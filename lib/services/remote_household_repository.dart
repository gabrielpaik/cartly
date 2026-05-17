import 'dart:convert';
import 'dart:io';

import '../models/household_state.dart';
import 'api_base.dart';

class RemoteHouseholdRepository {
  RemoteHouseholdRepository({HttpClient? httpClient})
    : _httpClient =
          httpClient ??
          (HttpClient()..connectionTimeout = const Duration(seconds: 4));

  static const Duration _requestTimeout = Duration(seconds: 8);
  final HttpClient _httpClient;

  Uri _uri(String path) => Uri.parse('${getCartlyApiBaseUrl()}$path');

  Future<HouseholdState> getHousehold(String authToken) async {
    final response = await _send('GET', '/v1/households/me', authToken: authToken);
    return _readState(response);
  }

  Future<HouseholdState> generateInviteCode(String authToken) async {
    final response = await _send('POST', '/v1/households/invite-code', authToken: authToken);
    return _readState(response);
  }

  Future<HouseholdState> joinByCode({
    required String authToken,
    required String inviteCode,
  }) async {
    final response = await _send(
      'POST',
      '/v1/households/join',
      authToken: authToken,
      body: {'inviteCode': inviteCode},
    );
    return _readState(response);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    required String authToken,
    Map<String, dynamic>? body,
  }) async {
    final request = switch (method) {
      'GET' => await _httpClient.getUrl(_uri(path)).timeout(_requestTimeout),
      'POST' => await _httpClient.postUrl(_uri(path)).timeout(_requestTimeout),
      _ => throw ArgumentError('Unsupported method: $method'),
    };
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(_requestTimeout);
    final responseBody = await response.transform(utf8.decoder).join().timeout(_requestTimeout);
    final decoded = responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteHouseholdException(_errorMessage(decoded, '가족 그룹 요청에 실패했어'));
    }
    if (decoded['ok'] == false) {
      throw RemoteHouseholdException(_errorMessage(decoded, '가족 그룹 요청에 실패했어'));
    }
    return decoded;
  }

  HouseholdState _readState(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const RemoteHouseholdException('가족 그룹 정보를 읽지 못했어');
    }
    return HouseholdState.fromJson(data);
  }

  String _errorMessage(Map<String, dynamic> body, String fallback) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    final detail = body['detail'];
    if (detail is Map<String, dynamic>) {
      final message = detail['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return fallback;
  }
}

class RemoteHouseholdException implements Exception {
  final String message;
  const RemoteHouseholdException(this.message);

  @override
  String toString() => message;
}
