import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_provider_type.dart';
import '../models/user_session.dart';

class AuthStore {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  static const _sessionKey = 'user_session_v1';

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

  Future<UserSession> signInLocally({
    required String displayName,
    required String email,
    AuthProviderType provider = AuthProviderType.email,
  }) async {
    final normalizedName = displayName.trim().isEmpty ? 'WIMC User' : displayName.trim();
    final normalizedEmail = email.trim();

    final providerLabel = switch (provider) {
      AuthProviderType.kakao => 'Kakao',
      AuthProviderType.google => 'Google',
      AuthProviderType.email => normalizedName,
      AuthProviderType.guest => 'Guest',
    };

    final next = UserSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      displayName: provider == AuthProviderType.email ? normalizedName : providerLabel,
      email: normalizedEmail,
      isGuest: false,
      signedInAt: DateTime.now(),
    );

    await _persist(next);
    return next;
  }

  Future<UserSession> continueAsGuest() async {
    final next = UserSession(
      id: 'guest',
      displayName: 'Guest',
      email: '',
      isGuest: true,
      signedInAt: DateTime.now(),
    );
    await _persist(next);
    return next;
  }

  Future<void> signOut() async {
    await _persist(null);
  }
}
