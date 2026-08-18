const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(__dirname, 'chat.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Failed to connect to SQLite DB:', err);
  } else {
    console.log('Connected to SQLite database at', dbPath);
  }
});

db.serialize(() => {
  // Users table
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      fullName TEXT,
      avatarUrl TEXT,
      isOnline INTEGER DEFAULT 0,
      lastSeen INTEGER,
      createdAt INTEGER
    )
  `);

  // Messages table
  db.run(`
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      senderId INTEGER NOT NULL,
      receiverId INTEGER NOT NULL,
      content TEXT NOT NULL,
      status TEXT DEFAULT 'sent', -- 'sent', 'delivered', 'read'
      timestamp INTEGER NOT NULL,
      FOREIGN KEY(senderId) REFERENCES users(id),
      FOREIGN KEY(receiverId) REFERENCES users(id)
    )
  `);
});

module.exports = db;
