enum ExploreOfferSourceType {
  currentCart,
  pendingReview,
  repeatPurchase,
}

class ExploreOfferSignal {
  final String intentKey;
  final String anchorName;
  final int anchorPrice;
  final ExploreOfferSourceType sourceType;
  final String sourceLabel;
  final String context;
  final String ctaLabel;
  final List<String> comparePoints;

  const ExploreOfferSignal({
    required this.intentKey,
    required this.anchorName,
    required this.anchorPrice,
    required this.sourceType,
    required this.sourceLabel,
    required this.context,
    required this.ctaLabel,
    required this.comparePoints,
  });
}

class ExploreOfferQuery {
  final String intentKey;
  final String queryText;
  final int? referencePrice;
  final ExploreOfferSourceType sourceType;

  const ExploreOfferQuery({
    required this.intentKey,
    required this.queryText,
    required this.sourceType,
    this.referencePrice,
  });

  Map<String, String> toQueryParameters() {
    return {
      'intentKey': intentKey,
      'q': queryText,
      'sourceType': sourceType.name,
      if (referencePrice != null) 'referencePrice': '$referencePrice',
    };
  }
}

class ExploreOfferSlot {
  final String intentKey;
  final String anchorName;
  final int anchorPrice;
  final ExploreOfferSourceType sourceType;
  final String sourceLabel;
  final String context;
  final String ctaLabel;
  final List<String> comparePoints;
  final ExploreOfferQuery query;

  const ExploreOfferSlot({
    required this.intentKey,
    required this.anchorName,
    required this.anchorPrice,
    required this.sourceType,
    required this.sourceLabel,
    required this.context,
    required this.ctaLabel,
    required this.comparePoints,
    required this.query,
  });
}

class ExploreAlternativeOffer {
  final String provider;
  final String title;
  final String? subtitle;
  final int? price;
  final String? deeplinkUrl;
  final List<String> highlights;

  const ExploreAlternativeOffer({
    required this.provider,
    required this.title,
    this.subtitle,
    this.price,
    this.deeplinkUrl,
    this.highlights = const [],
  });

  factory ExploreAlternativeOffer.fromJson(Map<String, dynamic> json) {
    return ExploreAlternativeOffer(
      provider: (json['provider'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      subtitle: (json['subtitle'] as String?)?.trim(),
      price: json['price'] is int ? json['price'] as int : int.tryParse('${json['price'] ?? ''}'),
      deeplinkUrl: (json['deeplinkUrl'] as String?)?.trim(),
      highlights: (json['highlights'] as List?)
              ?.map((item) => item?.toString().trim())
              .whereType<String>()
              .where((item) => item.isNotEmpty)
              .toList() ??
          const [],
    );
  }

  ExploreAlternativeOffer copyWith({
    String? provider,
    String? title,
    String? subtitle,
    int? price,
    String? deeplinkUrl,
    List<String>? highlights,
  }) {
    return ExploreAlternativeOffer(
      provider: provider ?? this.provider,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      price: price ?? this.price,
      deeplinkUrl: deeplinkUrl ?? this.deeplinkUrl,
      highlights: highlights ?? this.highlights,
    );
  }
}
