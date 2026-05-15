class AppAdLanding {
  final String type;
  final String key;
  final Map<String, dynamic> params;

  const AppAdLanding({
    required this.type,
    required this.key,
    required this.params,
  });

  bool get isValid => type.trim().isNotEmpty && key.trim().isNotEmpty;

  static AppAdLanding? fromMap(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    final type = (data['landingType'] as String?)?.trim() ??
        (data['type'] as String?)?.trim() ??
        '';
    final key = (data['landingKey'] as String?)?.trim() ??
        (data['key'] as String?)?.trim() ??
        '';
    final rawParams = data['landingParams'] ?? data['params'];
    final params = rawParams is Map
        ? Map<String, dynamic>.from(rawParams)
        : const <String, dynamic>{};
    if (type.isEmpty || key.isEmpty) {
      return null;
    }
    return AppAdLanding(type: type, key: key, params: params);
  }
}

class AppAdCreative {
  final String campaignId;
  final String creativeId;
  final String title;
  final String message;
  final String? ctaLabel;
  final String? targetUrl;
  final String? imageUrl;
  final int sortOrder;
  final String? startAt;
  final String? endAt;
  final AppAdLanding? landing;

  const AppAdCreative({
    required this.campaignId,
    required this.creativeId,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.targetUrl,
    required this.imageUrl,
    required this.sortOrder,
    required this.startAt,
    required this.endAt,
    required this.landing,
  });

  bool get hasAction {
    return (targetUrl?.trim().isNotEmpty ?? false) || (landing?.isValid ?? false);
  }

  factory AppAdCreative.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};

    String? nullableString(String key) {
      final value = (data[key] as String?)?.trim();
      return value != null && value.isNotEmpty ? value : null;
    }

    int intValue(String key, int fallback) {
      final value = data[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    return AppAdCreative(
      campaignId: nullableString('campaignId') ?? '',
      creativeId: nullableString('creativeId') ?? nullableString('campaignId') ?? '',
      title: nullableString('title') ?? '',
      message: nullableString('message') ?? '',
      ctaLabel: nullableString('ctaLabel'),
      targetUrl: nullableString('targetUrl'),
      imageUrl: nullableString('imageUrl'),
      sortOrder: intValue('sortOrder', 1),
      startAt: nullableString('startAt'),
      endAt: nullableString('endAt'),
      landing: AppAdLanding.fromMap(data),
    );
  }
}

class AppAdSlotConfig {
  final double maxHeight;
  final String? screen;
  final String? position;
  final String tone;
  final String title;
  final String message;
  final String? ctaLabel;
  final String? targetUrl;
  final String? imageUrl;
  final String? campaignId;
  final AppAdLanding? landing;
  final List<AppAdCreative> creatives;
  final String rotationMode;

  const AppAdSlotConfig({
    required this.maxHeight,
    required this.screen,
    required this.position,
    required this.tone,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.targetUrl,
    required this.imageUrl,
    required this.campaignId,
    required this.landing,
    required this.creatives,
    required this.rotationMode,
  });

  AppAdCreative? get primaryCreative {
    if (creatives.isNotEmpty) {
      return creatives.first;
    }
    final fallbackCampaignId = campaignId?.trim() ?? '';
    final hasContent = title.trim().isNotEmpty ||
        message.trim().isNotEmpty ||
        (imageUrl?.trim().isNotEmpty ?? false);
    if (fallbackCampaignId.isEmpty && !hasContent) {
      return null;
    }
    return AppAdCreative(
      campaignId: fallbackCampaignId,
      creativeId: fallbackCampaignId,
      title: title,
      message: message,
      ctaLabel: ctaLabel,
      targetUrl: targetUrl,
      imageUrl: imageUrl,
      sortOrder: 1,
      startAt: null,
      endAt: null,
      landing: landing,
    );
  }

  factory AppAdSlotConfig.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};

    double doubleValue(String key, double fallback) {
      final value = data[key];
      if (value is num) return value.toDouble();
      return fallback;
    }

    String? nullableString(String key) {
      final value = (data[key] as String?)?.trim();
      return value != null && value.isNotEmpty ? value : null;
    }

    final creativesJson = data['creatives'] as List?;
    final creatives = creativesJson == null
        ? const <AppAdCreative>[]
        : creativesJson
              .whereType<Map>()
              .map((item) => AppAdCreative.fromJson(Map<String, dynamic>.from(item)))
              .where((item) => item.campaignId.trim().isNotEmpty)
              .toList();

    return AppAdSlotConfig(
      maxHeight: doubleValue('maxHeight', 96),
      screen: nullableString('screen'),
      position: nullableString('position'),
      tone: nullableString('tone') ?? 'benefit_native',
      title: nullableString('title') ?? '',
      message: nullableString('message') ?? '',
      ctaLabel: nullableString('ctaLabel'),
      targetUrl: nullableString('targetUrl'),
      imageUrl: nullableString('imageUrl'),
      campaignId: nullableString('campaignId'),
      landing: AppAdLanding.fromMap(data),
      creatives: creatives,
      rotationMode: nullableString('rotationMode') ??
          (creatives.length > 1 ? 'ordered' : 'single'),
    );
  }
}

class AppAdSlot {
  final String slotKey;
  final String placementType;
  final bool enabled;
  final AppAdSlotConfig config;

  const AppAdSlot({
    required this.slotKey,
    required this.placementType,
    required this.enabled,
    required this.config,
  });

  factory AppAdSlot.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return AppAdSlot(
      slotKey: ((data['slotKey'] as String?) ?? '').trim(),
      placementType: ((data['placementType'] as String?) ?? '').trim(),
      enabled: data['enabled'] == true,
      config: AppAdSlotConfig.fromJson(data['config'] as Map<String, dynamic>?),
    );
  }

  static const fallback = AppAdSlot(
    slotKey: '',
    placementType: 'inline',
    enabled: false,
    config: AppAdSlotConfig(
      maxHeight: 96,
      screen: null,
      position: null,
      tone: 'benefit_native',
      title: '',
      message: '',
      ctaLabel: null,
      targetUrl: null,
      imageUrl: null,
      campaignId: null,
      landing: null,
      creatives: <AppAdCreative>[],
      rotationMode: 'single',
    ),
  );
}
