import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/recognized_item.dart';
import '../models/recognized_item_candidate.dart';
import '../models/scan_job.dart';
import 'scan_repository.dart';

class RemoteScanRepository implements ScanRepository {
  final String baseUrl;
  final String? authToken;
  final String? Function()? authTokenProvider;
  final HttpClient _httpClient;

  RemoteScanRepository({
    required this.baseUrl,
    this.authToken,
    this.authTokenProvider,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  @override
  Future<ScanJob> submitImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw const ScanRepositoryException('업로드할 이미지를 찾지 못했어요');
    }

    final request = await _httpClient.postUrl(_uri('/v1/scan/jobs'));
    _applyDefaultHeaders(request);

    final boundary = 'wimc-${DateTime.now().microsecondsSinceEpoch}';
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );

    final fileName = imagePath.split(Platform.pathSeparator).last;
    final imageBytes = await file.readAsBytes();
    request.add(
      _buildMultipartBody(
        boundary: boundary,
        fileName: fileName,
        imageBytes: imageBytes,
      ),
    );

    final responseJson = await _sendJson(request);
    final jobJson = _jobJsonFromEnvelope(responseJson);

    return ScanJob(
      jobId: _readString(jobJson, 'id'),
      status: _parseStatus(_readString(jobJson, 'status')),
      imagePath: imagePath,
      createdAt: _parseDateTime(jobJson['createdAt']) ?? DateTime.now(),
      errorMessage: _nullableString(jobJson['errorMessage']),
    );
  }

  @override
  Future<ScanJob> getJob(String jobId) async {
    final request = await _httpClient.getUrl(_uri('/v1/scan/jobs/$jobId'));
    _applyDefaultHeaders(request);

    final responseJson = await _sendJson(request);
    final jobJson = _jobJsonFromEnvelope(responseJson);

    return ScanJob(
      jobId: _readString(jobJson, 'id'),
      status: _parseStatus(_readString(jobJson, 'status')),
      imagePath: '',
      createdAt: _parseDateTime(jobJson['createdAt']) ?? DateTime.now(),
      errorMessage: _nullableString(jobJson['errorMessage']),
    );
  }

  @override
  Future<RecognizedItemCandidate?> getResult(String jobId) async {
    final request = await _httpClient.getUrl(
      _uri('/v1/scan/jobs/$jobId/result'),
    );
    _applyDefaultHeaders(request);

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final jsonBody = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode == HttpStatus.notFound) {
      throw const ScanRepositoryException('스캔 작업을 찾지 못했어요');
    }

    if (response.statusCode >= HttpStatus.badRequest) {
      final message = _extractErrorMessage(jsonBody) ?? '분석 결과를 불러오지 못했어요';
      if (_extractErrorCode(jsonBody) == 'RESULT_NOT_READY') {
        return null;
      }
      throw ScanRepositoryException(message);
    }

    final ok = jsonBody['ok'];
    if (ok is bool && !ok) {
      if (_extractErrorCode(jsonBody) == 'RESULT_NOT_READY') {
        return null;
      }
      throw ScanRepositoryException(
        _extractErrorMessage(jsonBody) ?? '분석 결과를 불러오지 못했어요',
      );
    }

    final data = jsonBody['data'];
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final result = data['result'];
    if (result is! Map<String, dynamic>) {
      return null;
    }

    return RecognizedItemCandidate(
      name: _readString(result, 'name'),
      price: _readInt(result, 'price'),
      sku: _nullableString(result['sku']),
      confidence: _nullableDouble(result['confidence']),
      source: _readString(result, 'source'),
      rawText: _nullableString(result['rawText']),
      scanJobId: _nullableString(data['jobId']) ?? jobId,
    );
  }

  @override
  Future<void> submitFeedback({
    required String jobId,
    required bool accepted,
    required RecognizedItemCandidate original,
    RecognizedItem? corrected,
  }) async {
    final request = await _httpClient.postUrl(
      _uri('/v1/scan/jobs/$jobId/feedback'),
    );
    _applyDefaultHeaders(request);
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'accepted': accepted,
        'original': _candidateToJson(original),
        'corrected': corrected == null ? null : _recognizedToJson(corrected),
      }),
    );
    await _sendJson(request);
  }

  @override
  Future<void> reportFailure({
    required String jobId,
    required String stage,
    String? errorCode,
    String? errorMessage,
    Map<String, dynamic>? details,
  }) async {
    final request = await _httpClient.postUrl(
      _uri('/v1/scan/jobs/$jobId/failures'),
    );
    _applyDefaultHeaders(request);
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'stage': stage,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'details': details,
      }),
    );
    await _sendJson(request);
  }

  void _applyDefaultHeaders(HttpClientRequest request) {
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final token = (authTokenProvider?.call() ?? authToken)?.trim();
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
  }

  Future<Map<String, dynamic>> _sendJson(HttpClientRequest request) async {
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final jsonBody = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ScanRepositoryException(
        _extractErrorMessage(jsonBody) ?? '원격 스캔 서버 요청에 실패했어요',
      );
    }

    final ok = jsonBody['ok'];
    if (ok is bool && !ok) {
      throw ScanRepositoryException(
        _extractErrorMessage(jsonBody) ?? '원격 스캔 서버가 요청을 처리하지 못했어요',
      );
    }

    return jsonBody;
  }

  Uint8List _buildMultipartBody({
    required String boundary,
    required String fileName,
    required Uint8List imageBytes,
  }) {
    final builder = BytesBuilder();
    final prefix = StringBuffer()
      ..write('--$boundary\r\n')
      ..write(
        'Content-Disposition: form-data; name="image"; filename="$fileName"\r\n',
      )
      ..write('Content-Type: image/jpeg\r\n\r\n');

    builder.add(utf8.encode(prefix.toString()));
    builder.add(imageBytes);
    builder.add(utf8.encode('\r\n--$boundary--\r\n'));
    return builder.toBytes();
  }

  Map<String, dynamic> _jobJsonFromEnvelope(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const ScanRepositoryException('원격 스캔 응답 형식이 올바르지 않아요');
    }

    final job = data['job'];
    if (job is! Map<String, dynamic>) {
      throw const ScanRepositoryException('원격 스캔 작업 정보가 비어 있어요');
    }

    return job;
  }

  Map<String, dynamic> _candidateToJson(RecognizedItemCandidate candidate) => {
    'name': candidate.name,
    'price': candidate.price,
    'sku': candidate.sku,
    'confidence': candidate.confidence,
    'source': candidate.source,
    'rawText': candidate.rawText,
  };

  Map<String, dynamic> _recognizedToJson(RecognizedItem item) => {
    'name': item.name,
    'price': item.price,
    'sku': item.sku,
    'confidence': item.confidence,
    'source': item.source,
    'rawText': item.rawText,
  };

  String _readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw ScanRepositoryException('응답에 $key 값이 없어요');
  }

  int _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw ScanRepositoryException('응답에 $key 값이 없어요');
  }

  String? _nullableString(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  double? _nullableDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  DateTime? _parseDateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  ScanJobStatus _parseStatus(String value) {
    return switch (value) {
      'queued' => ScanJobStatus.queued,
      'uploading' => ScanJobStatus.uploading,
      'processing' => ScanJobStatus.processing,
      'done' => ScanJobStatus.done,
      'failed' => ScanJobStatus.failed,
      _ => throw ScanRepositoryException('알 수 없는 스캔 상태예요: $value'),
    };
  }

  String? _extractErrorMessage(Map<String, dynamic> json) {
    final error = json['error'];
    if (error is Map<String, dynamic>) {
      return _nullableString(error['message']);
    }
    return null;
  }

  String? _extractErrorCode(Map<String, dynamic> json) {
    final error = json['error'];
    if (error is Map<String, dynamic>) {
      return _nullableString(error['code']);
    }
    return null;
  }
}

class ScanRepositoryException implements Exception {
  final String message;
  const ScanRepositoryException(this.message);

  @override
  String toString() => message;
}
