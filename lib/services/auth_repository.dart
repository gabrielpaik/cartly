import '../models/auth_provider_type.dart';
import '../models/user_session.dart';

class EmailRegisterDraft {
  final String displayName;
  final String email;
  final String password;
  final String code;

  const EmailRegisterDraft({
    required this.displayName,
    required this.email,
    required this.password,
    required this.code,
  });
}

abstract class AuthRepository {
  Future<UserSession> signInWithProvider(AuthProviderType provider);

  Future<void> requestSignupCode(String email);

  Future<void> verifySignupCode({required String email, required String code});

  Future<UserSession> registerWithEmail(EmailRegisterDraft draft);

  Future<UserSession> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> requestPasswordResetCode(String email);

  Future<UserSession> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<UserSession> continueAsGuest();

  Future<UserSession> refreshSession(UserSession current);

  Future<UserSession> updateProfile({
    required UserSession current,
    required String displayName,
  });

  Future<void> deleteAccount(String authToken);
}
