import 'dart:convert';
import 'dart:io';

import '../app_support.dart';
import 'api_base.dart';

class SharedCurrentCartSnapshot {
  final bool shared;
  final List<CartItem> items;

  const SharedCurrentCartSnapshot({required this.shared, required this.items});
}

SharedCurrentCartSnapshot _snapshotFromJson(Map<String, dynamic> data) {
  final shared = data['shared'] == true;
  final cart = data['cart'];
  final itemsRaw = cart is Map<String, dynamic>
      ? (cart['items'] as List? ?? const [])
      : const [];
  final items = itemsRaw
      .whereType<Map>()
      .map(
        (item) => CartItem(
          id: item['id'] as String?,
          name: (item['name'] ?? '') as String,
          price: (item['price'] ?? 0) as int,
          quantity: (item['quantity'] ?? 1) as int,
          source: item['source'] as String?,
          scanJobId: item['scanResultId'] as String?,
          originalRecognizedName: item['originalName'] as String?,
        ),
      )
      .toList(growable: false);
  return SharedCurrentCartSnapshot(shared: shared, items: items);
}

class RemoteCurrentCartRepository {
  RemoteCurrentCartRepository({HttpClient? httpClient})
    : _httpClient =
          httpClient ??
          (HttpClient()..connectionTimeout = const Duration(seconds: 4));

  static const Duration _requestTimeout = Duration(seconds: 8);

  final HttpClient _httpClient;

  Uri _uri(String path) => Uri.parse('${getCartlyApiBaseUrl()}$path');

  Future<SharedCurrentCartSnapshot> getCurrentCart(String authToken) async {
    final response = await _send(
      'GET',
      '/v1/households/current-cart',
      authToken: authToken,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const RemoteCurrentCartException('현재 카트 응답 형식이 올바르지 않아');
    }
    return _snapshotFromJson(data);
  }

  Future<SharedCurrentCartSnapshot> addItem(
    String authToken,
    CartItem item,
  ) async {
    final response = await _send(
      'POST',
      '/v1/households/current-cart/items',
      authToken: authToken,
      body: {
        'id': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'source': item.source,
        'scanResultId': item.scanJobId,
        'originalName': item.originalRecognizedName,
      },
    );
    return _readCartSnapshot(response);
  }

  Future<SharedCurrentCartSnapshot> updateItem(
    String authToken,
    CartItem item,
  ) async {
    final response = await _send(
      'PATCH',
      '/v1/households/current-cart/items/${item.id}',
      authToken: authToken,
      body: {
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'source': item.source,
        'scanResultId': item.scanJobId,
        'originalName': item.originalRecognizedName,
      },
    );
    return _readCartSnapshot(response);
  }

  Future<SharedCurrentCartSnapshot> deleteItem(
    String authToken,
    String itemId,
  ) async {
    final response = await _send(
      'DELETE',
      '/v1/households/current-cart/items/$itemId',
      authToken: authToken,
    );
    return _readCartSnapshot(response);
  }

  Future<SharedCurrentCartSnapshot> clear(String authToken) async {
    final response = await _send(
      'DELETE',
      '/v1/households/current-cart',
      authToken: authToken,
    );
    return _readCartSnapshot(response);
  }

  SharedCurrentCartSnapshot _readCartSnapshot(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const RemoteCurrentCartException('현재 카트 응답 형식이 올바르지 않아');
    }
    final cart = data['cart'];
    if (cart is! Map<String, dynamic>) {
      throw const RemoteCurrentCartException('현재 카트 정보를 읽지 못했어');
    }
    return _snapshotFromJson({'shared': true, 'cart': cart});
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
      'PATCH' =>
        await _httpClient.patchUrl(_uri(path)).timeout(_requestTimeout),
      'DELETE' =>
        await _httpClient.deleteUrl(_uri(path)).timeout(_requestTimeout),
      _ => throw ArgumentError('Unsupported method: $method'),
    };

    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');

    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final response = await request.close().timeout(_requestTimeout);
    final responseBody = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_requestTimeout);
    final decoded = responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteCurrentCartException(
        _errorMessage(decoded, '현재 카트 요청에 실패했어'),
      );
    }

    final ok = decoded['ok'];
    if (ok is bool && !ok) {
      throw RemoteCurrentCartException(
        _errorMessage(decoded, '현재 카트 요청에 실패했어'),
      );
    }

    return decoded;
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

class RemoteCurrentCartException implements Exception {
  final String message;
  const RemoteCurrentCartException(this.message);

  @override
  String toString() => message;
}
