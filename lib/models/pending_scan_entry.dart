import 'recognized_item.dart';
import 'recognized_item_candidate.dart';

enum PendingScanStatus { captured, uploading, processing, ready, failed, added }

class PendingScanEntry {
  final String id;
  final String? imagePath;
  final PendingScanStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final RecognizedItem? item;
  final RecognizedItemCandidate? candidate;
  final String? errorMessage;
  final String? scanJobId;

  const PendingScanEntry({
    required this.id,
    required this.status,
    required this.createdAt,
    this.imagePath,
    this.completedAt,
    this.item,
    this.candidate,
    this.errorMessage,
    this.scanJobId,
  });

  PendingScanEntry copyWith({
    String? id,
    String? imagePath,
    PendingScanStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    RecognizedItem? item,
    RecognizedItemCandidate? candidate,
    String? errorMessage,
    String? scanJobId,
  }) {
    return PendingScanEntry(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      item: item ?? this.item,
      candidate: candidate ?? this.candidate,
      errorMessage: errorMessage ?? this.errorMessage,
      scanJobId: scanJobId ?? this.scanJobId,
    );
  }
}

class PendingScanStateSnapshot {
  final List<PendingScanEntry> entries;
  final String? activeEntryId;

  const PendingScanStateSnapshot({
    required this.entries,
    this.activeEntryId,
  });
}
