const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jwt-simple'); // using jwt-simple or jsonwebtoken
const jwtNative = require('jsonwebtoken');
const db = require('./db');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

const JWT_SECRET = process.env.JWT_SECRET || 'telegram_super_secret_key_123';

app.use(cors());
app.use(express.json());

// Helper DB functions returning promises
const dbRun = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve(this);
    });
  });
};

const dbGet = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => {
      if (err) reject(err);
      else resolve(row);
    });
  });
};

const dbAll = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
};

// Auth middleware
const authMiddleware = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: missing token' });
  }
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwtNative.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Unauthorized: invalid token' });
  }
};

// --- AUTH ROUTES ---

// Register
app.post('/api/auth/register', async (req, res) => {
  try {
    const { username, password, fullName } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }

    const existingUser = await dbGet('SELECT * FROM users WHERE username = ?', [username.toLowerCase().trim()]);
    if (existingUser) {
      return res.status(400).json({ error: 'Username is already taken' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const now = Date.now();
    const result = await dbRun(
      'INSERT INTO users (username, password, fullName, avatarUrl, isOnline, lastSeen, createdAt) VALUES (?, ?, ?, ?, 0, ?, ?)',
      [username.toLowerCase().trim(), hashedPassword, fullName || username, '', now, now]
    );

    const userId = result.lastID;
    const token = jwtNative.sign({ id: userId, username: username.toLowerCase().trim() }, JWT_SECRET, { expiresIn: '30d' });

    res.json({
      message: 'Registration successful',
      token,
      user: {
        id: userId,
        username: username.toLowerCase().trim(),
        fullName: fullName || username,
        avatarUrl: ''
      }
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Server error during registration' });
  }
});

// Login
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }

    const user = await dbGet('SELECT * FROM users WHERE username = ?', [username.toLowerCase().trim()]);
    if (!user) {
      return res.status(400).json({ error: 'Invalid username or password' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ error: 'Invalid username or password' });
    }

    const token = jwtNative.sign({ id: user.id, username: user.username }, JWT_SECRET, { expiresIn: '30d' });

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        username: user.username,
        fullName: user.fullName,
        avatarUrl: user.avatarUrl
      }
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Server error during login' });
  }
});

// Get Current Profile
app.get('/api/auth/me', authMiddleware, async (req, res) => {
  try {
    const user = await dbGet('SELECT id, username, fullName, avatarUrl, isOnline, lastSeen FROM users WHERE id = ?', [req.user.id]);
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ user });
  } catch (err) {
    res.status(500).json({ error: 'Server error fetching profile' });
  }
});

// --- USER ROUTES ---

// Search users
app.get('/api/users/search', authMiddleware, async (req, res) => {
  try {
    const query = req.query.q || '';
    const users = await dbAll(
      `SELECT id, username, fullName, avatarUrl, isOnline, lastSeen FROM users WHERE id != ? AND (username LIKE ? OR fullName LIKE ?) LIMIT 20`,
      [req.user.id, `%${query}%`, `%${query}%`]
    );
    res.json({ users });
  } catch (err) {
    res.status(500).json({ error: 'Server error searching users' });
  }
});

// Get recent conversations for current user
app.get('/api/conversations', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    // Query recent distinct contacts and their latest message
    const rows = await dbAll(
      `
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
      `,
      [userId, userId, userId, userId]
    );

    res.json({ conversations: rows });
  } catch (err) {
    console.error('Conversations error:', err);
    res.status(500).json({ error: 'Server error fetching conversations' });
  }
});

// Get message history with a contact
app.get('/api/messages/:contactId', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const contactId = parseInt(req.params.contactId, 10);

    const messages = await dbAll(
      `
      SELECT * FROM messages
      WHERE (senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)
      ORDER BY timestamp ASC
      `,
      [userId, contactId, contactId, userId]
    );

    res.json({ messages });
  } catch (err) {
    res.status(500).json({ error: 'Server error fetching messages' });
  }
});

// --- SOCKET.IO REAL-TIME SYSTEM ---
const connectedSockets = new Map(); // userId -> socket.id

