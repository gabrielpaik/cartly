enum ScanJobStatus { queued, uploading, processing, done, failed }

class ScanJob {
  final String jobId;
  final ScanJobStatus status;
  final String imagePath;
  final DateTime createdAt;
  final String? errorMessage;

  const ScanJob({
    required this.jobId,
    required this.status,
    required this.imagePath,
    required this.createdAt,
    this.errorMessage,
  });

  ScanJob copyWith({
    String? jobId,
    ScanJobStatus? status,
    String? imagePath,
    DateTime? createdAt,
    String? errorMessage,
  }) {
    return ScanJob(
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
