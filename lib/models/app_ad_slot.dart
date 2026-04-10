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
  });

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
    ),
  );
}
