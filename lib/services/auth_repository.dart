import '../models/auth_provider_type.dart';
import '../models/user_session.dart';

class EmailAuthDraft {
  final String displayName;
  final String email;

  const EmailAuthDraft({required this.displayName, required this.email});
}

abstract class AuthRepository {
  Future<UserSession> signInWithProvider(AuthProviderType provider);

  Future<UserSession> signInWithEmail(EmailAuthDraft draft);

  Future<UserSession> continueAsGuest();
}
