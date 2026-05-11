enum ExploreOfferSourceType { currentCart, pendingReview, repeatPurchase }

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

class ExploreStorePromo {
  final String id;
  final String title;
  final String body;
  final String badgeLabel;
  final String storeName;
  final String ctaLabel;
  final String placementLabel;
  final String intentHint;
  final String source;
  final String sourceType;
  final int priority;
  final bool isSponsored;
  final String? sponsorLabel;

  const ExploreStorePromo({
    required this.id,
    required this.title,
    required this.body,
    required this.badgeLabel,
    required this.storeName,
    required this.ctaLabel,
    required this.placementLabel,
    required this.intentHint,
    required this.source,
    required this.sourceType,
    required this.priority,
    required this.isSponsored,
    this.sponsorLabel,
  });

  factory ExploreStorePromo.fromJson(Map<String, dynamic> json) {
    String text(String key, String fallback) {
      final value = (json[key] as String?)?.trim();
      return value == null || value.isEmpty ? fallback : value;
    }

    final rawPriority = json['priority'];
    final priority = rawPriority is int
        ? rawPriority
        : int.tryParse('${json['priority'] ?? ''}') ?? 100;
    final isSponsored =
        json['isSponsored'] == true ||
        '${json['isSponsored']}'.trim().toLowerCase() == 'true';
    final sponsorLabelValue = (json['sponsorLabel'] as String?)?.trim();

    return ExploreStorePromo(
      id: text('id', 'store-promo'),
      title: text('title', '지금 이 마트 세일'),
      body: text('body', '자주 사는 상품군과 겹치는 할인 행사부터 먼저 보여줘요.'),
      badgeLabel: text('badgeLabel', '행사'),
      storeName: text('storeName', '이마트 양재점'),
      ctaLabel: text('ctaLabel', '행사 보기'),
      placementLabel: text('placementLabel', '매장 프로모션'),
      intentHint: text('intentHint', '같은 구매 의도 기준'),
      source: text('source', 'store-context-preview'),
      sourceType: text('sourceType', 'storeSale'),
      priority: priority,
      isSponsored: isSponsored,
      sponsorLabel: sponsorLabelValue == null || sponsorLabelValue.isEmpty
          ? null
          : sponsorLabelValue,
    );
  }
}

class ExploreAlternativeOffer {
  final String provider;
  final String title;
  final String? subtitle;
  final int? price;
  final String? thumbnailUrl;
  final String? deeplinkUrl;
  final List<String> highlights;

  const ExploreAlternativeOffer({
    required this.provider,
    required this.title,
    this.subtitle,
    this.price,
    this.thumbnailUrl,
    this.deeplinkUrl,
    this.highlights = const [],
  });

  factory ExploreAlternativeOffer.fromJson(Map<String, dynamic> json) {
    return ExploreAlternativeOffer(
      provider: (json['provider'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      subtitle: (json['subtitle'] as String?)?.trim(),
      price: json['price'] is int
          ? json['price'] as int
          : int.tryParse('${json['price'] ?? ''}'),
      thumbnailUrl: (json['thumbnailUrl'] as String?)?.trim(),
      deeplinkUrl: (json['deeplinkUrl'] as String?)?.trim(),
      highlights:
          (json['highlights'] as List?)
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
    String? thumbnailUrl,
    String? deeplinkUrl,
    List<String>? highlights,
  }) {
    return ExploreAlternativeOffer(
      provider: provider ?? this.provider,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      price: price ?? this.price,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      deeplinkUrl: deeplinkUrl ?? this.deeplinkUrl,
      highlights: highlights ?? this.highlights,
    );
  }
}
