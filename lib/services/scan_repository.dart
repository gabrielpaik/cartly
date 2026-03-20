import '../models/recognized_item_candidate.dart';
import '../models/scan_job.dart';

abstract class ScanRepository {
  Future<ScanJob> submitImage(String imagePath);
  Future<ScanJob> getJob(String jobId);
  Future<RecognizedItemCandidate?> getResult(String jobId);
}
