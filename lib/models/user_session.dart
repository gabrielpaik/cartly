class UserSession {
  final String id;
  final String displayName;
  final String email;
  final bool isGuest;
  final DateTime signedInAt;

  const UserSession({
    required this.id,
    required this.displayName,
    required this.email,
    required this.isGuest,
    required this.signedInAt,
  });

  String get badgeLabel => isGuest ? '게스트' : '로그인됨';

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'email': email,
    'isGuest': isGuest,
    'signedInAt': signedInAt.toIso8601String(),
  };

  static UserSession fromJson(Map<String, dynamic> json) => UserSession(
    id: (json['id'] ?? '') as String,
    displayName: (json['displayName'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    isGuest: (json['isGuest'] ?? true) as bool,
    signedInAt:
        DateTime.tryParse((json['signedInAt'] ?? '') as String) ?? DateTime.now(),
  );
}
