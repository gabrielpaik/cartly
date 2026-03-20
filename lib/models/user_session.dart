import 'auth_provider_type.dart';

class UserSession {
  final String id;
  final AuthProviderType provider;
  final String displayName;
  final String email;
  final bool isGuest;
  final DateTime signedInAt;

  const UserSession({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.email,
    required this.isGuest,
    required this.signedInAt,
  });

  String get badgeLabel => isGuest ? '게스트' : providerBadge;

  String get providerBadge => switch (provider) {
    AuthProviderType.kakao => 'Kakao',
    AuthProviderType.google => 'Google',
    AuthProviderType.email => 'Email',
    AuthProviderType.guest => 'Guest',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider.name,
    'displayName': displayName,
    'email': email,
    'isGuest': isGuest,
    'signedInAt': signedInAt.toIso8601String(),
  };

  static UserSession fromJson(Map<String, dynamic> json) {
    final providerName = (json['provider'] ?? 'guest') as String;
    final provider = AuthProviderType.values.firstWhere(
      (value) => value.name == providerName,
      orElse: () => ((json['isGuest'] ?? true) as bool)
          ? AuthProviderType.guest
          : AuthProviderType.email,
    );

    return UserSession(
      id: (json['id'] ?? '') as String,
      provider: provider,
      displayName: (json['displayName'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      isGuest: (json['isGuest'] ?? true) as bool,
      signedInAt:
          DateTime.tryParse((json['signedInAt'] ?? '') as String) ??
          DateTime.now(),
    );
  }
}
