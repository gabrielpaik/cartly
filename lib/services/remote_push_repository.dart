import 'dart:convert';
import 'dart:io';

import 'api_base.dart';

class RemotePushRepository {
  final String baseUrl;
  final String? authToken;
  final String? Function()? authTokenProvider;
  final HttpClient _httpClient;

  RemotePushRepository({
    String? baseUrl,
    this.authToken,
    this.authTokenProvider,
    HttpClient? httpClient,
  }) : baseUrl = (baseUrl ?? getCartlyApiBaseUrl()).replaceAll(
         RegExp(r'/$'),
         '',
       ),
       _httpClient = httpClient ?? HttpClient();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<void> registerDevice({
    required String installId,
    required String platform,
    required bool notificationsEnabled,
    String? pushProvider,
    String? pushToken,
    String? appVersion,
    String? locale,
    Map<String, Object?>? debugInfo,
  }) async {
    final request = await _httpClient.postUrl(_uri('/v1/push/devices'));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    final token = (authTokenProvider?.call() ?? authToken)?.trim();
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    request.add(
      utf8.encode(
        jsonEncode({
          'installId': installId,
          'platform': platform,
          'pushProvider': pushProvider,
          'pushToken': pushToken,
          'notificationsEnabled': notificationsEnabled,
          'appVersion': appVersion,
          'locale': locale,
          'debugInfo': debugInfo,
        }),
      ),
    );

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw RemotePushException(body.isEmpty ? '디바이스 등록에 실패했어요' : body);
    }
  }
}

class RemotePushException implements Exception {
  final String message;

  const RemotePushException(this.message);

  @override
  String toString() => message;
}
