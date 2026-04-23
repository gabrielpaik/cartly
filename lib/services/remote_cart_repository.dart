import 'dart:convert';
import 'dart:io';

import '../models/saved_cart.dart';
import 'api_base.dart';

class RemoteCartRepository {
  RemoteCartRepository({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  Uri _uri(String path) => Uri.parse('${getCartlyApiBaseUrl()}$path');

  Future<List<SavedCart>> listCarts(String authToken) async {
    final response = await _send('GET', '/v1/carts', authToken: authToken);
    final data = response['data'];
    if (data is! Map<String, dynamic>) return const [];
    final carts = (data['carts'] as List? ?? const []);
    return carts
        .whereType<Map>()
        .map((item) => SavedCart.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<SavedCart> getCart({
    required String authToken,
    required String cartId,
  }) async {
    final response = await _send(
      'GET',
      '/v1/carts/$cartId',
      authToken: authToken,
    );
    return _readCart(response);
  }

  Future<SavedCart> createCart({
    required String authToken,
    required SavedCart cart,
  }) async {
    final response = await _send(
      'POST',
      '/v1/carts',
      authToken: authToken,
      body: {
        'title': cart.title,
        'items': cart.items.map((item) => item.toJson()).toList(),
      },
    );
    return _readCart(response);
  }

  Future<SavedCart> updateCart({
    required String authToken,
    required SavedCart cart,
  }) async {
    final response = await _send(
      'PATCH',
      '/v1/carts/${cart.id}',
      authToken: authToken,
      body: {
        'title': cart.title,
        'items': cart.items.map((item) => item.toJson()).toList(),
      },
    );
    return _readCart(response);
  }

  Future<void> deleteCart({
    required String authToken,
    required String cartId,
  }) async {
    await _send('DELETE', '/v1/carts/$cartId', authToken: authToken);
  }

  Future<SavedCart> extendCartRetention({
    required String authToken,
    required String cartId,
  }) async {
    final response = await _send(
      'POST',
      '/v1/carts/$cartId/retention/extend',
      authToken: authToken,
    );
    return _readCart(response);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    required String authToken,
    Map<String, dynamic>? body,
  }) async {
    final request = switch (method) {
      'GET' => await _httpClient.getUrl(_uri(path)),
      'POST' => await _httpClient.postUrl(_uri(path)),
      'PATCH' => await _httpClient.patchUrl(_uri(path)),
      'DELETE' => await _httpClient.deleteUrl(_uri(path)),
      _ => throw ArgumentError('Unsupported method: $method'),
    };

    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');

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
      throw RemoteCartException(_errorMessage(decoded, '카트 요청에 실패했어'));
    }

    final ok = decoded['ok'];
    if (ok is bool && !ok) {
      throw RemoteCartException(_errorMessage(decoded, '카트 요청에 실패했어'));
    }

    return decoded;
  }

  SavedCart _readCart(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const RemoteCartException('카트 응답 형식이 올바르지 않아');
    }
    final cart = data['cart'];
    if (cart is! Map<String, dynamic>) {
      throw const RemoteCartException('카트 정보를 읽지 못했어');
    }
    return SavedCart.fromJson(cart);
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
}

class RemoteCartException implements Exception {
  final String message;
  const RemoteCartException(this.message);

  @override
  String toString() => message;
}
