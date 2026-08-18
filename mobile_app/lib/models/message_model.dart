enum MessageSyncStatus { sending, sent, delivered, read, failed }

class MessageModel {
  final String id;
  final int senderId;
  final int receiverId;
  final String content;
  final String status; // 'sending', 'sent', 'delivered', 'read'
  final int timestamp;
  final bool isPendingSync;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.status,
    required this.timestamp,
    this.isPendingSync = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? '',
      senderId: json['senderId'] is int
          ? json['senderId']
          : int.parse(json['senderId'].toString()),
      receiverId: json['receiverId'] is int
          ? json['receiverId']
          : int.parse(json['receiverId'].toString()),
      content: json['content'] ?? '',
      status: json['status'] ?? 'sent',
      timestamp: json['timestamp'] is int
          ? json['timestamp']
          : int.parse(json['timestamp'].toString()),
      isPendingSync: json['isPendingSync'] == 1 || json['isPendingSync'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'status': status,
      'timestamp': timestamp,
      'isPendingSync': isPendingSync ? 1 : 0,
    };
  }

  MessageModel copyWith({
    String? status,
    bool? isPendingSync,
  }) {
    return MessageModel(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      status: status ?? this.status,
      timestamp: timestamp,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }
}
