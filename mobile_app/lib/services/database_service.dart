import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('telegram_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        username TEXT NOT NULL,
        fullName TEXT,
        avatarUrl TEXT,
        isOnline INTEGER DEFAULT 0,
        lastSeen INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        senderId INTEGER NOT NULL,
        receiverId INTEGER NOT NULL,
        content TEXT NOT NULL,
        status TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        isPendingSync INTEGER DEFAULT 0
      )
    ''');
  }

  // Save or update user locally
  Future<void> saveUser(UserModel user) async {
    final db = await instance.database;
    await db.insert(
      'users',
      user.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get user profile
  Future<UserModel?> getUser(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return UserModel.fromJson(maps.first);
    }
    return null;
  }

  // Save message locally
  Future<void> saveMessage(MessageModel message) async {
    final db = await instance.database;
    await db.insert(
      'messages',
      message.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get message history between two users
  Future<List<MessageModel>> getMessages(int currentUserId, int contactId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT * FROM messages
      WHERE (senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)
      ORDER BY timestamp ASC
    ''', [currentUserId, contactId, contactId, currentUserId]);

    return result.map((json) => MessageModel.fromJson(json)).toList();
  }

  // Get unsent/pending messages to retry sync when back online
  Future<List<MessageModel>> getPendingMessages(int currentUserId) async {
    final db = await instance.database;
    final result = await db.query(
      'messages',
      where: 'senderId = ? AND isPendingSync = 1',
      whereArgs: [currentUserId],
      orderBy: 'timestamp ASC',
    );
    return result.map((json) => MessageModel.fromJson(json)).toList();
  }

  // Update message status
  Future<void> updateMessageStatus(String messageId, String status, {bool isPendingSync = false}) async {
    final db = await instance.database;
    await db.update(
      'messages',
      {
        'status': status,
        'isPendingSync': isPendingSync ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // Get recent chats for home screen offline list
  Future<List<Map<String, dynamic>>> getLocalConversations(int currentUserId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT
        u.id as contactId,
        u.username,
        u.fullName,
        u.avatarUrl,
        u.isOnline,
        u.lastSeen,
        m.id as messageId,
        m.content as lastMessage,
        m.senderId,
        m.receiverId,
        m.status,
        m.timestamp
      FROM users u
      JOIN messages m ON (
        (m.senderId = u.id AND m.receiverId = ?) OR
        (m.senderId = ? AND m.receiverId = u.id)
      )
      WHERE m.timestamp = (
        SELECT MAX(m2.timestamp)
        FROM messages m2
        WHERE (m2.senderId = u.id AND m2.receiverId = ?) OR
              (m2.senderId = ? AND m2.receiverId = u.id)
      )
      ORDER BY m.timestamp DESC
    ''', [currentUserId, currentUserId, currentUserId, currentUserId]);

    return result;
  }
}
