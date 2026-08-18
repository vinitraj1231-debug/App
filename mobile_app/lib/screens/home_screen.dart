import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ChatProvider>(context, listen: false).loadConversations();
    });
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final provider = Provider.of<ChatProvider>(context, listen: false);
    if (provider.isConnectedToInternet && provider.token != null) {
      try {
        final results = await ApiService.searchUsers(provider.token!, query.trim());
        setState(() {
          _searchResults = results;
        });
      } catch (e) {
        print('Search error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final user = chatProvider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF17212B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF242F3D),
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search user...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text('Telegram', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                _searchController.clear();
                _searchResults = [];
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF242F3D),
            onSelected: (val) {
              if (val == 'logout') {
                chatProvider.logout();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(user?.fullName ?? 'Profile', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF17212B),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF242F3D)),
              accountName: Text(user?.fullName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text('@${user?.username ?? ''}', style: const TextStyle(color: Colors.grey)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: const Color(0xFF229ED9),
                child: Text(
                  user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined, color: Colors.grey),
              title: const Text('New Group', style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: Colors.grey),
              title: const Text('Contacts', style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: Colors.grey),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: Icon(
                chatProvider.isConnectedToInternet ? Icons.wifi : Icons.wifi_off,
                color: chatProvider.isConnectedToInternet ? Colors.green : Colors.red,
              ),
              title: Text(
                chatProvider.isConnectedToInternet ? 'Online Mode' : 'Offline Mode',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Offline network banner indicator
          if (!chatProvider.isConnectedToInternet)
            Container(
              color: Colors.redAccent.withOpacity(0.8),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Offline Mode: Local chats accessible. Messages queue until connected.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : _buildConversationList(chatProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text('No users found', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final contact = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF229ED9),
            child: Text(
              contact.fullName.isNotEmpty ? contact.fullName[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(contact.fullName, style: const TextStyle(color: Colors.white)),
          subtitle: Text('@${contact.username}', style: const TextStyle(color: Colors.grey)),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatScreen(contact: contact)),
            );
          },
        );
      },
    );
  }

  Widget _buildConversationList(ChatProvider chatProvider) {
    final conversations = chatProvider.conversations;

    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 64),
            SizedBox(height: 12),
            Text(
              'No conversations yet.\nSearch for users above to start chatting!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conv = conversations[index];
        final timeStr = DateFormat('HH:mm').format(
          DateTime.fromMillisecondsSinceEpoch(conv.lastMessageTimestamp),
        );

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF229ED9),
            child: Text(
              conv.contact.fullName.isNotEmpty ? conv.contact.fullName[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            conv.contact.fullName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            conv.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.grey),
          ),
          trailing: Text(
            timeStr,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChatScreen(contact: conv.contact)),
            );
          },
        );
      },
    );
  }
}
