import '../models/recognized_item.dart';
import '../models/recognized_item_candidate.dart';
import '../models/scan_job.dart';

abstract class ScanRepository {
  Future<ScanJob> submitImage(String imagePath);
  Future<ScanJob> getJob(String jobId);
  Future<RecognizedItemCandidate?> getResult(String jobId);

  Future<void> submitFeedback({
    required String jobId,
    required bool accepted,
    required RecognizedItemCandidate original,
    RecognizedItem? corrected,
  });

  Future<void> reportFailure({
    required String jobId,
    required String stage,
    String? errorCode,
    String? errorMessage,
    Map<String, dynamic>? details,
  });
}
