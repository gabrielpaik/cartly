import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/receipt_compare.dart';
import 'api_base.dart';

class RemoteReceiptRepository {
  final String baseUrl;
  final String? authToken;
  final String? Function()? authTokenProvider;
  final HttpClient _httpClient;

  RemoteReceiptRepository({
    String? baseUrl,
    this.authToken,
    this.authTokenProvider,
    HttpClient? httpClient,
  }) : baseUrl = (baseUrl ?? getCartlyApiBaseUrl()).replaceAll(RegExp(r'/$'), ''),
       _httpClient = httpClient ?? HttpClient();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<ReceiptSummaryModel> createReceipt({
    required String savedCartId,
    required String imagePath,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw const RemoteReceiptException('업로드할 영수증 이미지를 찾지 못했어요');
    }

    final request = await _httpClient.postUrl(_uri('/v1/receipts'));
    _applyDefaultHeaders(request);

    final boundary = 'cartly-receipt-${DateTime.now().microsecondsSinceEpoch}';
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );

    final imageBytes = await file.readAsBytes();
    final fileName = imagePath.split(Platform.pathSeparator).last;
    request.add(
      _buildMultipartBody(
        boundary: boundary,
        fields: {'savedCartId': savedCartId},
        fileFieldName: 'image',
        fileName: fileName,
        fileBytes: imageBytes,
      ),
    );

    final response = await _sendJson(request, fallbackMessage: '영수증 업로드에 실패했어요');
    final data = _readData(response);
    final receipt = data['receipt'];
    if (receipt is! Map<String, dynamic>) {
      throw const RemoteReceiptException('영수증 응답 형식이 올바르지 않아요');
    }
    return ReceiptSummaryModel.fromJson(receipt);
  }

  Future<ReceiptSummaryModel> getReceipt(String receiptId) async {
    final request = await _httpClient.getUrl(_uri('/v1/receipts/$receiptId'));
    _applyDefaultHeaders(request);
    final response = await _sendJson(request, fallbackMessage: '영수증 정보를 불러오지 못했어요');
    final data = _readData(response);
    final receipt = data['receipt'];
    if (receipt is! Map<String, dynamic>) {
      throw const RemoteReceiptException('영수증 정보가 비어 있어요');
    }
    return ReceiptSummaryModel.fromJson(receipt);
  }

  Future<ReceiptCompareResultModel> getResult(String receiptId) async {
    final request = await _httpClient.getUrl(_uri('/v1/receipts/$receiptId/result'));
    _applyDefaultHeaders(request);
    final response = await _sendJson(request, fallbackMessage: '영수증 비교 결과를 불러오지 못했어요');
    final data = _readData(response);
    return ReceiptCompareResultModel.fromJson(data);
  }

  void _applyDefaultHeaders(HttpClientRequest request) {
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final token = (authTokenProvider?.call() ?? authToken)?.trim();
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
  }

  Future<Map<String, dynamic>> _sendJson(
    HttpClientRequest request, {
    required String fallbackMessage,
  }) async {
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final jsonBody = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode >= HttpStatus.badRequest) {
      throw RemoteReceiptException(
        _extractErrorMessage(jsonBody) ?? fallbackMessage,
        code: _extractErrorCode(jsonBody),
      );
    }

    final ok = jsonBody['ok'];
    if (ok is bool && !ok) {
      throw RemoteReceiptException(
        _extractErrorMessage(jsonBody) ?? fallbackMessage,
        code: _extractErrorCode(jsonBody),
      );
    }

    return jsonBody;
  }

  Map<String, dynamic> _readData(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const RemoteReceiptException('영수증 응답 형식이 올바르지 않아요');
  }

  Uint8List _buildMultipartBody({
    required String boundary,
    required Map<String, String> fields,
    required String fileFieldName,
    required String fileName,
    required Uint8List fileBytes,
  }) {
    final builder = BytesBuilder();

    for (final entry in fields.entries) {
      builder.add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n'
          '${entry.value}\r\n',
        ),
      );
    }

    builder.add(
      utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="$fileFieldName"; filename="$fileName"\r\n'
        'Content-Type: image/jpeg\r\n\r\n',
      ),
    );
    builder.add(fileBytes);
    builder.add(utf8.encode('\r\n--$boundary--\r\n'));

    return builder.toBytes();
  }

  String? _extractErrorMessage(Map<String, dynamic> json) {
    final detail = json['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is Map<String, dynamic>) {
      final message = detail['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }

    final error = json['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  String? _extractErrorCode(Map<String, dynamic> json) {
    final detail = json['detail'];
    if (detail is Map<String, dynamic>) {
      final code = detail['code'];
      if (code is String && code.isNotEmpty) {
        return code;
      }
    }

    final error = json['error'];
    if (error is Map<String, dynamic>) {
      final code = error['code'];
      if (code is String && code.isNotEmpty) {
        return code;
      }
    }
    return null;
  }
}

class RemoteReceiptException implements Exception {
  final String message;
  final String? code;

  const RemoteReceiptException(this.message, {this.code});

  @override
  String toString() => message;
}
