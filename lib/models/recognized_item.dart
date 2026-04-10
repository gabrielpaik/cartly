import 'recognized_item_candidate.dart';

class RecognizedItem {
  final String name;
  final int price;
  final String? sku;
  final double? confidence;
  final String? source;
  final String? rawText;
  final String? scanJobId;

  RecognizedItem({
    required this.name,
    required this.price,
    this.sku,
    this.confidence,
    this.source,
    this.rawText,
    this.scanJobId,
  });

  factory RecognizedItem.fromCandidate(RecognizedItemCandidate candidate) {
    return RecognizedItem(
      name: candidate.name,
      price: candidate.price,
      sku: candidate.sku,
      confidence: candidate.confidence,
      source: candidate.source,
      rawText: candidate.rawText,
      scanJobId: candidate.scanJobId,
    );
  }

  RecognizedItem copyWith({
    String? name,
    int? price,
    String? sku,
    double? confidence,
    String? source,
    String? rawText,
    String? scanJobId,
  }) {
    return RecognizedItem(
      name: name ?? this.name,
      price: price ?? this.price,
      sku: sku ?? this.sku,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      rawText: rawText ?? this.rawText,
      scanJobId: scanJobId ?? this.scanJobId,
    );
  }
}
