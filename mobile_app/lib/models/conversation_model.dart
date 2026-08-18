import 'user_model.dart';

class ConversationModel {
  final UserModel contact;
  final String lastMessage;
  final int lastMessageTimestamp;
  final String lastMessageStatus;
  final int lastMessageSenderId;

  ConversationModel({
    required this.contact,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    required this.lastMessageStatus,
    required this.lastMessageSenderId,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      contact: UserModel(
        id: json['contactId'] is int
            ? json['contactId']
            : int.parse(json['contactId'].toString()),
        username: json['username'] ?? '',
        fullName: json['fullName'] ?? json['username'] ?? '',
        avatarUrl: json['avatarUrl'] ?? '',
        isOnline: json['isOnline'] == 1 || json['isOnline'] == true,
        lastSeen: json['lastSeen'] != null
            ? (json['lastSeen'] is int
                ? json['lastSeen']
                : int.tryParse(json['lastSeen'].toString()) ?? 0)
            : 0,
      ),
      lastMessage: json['lastMessage'] ?? '',
      lastMessageTimestamp: json['timestamp'] is int
          ? json['timestamp']
          : int.parse(json['timestamp'].toString()),
      lastMessageStatus: json['status'] ?? 'sent',
      lastMessageSenderId: json['senderId'] is int
          ? json['senderId']
          : int.parse(json['senderId'].toString()),
    );
  }
}