io.use((socket, next) => {
  const token = socket.handshake.auth.token || socket.handshake.query.token;
  if (!token) {
    return next(new Error('Authentication error: token missing'));
  }
  try {
    const decoded = jwtNative.verify(token, JWT_SECRET);
    socket.user = decoded;
    next();
  } catch (err) {
    next(new Error('Authentication error: invalid token'));
  }
});

io.on('connection', async (socket) => {
  const userId = socket.user.id;
  connectedSockets.set(userId, socket.id);

  console.log(`User ${socket.user.username} (ID: ${userId}) connected with socket ${socket.id}`);

  // Mark user online
  const now = Date.now();
  await dbRun('UPDATE users SET isOnline = 1, lastSeen = ? WHERE id = ?', [now, userId]);
  io.emit('user_status', { userId, isOnline: true, lastSeen: now });

  // Deliver pending messages to this re-connected user
  try {
    const pendingMessages = await dbAll(
      `SELECT * FROM messages WHERE receiverId = ? AND status = 'sent'`,
      [userId]
    );

    for (const msg of pendingMessages) {
      socket.emit('receive_message', msg);
      // Mark as delivered
      await dbRun(`UPDATE messages SET status = 'delivered' WHERE id = ?`, [msg.id]);

      // Notify sender if online
      const senderSocketId = connectedSockets.get(msg.senderId);
      if (senderSocketId) {
        io.to(senderSocketId).emit('message_status', {
          messageId: msg.id,
          status: 'delivered'
        });
      }
    }
  } catch (err) {
    console.error('Error syncing offline messages:', err);
  }

  // Handle send message
  socket.on('send_message', async (data) => {
    // data: { id, receiverId, content, timestamp }
    const { id, receiverId, content, timestamp } = data;
    const msgId = id || `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const msgTimestamp = timestamp || Date.now();

    const receiverSocketId = connectedSockets.get(receiverId);
    const initialStatus = receiverSocketId ? 'delivered' : 'sent';

    try {
      await dbRun(
        `INSERT INTO messages (id, senderId, receiverId, content, status, timestamp) VALUES (?, ?, ?, ?, ?, ?)`,
        [msgId, userId, receiverId, content, initialStatus, msgTimestamp]
      );

      const messageObj = {
        id: msgId,
        senderId: userId,
        receiverId,
        content,
        status: initialStatus,
        timestamp: msgTimestamp
      };

      // Confirm to sender that message is saved on server
      socket.emit('message_ack', messageObj);

      // Send to receiver if online
      if (receiverSocketId) {
        io.to(receiverSocketId).emit('receive_message', messageObj);
      }
    } catch (err) {
      console.error('Error saving message:', err);
      socket.emit('message_error', { id: msgId, error: 'Failed to send message' });
    }
  });

  // Handle typing indicator
  socket.on('typing', (data) => {
    // data: { receiverId, isTyping }
    const receiverSocketId = connectedSockets.get(data.receiverId);
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('user_typing', {
        senderId: userId,
        isTyping: data.isTyping
      });
    }
  });

  // Handle mark as read
  socket.on('mark_read', async (data) => {
    // data: { senderId } -> user is reading messages from senderId
    const senderId = data.senderId;
    try {
      await dbRun(
        `UPDATE messages SET status = 'read' WHERE senderId = ? AND receiverId = ? AND status != 'read'`,
        [senderId, userId]
      );

      const senderSocketId = connectedSockets.get(senderId);
      if (senderSocketId) {
        io.to(senderSocketId).emit('messages_read', {
          readBy: userId
        });
      }
    } catch (err) {
      console.error('Error marking as read:', err);
    }
  });

  // Disconnect handler
  socket.on('disconnect', async () => {
    console.log(`User ${socket.user.username} disconnected`);
    connectedSockets.delete(userId);
    const lastSeen = Date.now();
    await dbRun('UPDATE users SET isOnline = 0, lastSeen = ? WHERE id = ?', [lastSeen, userId]);
    io.emit('user_status', { userId, isOnline: false, lastSeen });
  });
});

// Docker/VPS deployment files helper
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Telegram Backend Server running on port ${PORT}`);
});
