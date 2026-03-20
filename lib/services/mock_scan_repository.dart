import 'dart:async';

import '../models/recognized_item_candidate.dart';
import '../models/scan_job.dart';
import 'label_analyzer.dart';
import 'scan_repository.dart';

class MockScanRepository implements ScanRepository {
  final LabelAnalyzer analyzer;
  final Map<String, ScanJob> _jobs = {};
  final Map<String, RecognizedItemCandidate?> _results = {};

  MockScanRepository({required this.analyzer});

  @override
  Future<ScanJob> submitImage(String imagePath) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    var job = ScanJob(
      jobId: id,
      status: ScanJobStatus.uploading,
      imagePath: imagePath,
      createdAt: DateTime.now(),
    );
    _jobs[id] = job;

    unawaited(_process(id, imagePath));
    return job;
  }

  Future<void> _process(String jobId, String imagePath) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _jobs[jobId] = _jobs[jobId]!.copyWith(status: ScanJobStatus.processing);

    try {
      final result = await analyzer.analyze(imagePath);
      await Future.delayed(const Duration(milliseconds: 900));

      if (result == null) {
        _results[jobId] = null;
        _jobs[jobId] = _jobs[jobId]!.copyWith(
          status: ScanJobStatus.failed,
          errorMessage: '텍스트를 인식하지 못했어요',
        );
        return;
      }

      _results[jobId] = RecognizedItemCandidate(
        name: result.name,
        price: result.price,
        source: 'mock-local',
        confidence: 0.72,
      );
      _jobs[jobId] = _jobs[jobId]!.copyWith(status: ScanJobStatus.done);
    } catch (_) {
      _results[jobId] = null;
      _jobs[jobId] = _jobs[jobId]!.copyWith(
        status: ScanJobStatus.failed,
        errorMessage: '분석 중 오류가 났어요',
      );
    }
  }

  @override
  Future<ScanJob> getJob(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) {
      throw StateError('job not found: $jobId');
    }
    return job;
  }

  @override
  Future<RecognizedItemCandidate?> getResult(String jobId) async {
    return _results[jobId];
  }
}
