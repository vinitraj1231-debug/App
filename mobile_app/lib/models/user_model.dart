class UserModel {
  final int id;
  final String username;
  final String fullName;
  final String avatarUrl;
  final bool isOnline;
  final int lastSeen;

  UserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.isOnline,
    required this.lastSeen,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? json['username'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      isOnline: json['isOnline'] == 1 || json['isOnline'] == true,
      lastSeen: json['lastSeen'] != null
          ? (json['lastSeen'] is int
              ? json['lastSeen']
              : int.tryParse(json['lastSeen'].toString()) ?? 0)
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'isOnline': isOnline ? 1 : 0,
      'lastSeen': lastSeen,
    };
  }
}
