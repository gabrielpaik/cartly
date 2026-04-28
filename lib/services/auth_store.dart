import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_provider_type.dart';
import '../models/user_session.dart';
import 'api_base.dart';
import 'auth_repository.dart';
import 'remote_auth_repository.dart';

class AuthStore {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  static const _sessionKey = 'user_session_v1';

  AuthRepository? _repository;

  AuthRepository get _authRepository => _repository ??= RemoteAuthRepository();

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
      final next = UserSession.fromJson(decoded);
      if (next.authToken.trim().isEmpty) {
        session.value = null;
        await sp.remove(_sessionKey);
        return;
      }
      if (next.sessionExpiresAt != null &&
          next.sessionExpiresAt!.isBefore(DateTime.now())) {
        session.value = null;
        await sp.remove(_sessionKey);
        return;
      }

      session.value = next;

      try {
        final refreshed = await _authRepository.refreshSession(next);
        await _persist(refreshed);
      } on AuthRepositoryException catch (error) {
        if (error.code == 'UNAUTHORIZED') {
          await _persist(null);
          return;
        }
        session.value = next;
      } catch (_) {
        session.value = next;
      }
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
    final next = await _authRepository.signInWithProvider(provider);
    await _persist(next);
    return next;
  }

  Future<void> requestSignupCode(String email) {
    return _authRepository.requestSignupCode(email);
  }

  Future<void> verifySignupCode({
    required String email,
    required String code,
  }) {
    return _authRepository.verifySignupCode(email: email, code: code);
  }

  Future<UserSession> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
    required String code,
  }) async {
    final next = await _authRepository.registerWithEmail(
      EmailRegisterDraft(
        displayName: displayName,
        email: email,
        password: password,
        code: code,
      ),
    );
    await _persist(next);
    return next;
  }

  Future<UserSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final next = await _authRepository.signInWithPassword(
      email: email,
      password: password,
    );
    await _persist(next);
    return next;
  }

  Future<void> requestPasswordResetCode(String email) {
    return _authRepository.requestPasswordResetCode(email);
  }

  Future<UserSession> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final next = await _authRepository.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
    );
    await _persist(next);
    return next;
  }

  Future<UserSession> continueAsGuest() async {
    final next = await _authRepository.continueAsGuest();
    await _persist(next);
    return next;
  }

  Future<void> signOut() async {
    final current = session.value;
    if (current != null && current.authToken.trim().isNotEmpty) {
      try {
        final client = HttpClient();
        final request = await client.postUrl(
          Uri.parse('${getCartlyApiBaseUrl()}/v1/auth/logout'),
        );
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${current.authToken}',
        );
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        await request.close();
        client.close(force: true);
      } catch (_) {
        // local sign-out should still complete even if backend revoke fails
      }
    }
    await _persist(null);
  }
}
