import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_provider_type.dart';
import '../models/user_session.dart';
import 'auth_repository.dart';
import 'mock_auth_repository.dart';

class AuthStore {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  static const _sessionKey = 'user_session_v1';

  final AuthRepository _repository = const MockAuthRepository();

  final ValueNotifier<UserSession?> session = ValueNotifier<UserSession?>(null);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      session.value = null;
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      session.value = UserSession.fromJson(decoded);
    } catch (_) {
      session.value = null;
    }
  }

  Future<void> _persist(UserSession? next) async {
    final sp = await SharedPreferences.getInstance();
    if (next == null) {
      await sp.remove(_sessionKey);
      session.value = null;
      return;
    }
    await sp.setString(_sessionKey, jsonEncode(next.toJson()));
    session.value = next;
  }

  Future<UserSession> signInWithProvider(AuthProviderType provider) async {
    final next = await _repository.signInWithProvider(provider);
    await _persist(next);
    return next;
  }

  Future<UserSession> signInWithEmail({
    required String displayName,
    required String email,
  }) async {
    final next = await _repository.signInWithEmail(
      EmailAuthDraft(displayName: displayName, email: email),
    );
    await _persist(next);
    return next;
  }

  Future<UserSession> continueAsGuest() async {
    final next = await _repository.continueAsGuest();
    await _persist(next);
    return next;
  }

  Future<void> signOut() async {
    await _persist(null);
  }
}
