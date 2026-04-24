import 'dart:convert';
import 'dart:io';

import '../models/auth_provider_type.dart';
import '../models/user_session.dart';
import 'api_base.dart';
import 'auth_repository.dart';
import 'install_id_store.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  Uri _uri(String path) => Uri.parse('${getCartlyApiBaseUrl()}$path');

  @override
  Future<UserSession> continueAsGuest() async {
    final installId = await InstallIdStore.getOrCreate();
    final response = await _postJson('/v1/auth/guest', {
      'deviceId': installId,
      'platform': Platform.operatingSystem,
      'appVersion': '0.1.0',
    });
    return _sessionFromResponse(
      response,
      fallbackProvider: AuthProviderType.guest,
    );
  }

  @override
  Future<void> requestSignupCode(String email) async {
    await _postJson('/v1/auth/email/request-signup-code', {
      'email': email.trim(),
    });
  }

  @override
  Future<void> verifySignupCode({
    required String email,
    required String code,
  }) async {
    await _postJson('/v1/auth/email/verify-signup-code', {
      'email': email.trim(),
      'code': code.trim(),
    });
  }

  @override
  Future<UserSession> registerWithEmail(EmailRegisterDraft draft) async {
    final installId = await InstallIdStore.getOrCreate();
    final response = await _postJson('/v1/auth/email/register', {
      'email': draft.email.trim(),
      'displayName': draft.displayName.trim().isEmpty
          ? 'Cartly User'
          : draft.displayName.trim(),
      'password': draft.password,
      'code': draft.code.trim(),
      'deviceId': installId,
    });
    return _sessionFromResponse(
      response,
      fallbackProvider: AuthProviderType.email,
    );
  }

  @override
  Future<UserSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final installId = await InstallIdStore.getOrCreate();
    final response = await _postJson('/v1/auth/password/login', {
      'email': email.trim(),
      'password': password,
      'deviceId': installId,
    });
    return _sessionFromResponse(
      response,
      fallbackProvider: AuthProviderType.email,
    );
  }

  @override
  Future<void> requestPasswordResetCode(String email) async {
    await _postJson('/v1/auth/password/request-reset-code', {
      'email': email.trim(),
    });
  }

  @override
  Future<UserSession> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _postJson('/v1/auth/password/reset', {
      'email': email.trim(),
      'code': code.trim(),
      'newPassword': newPassword,
    });
    return _sessionFromResponse(
      response,
      fallbackProvider: AuthProviderType.email,
    );
  }

  @override
  Future<UserSession> signInWithProvider(AuthProviderType provider) async {
    if (provider == AuthProviderType.email ||
        provider == AuthProviderType.guest) {
      throw ArgumentError('Use dedicated methods for $provider');
    }

    final installId = await InstallIdStore.getOrCreate();
    final providerKey = provider.name;
    final response = await _postJson('/v1/auth/login', {
      'email': '$providerKey-$installId@cartly.app',
      'displayName': provider == AuthProviderType.kakao
          ? 'Kakao User'
          : 'Google User',
      'provider': providerKey,
      'deviceId': installId,
    });
    return _sessionFromResponse(response, fallbackProvider: provider);
  }

  @override
  Future<UserSession> refreshSession(UserSession current) async {
    final authToken = current.authToken.trim();
    if (authToken.isEmpty) {
      throw const AuthRepositoryException('세션 토큰이 비어 있습니다');
    }

    final response = await _getJson('/v1/auth/me', authToken: authToken);
    return _sessionFromResponse(
      response,
      fallbackProvider: current.provider,
      currentSession: current,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) {
    return _requestJson('POST', path, body: body);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    String? authToken,
  }) {
    return _requestJson('GET', path, authToken: authToken);
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? authToken,
  }) async {
    final request = await _httpClient.openUrl(method, _uri(path));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final trimmedToken = authToken?.trim() ?? '';
    if (trimmedToken.isNotEmpty) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $trimmedToken',
      );
    }

    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final decoded = responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthRepositoryException(
        _errorMessage(decoded, '로그인을 완료하지 못했습니다'),
        code: _errorCode(decoded),
      );
    }

    final ok = decoded['ok'];
    if (ok is bool && !ok) {
      throw AuthRepositoryException(
        _errorMessage(decoded, '로그인을 완료하지 못했습니다'),
        code: _errorCode(decoded),
      );
    }

    return decoded;
  }

  UserSession _sessionFromResponse(
    Map<String, dynamic> response, {
    required AuthProviderType fallbackProvider,
    UserSession? currentSession,
  }) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const AuthRepositoryException('인증 응답 형식이 올바르지 않습니다');
    }

    final user = data['user'];
    if (user is! Map<String, dynamic>) {
      throw const AuthRepositoryException('사용자 정보를 읽지 못했습니다');
    }

    final session = data['session'];
    final sessionMap = session is Map<String, dynamic> ? session : null;
    if (currentSession == null && sessionMap == null) {
      throw const AuthRepositoryException('세션 정보를 읽지 못했습니다');
    }

    final providerName = (user['provider'] ?? fallbackProvider.name).toString();
    final provider = AuthProviderType.values.firstWhere(
      (value) => value.name == providerName,
      orElse: () => fallbackProvider,
    );

    final rawGuestCode = (user['guestCode'] as String?)?.trim();
    final rawToken = ((sessionMap?['token'] ?? currentSession?.authToken ?? '')
            as String)
        .trim();
    final rawExpiresAt =
        ((sessionMap?['expiresAt'] ?? '') as String).trim();

    return UserSession(
      id: (user['id'] ?? currentSession?.id ?? '') as String,
      provider: provider,
      displayName: ((user['displayName'] ?? currentSession?.displayName ?? '')
              as String)
          .trim(),
      guestCode: rawGuestCode == null || rawGuestCode.isEmpty
          ? currentSession?.guestCode
          : rawGuestCode,
      email: ((user['email'] ?? currentSession?.email ?? '') as String).trim(),
      isGuest: (user['isGuest'] ?? currentSession?.isGuest ?? provider == AuthProviderType.guest)
          as bool,
      signedInAt: currentSession?.signedInAt ?? DateTime.now(),
      authToken: rawToken,
      sessionExpiresAt: rawExpiresAt.isEmpty
          ? currentSession?.sessionExpiresAt
          : DateTime.tryParse(rawExpiresAt),
    );
  }

  String _errorMessage(Map<String, dynamic> body, String fallback) {
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is Map<String, dynamic>) {
      final message = detail['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return fallback;
  }

  String? _errorCode(Map<String, dynamic> body) {
    final detail = body['detail'];
    if (detail is Map<String, dynamic>) {
      final code = detail['code'];
      if (code is String && code.isNotEmpty) return code;
    }
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      final code = error['code'];
      if (code is String && code.isNotEmpty) return code;
    }
    return null;
  }
}

class AuthRepositoryException implements Exception {
  final String message;
  final String? code;
  const AuthRepositoryException(this.message, {this.code});

  @override
  String toString() => message;
}
