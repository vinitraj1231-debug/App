import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  UserModel? currentUser;
  String? token;
  IO.Socket? socket;

  bool isConnectedToInternet = true;
  bool isSocketConnected = false;

  List<ConversationModel> conversations = [];
  Map<int, List<MessageModel>> chatMessages = {}; // contactId -> list of messages
  Map<int, bool> typingUsers = {}; // contactId -> isTyping

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  ChatProvider() {
    _initConnectivity();
  }

  void _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectivityStatus(results);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateConnectivityStatus(results);
    });
  }

  void _updateConnectivityStatus(List<ConnectivityResult> results) {
    bool hasNet = results.any((result) => result != ConnectivityResult.none);
    isConnectedToInternet = hasNet;

    if (hasNet) {
      if (token != null && (socket == null || !socket!.connected)) {
        connectSocket();
      }
      _syncPendingOfflineMessages();
    } else {
      isSocketConnected = false;
    }
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    final savedUserId = prefs.getInt('user_id');

    if (savedToken != null && savedUserId != null) {
      token = savedToken;
      final cachedUser = await DatabaseService.instance.getUser(savedUserId);
      if (cachedUser != null) {
        currentUser = cachedUser;
        notifyListeners();
        if (isConnectedToInternet) {
          connectSocket();
        }
        loadConversations();
        return true;
      }
    }
    return false;
  }

  Future<void> login(String username, String password) async {
    final data = await ApiService.login(username: username, password: password);
    token = data['token'];
    currentUser = UserModel.fromJson(data['user']);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token!);
    await prefs.setInt('user_id', currentUser!.id);

    await DatabaseService.instance.saveUser(currentUser!);

    connectSocket();
    await loadConversations();
    notifyListeners();
  }

  Future<void> register(String username, String password, String fullName) async {
    final data = await ApiService.register(
      username: username,
      password: password,
      fullName: fullName,
    );
    token = data['token'];
    currentUser = UserModel.fromJson(data['user']);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token!);
    await prefs.setInt('user_id', currentUser!.id);

    await DatabaseService.instance.saveUser(currentUser!);

    connectSocket();
    await loadConversations();
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (socket != null) {
      socket!.disconnect();
      socket!.dispose();
    }

    currentUser = null;
    token = null;
    conversations.clear();
    chatMessages.clear();
    notifyListeners();
  }

  void connectSocket() {
    if (token == null) return;

    socket = IO.io(ApiService.baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .setAuth({'token': token})
      .build());

    socket!.connect();

    socket!.onConnect((_) {
      isSocketConnected = true;
      notifyListeners();
      _syncPendingOfflineMessages();
    });

    socket!.onDisconnect((_) {
      isSocketConnected = false;
      notifyListeners();
    });

    socket!.on('receive_message', (data) async {
      final msg = MessageModel.fromJson(data);
      await DatabaseService.instance.saveMessage(msg);

      // Add message to chat memory list
      int contactId = msg.senderId == currentUser?.id ? msg.receiverId : msg.senderId;
      if (chatMessages.containsKey(contactId)) {
        chatMessages[contactId]!.add(msg);
      } else {
        chatMessages[contactId] = [msg];
      }

      // Show Local Notification if from another user
      if (msg.senderId != currentUser?.id) {
        NotificationService().showMessageNotification(
          id: msg.timestamp ~/ 1000,
          title: 'New Telegram Message',
          body: msg.content,
        );
      }

      await loadConversations();
      notifyListeners();
    });

    socket!.on('message_ack', (data) async {
      final msg = MessageModel.fromJson(data);
      await DatabaseService.instance.saveMessage(msg);

      int contactId = msg.receiverId;
      if (chatMessages.containsKey(contactId)) {
        int idx = chatMessages[contactId]!.indexWhere((m) => m.id == msg.id);
        if (idx != -1) {
          chatMessages[contactId]![idx] = msg.copyWith(status: msg.status, isPendingSync: false);
        }
      }

      await loadConversations();
      notifyListeners();
    });

    socket!.on('user_typing', (data) {
      int senderId = data['senderId'];
      bool isTyping = data['isTyping'] ?? false;
      typingUsers[senderId] = isTyping;
      notifyListeners();
    });

    socket!.on('user_status', (data) {
      // User online / last seen status update
      loadConversations();
    });
  }

  Future<void> loadConversations() async {
    if (currentUser == null) return;

    if (isConnectedToInternet && token != null) {
      try {
        final serverConversations = await ApiService.fetchConversations(token!);
        conversations = serverConversations;

        // Save contacts to local DB
        for (var c in serverConversations) {
          await DatabaseService.instance.saveUser(c.contact);
        }
        notifyListeners();
        return;
      } catch (e) {
        print('Error fetching online conversations: $e');
      }
    }

    // Fallback offline database
    final localData = await DatabaseService.instance.getLocalConversations(currentUser!.id);
    conversations = localData.map((map) => ConversationModel.fromJson(map)).toList();
    notifyListeners();
  }

  Future<void> loadMessages(int contactId) async {
    if (currentUser == null) return;

    // Load from local DB immediately (Fast / Offline-first)
    List<MessageModel> localMsgs = await DatabaseService.instance.getMessages(currentUser!.id, contactId);
    chatMessages[contactId] = localMsgs;
    notifyListeners();

    // Fetch from server if online
    if (isConnectedToInternet && token != null) {
      try {
        List<MessageModel> serverMsgs = await ApiService.fetchMessages(token!, contactId);
        for (var msg in serverMsgs) {
          await DatabaseService.instance.saveMessage(msg);
        }
        chatMessages[contactId] = await DatabaseService.instance.getMessages(currentUser!.id, contactId);
        notifyListeners();
      } catch (e) {
        print('Error loading online messages: $e');
      }
    }
  }

  Future<void> sendMessage(int receiverId, String content) async {
    if (currentUser == null) return;

    final String tempId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecondsSinceEpoch % 9000))}';
    final int timestamp = DateTime.now().millisecondsSinceEpoch;

    bool willSendNow = isConnectedToInternet && isSocketConnected;

    final newMessage = MessageModel(
      id: tempId,
      senderId: currentUser!.id,
      receiverId: receiverId,
      content: content,
      status: willSendNow ? 'sending' : 'failed', // Failed / unsent icon if offline
      timestamp: timestamp,
      isPendingSync: !willSendNow,
    );

    // Save locally
    await DatabaseService.instance.saveMessage(newMessage);

    // Add to screen list immediately
    if (!chatMessages.containsKey(receiverId)) {
      chatMessages[receiverId] = [];
    }
    chatMessages[receiverId]!.add(newMessage);
    await loadConversations();
    notifyListeners();

    if (willSendNow && socket != null) {
      socket!.emit('send_message', {
        'id': tempId,
        'receiverId': receiverId,
        'content': content,
        'timestamp': timestamp,
      });
    }
  }

  Future<void> _syncPendingOfflineMessages() async {
    if (currentUser == null || !isConnectedToInternet || !isSocketConnected || socket == null) return;

    List<MessageModel> pending = await DatabaseService.instance.getPendingMessages(currentUser!.id);
    for (var msg in pending) {
      socket!.emit('send_message', {
        'id': msg.id,
        'receiverId': msg.receiverId,
        'content': msg.content,
        'timestamp': msg.timestamp,
      });
      await DatabaseService.instance.updateMessageStatus(msg.id, 'sending', isPendingSync: false);
    }
  }

  void sendTyping(int receiverId, bool isTyping) {
    if (isConnectedToInternet && isSocketConnected && socket != null) {
      socket!.emit('typing', {
        'receiverId': receiverId,
        'isTyping': isTyping,
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
