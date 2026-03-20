import '../models/recognized_item_candidate.dart';
import '../models/scan_job.dart';
import 'scan_repository.dart';

class RemoteScanRepository implements ScanRepository {
  final String baseUrl;
  final String? authToken;

  const RemoteScanRepository({
    required this.baseUrl,
    this.authToken,
  });

  @override
  Future<ScanJob> submitImage(String imagePath) async {
    throw UnimplementedError('Remote submitImage is not wired yet');
  }

  @override
  Future<ScanJob> getJob(String jobId) async {
    throw UnimplementedError('Remote getJob is not wired yet');
  }

  @override
  Future<RecognizedItemCandidate?> getResult(String jobId) async {
    throw UnimplementedError('Remote getResult is not wired yet');
  }
}
