class RecognizedItemCandidate {
  final String name;
  final int price;
  final String? sku;
  final double? confidence;
  final String source;
  final String? rawText;
  final String? scanJobId;

  const RecognizedItemCandidate({
    required this.name,
    required this.price,
    this.sku,
    this.confidence,
    required this.source,
    this.rawText,
    this.scanJobId,
  });
}
