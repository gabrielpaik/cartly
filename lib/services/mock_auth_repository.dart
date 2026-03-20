import '../models/auth_provider_type.dart';
import '../models/user_session.dart';
import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  const MockAuthRepository();

  @override
  Future<UserSession> signInWithProvider(AuthProviderType provider) async {
    if (provider == AuthProviderType.email ||
        provider == AuthProviderType.guest) {
      throw ArgumentError(
        'Use the dedicated email/guest methods for $provider',
      );
    }

    final now = DateTime.now();
    final providerName = switch (provider) {
      AuthProviderType.kakao => 'Kakao',
      AuthProviderType.google => 'Google',
      AuthProviderType.email => 'Email',
      AuthProviderType.guest => 'Guest',
    };

    final placeholderEmail = switch (provider) {
      AuthProviderType.kakao => 'kakao-placeholder@wimc.app',
      AuthProviderType.google => 'google-placeholder@wimc.app',
      AuthProviderType.email => 'email-placeholder@wimc.app',
      AuthProviderType.guest => '',
    };

    return UserSession(
      id: '${provider.name}_${now.microsecondsSinceEpoch}',
      provider: provider,
      displayName: providerName,
      email: placeholderEmail,
      isGuest: false,
      signedInAt: now,
    );
  }

  @override
  Future<UserSession> signInWithEmail(EmailAuthDraft draft) async {
    final now = DateTime.now();
    final normalizedName = draft.displayName.trim().isEmpty
        ? 'WIMC User'
        : draft.displayName.trim();
    final normalizedEmail = draft.email.trim();

    return UserSession(
      id: 'email_${now.microsecondsSinceEpoch}',
      provider: AuthProviderType.email,
      displayName: normalizedName,
      email: normalizedEmail,
      isGuest: false,
      signedInAt: now,
    );
  }

  @override
  Future<UserSession> continueAsGuest() async {
    return UserSession(
      id: 'guest',
      provider: AuthProviderType.guest,
      displayName: 'Guest',
      email: '',
      isGuest: true,
      signedInAt: DateTime.now(),
    );
  }
}
