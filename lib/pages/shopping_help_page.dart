import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/cartly_ui.dart';

import '../app_support.dart';
import '../models/explore_offer.dart';
import '../models/saved_cart.dart';
import '../pages/cart_detail_page.dart';
import '../services/app_config_store.dart';
import '../services/app_location_service.dart';
import '../services/app_runtime_copy.dart';
import '../services/cart_store.dart';
import '../services/cart_title_formatter.dart';
import '../services/cart_title_suggester.dart';
import '../services/explore_intent_normalizer.dart';
import '../services/explore_offer_service.dart';
import '../widgets/cartly_badge.dart';
import '../widgets/cartly_surface_card.dart';
import '../widgets/cartly_symbol_icon.dart';
import '../widgets/section_header.dart';

const ExploreOfferProvider _offerProvider = HybridExploreOfferProvider();

const String _exploreStateActiveShopping = 'activeShopping';
const String _exploreStatePostSave = 'postSave';
const String _exploreStateIdlePlanning = 'idlePlanning';
const String _exploreStateStoreContext = 'storeContext';

class ShoppingHelpPage extends StatefulWidget {
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;
  final List<ConsideredProductEntry> consideredItems;
  final bool? shoppingModeOverride;
  final VoidCallback? onUseDefaultExploreMode;
  final VoidCallback? onUseShoppingMode;
  final VoidCallback onGoHome;
  final VoidCallback onGoSaved;

  const ShoppingHelpPage({
    super.key,
    required this.items,
    required this.recentScans,
    this.consideredItems = const [],
    this.shoppingModeOverride,
    this.onUseDefaultExploreMode,
    this.onUseShoppingMode,
    required this.onGoHome,
    required this.onGoSaved,
  });

  @override
  State<ShoppingHelpPage> createState() => _ShoppingHelpPageState();
}

class _ShoppingHelpPageState extends State<ShoppingHelpPage> {
  final Set<String> _dismissedOfferIntentKeys = <String>{};
  int _editorialRefreshSeed = DateTime.now().microsecondsSinceEpoch;

  @override
  void didUpdateWidget(covariant ShoppingHelpPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldActive =
        oldWidget.items.isNotEmpty || oldWidget.recentScans.isNotEmpty;
    final nextActive = widget.items.isNotEmpty || widget.recentScans.isNotEmpty;
    if (oldActive != nextActive) {
      _dismissedOfferIntentKeys.clear();
    }
  }

  int get _totalPrice =>
      widget.items.fold(0, (sum, item) => sum + item.totalPrice);
  int get _totalCount =>
      widget.items.fold(0, (sum, item) => sum + item.quantity);
  bool get _hasActiveShoppingContext =>
      widget.items.isNotEmpty || widget.recentScans.isNotEmpty;
  bool get _showShoppingMode =>
      widget.shoppingModeOverride ?? _hasActiveShoppingContext;

  String _pageTitle() {
    if (_showShoppingMode) {
      return '지금 장보는중!';
    }
    return AppRuntimeCopy.text(['help', 'pageTitle'], '탐색');
  }

  String _pageSubtitle(AppLocationSnapshot? locationSnapshot) {
    if (!_showShoppingMode) {
      return AppRuntimeCopy.text(
        ['help', 'subtitle'],
        '다음 장보기에 도움을 드려요',
      );
    }

    final shoppingContextLabel = _shoppingContextLabel(locationSnapshot);
    if (shoppingContextLabel != null) {
      return shoppingContextLabel;
    }
    return '지금 위치와 담은 상품을 바탕으로 장보기 흐름을 맞춰드릴게요';
  }

  String? _shoppingContextLabel(AppLocationSnapshot? locationSnapshot) {
    final brand = CartTitleSuggester.inferMartBrand(widget.items);
    final region = locationSnapshot?.customerFacingRegionLabel?.trim();

    if (brand != null && region != null && region.isNotEmpty) {
      return '$brand · $region 근처 장보기로 추정돼요';
    }
    if (brand != null) {
      return '$brand 장보기로 추정돼요';
    }
    if (region != null && region.isNotEmpty) {
      return '$region 근처 장보기로 추정돼요';
    }
    return null;
  }

  Widget _modeToggleIconButton({
    required bool shoppingMode,
    required VoidCallback? onPressed,
  }) {
    if (onPressed == null) {
      return const SizedBox(width: 32, height: 32);
    }

    final iconName = shoppingMode
        ? 'arrow.uturn.backward.circle'
        : 'sparkle.magnifyingglass';
    final foregroundColor = shoppingMode
        ? CartlyColors.onBrandPrimary
        : CartlyColors.textSecondary;
    final backgroundColor = shoppingMode
        ? Colors.white.withValues(alpha: 0.14)
        : CartlyColors.surface2;

    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: CartlySymbolIcon.sf(
          iconName,
          size: 18,
          color: foregroundColor,
        ),
      ),
    );
  }

  int _configInt(Map<String, dynamic> config, String key, int fallback) {
    final value = config[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  String _providerLabelFromUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    final host = Uri.tryParse(trimmed)?.host.toLowerCase() ?? '';
    if (host.isEmpty) return '추천';
    if (host.contains('coupang') || host.contains('coupa.ng')) return '쿠팡';
    if (host.contains('11st')) return '11번가';
    if (host.contains('naver')) return '네이버';
    if (host.contains('gmarket')) return 'G마켓';
    if (host.contains('auction')) return '옥션';
    if (host.contains('ssg')) return 'SSG';
    if (host.contains('kurly')) return '컬리';
    if (host.contains('lotteon')) return '롯데온';
    if (host.contains('emart')) return '이마트';
    final segments = host.split('.');
    final label = segments.length >= 2 ? segments[segments.length - 2] : host;
    return label.length <= 4
        ? label.toUpperCase()
        : '${label[0].toUpperCase()}${label.substring(1)}';
  }

  bool _configBool(Map<String, dynamic> config, String key, bool fallback) {
    final value = config[key];
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }

  String _configText(Map<String, dynamic> config, String key, String fallback) {
    final value = config[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  int _stateRuleInt(
    Map<String, dynamic> config,
    String state,
    String key,
    int fallback,
  ) {
    final stateRules = config['stateRules'];
    if (stateRules is Map) {
      final rawStateRules = stateRules[state];
      if (rawStateRules is Map) {
        final value = rawStateRules[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        final parsed = int.tryParse('$value');
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return _configInt(config, key, fallback);
  }

  bool _statePromoPolicyBool(
    Map<String, dynamic> config,
    String state,
    String key,
    bool fallback,
  ) {
    final policies = config['statePromoPolicies'];
    if (policies is Map) {
      final rawStatePolicies = policies[state];
      if (rawStatePolicies is Map) {
        final value = rawStatePolicies[key];
        if (value is bool) return value;
        if (value is String) {
          final normalized = value.trim().toLowerCase();
          if (normalized == 'true' ||
              normalized == '1' ||
              normalized == 'yes') {
            return true;
          }
          if (normalized == 'false' ||
              normalized == '0' ||
              normalized == 'no') {
            return false;
          }
        }
      }
    }
    return fallback;
  }

  int _statePromoPolicyInt(
    Map<String, dynamic> config,
    String state,
    String key,
    int fallback,
  ) {
    final policies = config['statePromoPolicies'];
    if (policies is Map) {
      final rawStatePolicies = policies[state];
      if (rawStatePolicies is Map) {
        final value = rawStatePolicies[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        final parsed = int.tryParse('$value');
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return fallback;
  }

  List<ExploreStorePromo> _applyPromoPolicy(
    List<ExploreStorePromo> promos,
    Map<String, dynamic> config,
    String state,
  ) {
    final allowSponsored = _statePromoPolicyBool(
      config,
      state,
      'allowSponsoredPromos',
      true,
    );
    final organicFirst = _statePromoPolicyBool(
      config,
      state,
      'organicFirst',
      true,
    );
    final policyMaxSponsored = _statePromoPolicyInt(
      config,
      state,
      'maxSponsoredPromos',
      1,
    );

    final sorted = [...promos]
      ..sort((a, b) {
        if (organicFirst && a.isSponsored != b.isSponsored) {
          return a.isSponsored ? 1 : -1;
        }
        if (!organicFirst && a.isSponsored != b.isSponsored) {
          return a.isSponsored ? -1 : 1;
        }
        return a.priority.compareTo(b.priority);
      });

    var sponsoredCount = 0;
    return sorted
        .where((promo) {
          if (!promo.isSponsored) return true;
          if (!allowSponsored) return false;
          if (sponsoredCount >= policyMaxSponsored) return false;
          sponsoredCount += 1;
          return true;
        })
        .toList(growable: false);
  }

  List<ExploreStorePromo> _buildStoreContextPromos(
    Map<String, dynamic> config,
    String state,
  ) {
    final promos = (config['storeContextPromos'] as List?)
        ?.whereType<Map>()
        .map(
          (item) => ExploreStorePromo.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);

    if (promos == null || promos.isEmpty) {
      return const [];
    }

    return _applyPromoPolicy(promos, config, state);
  }

  Set<String> _enabledSections(Map<String, dynamic> config) {
    final raw = (config['enabledSections'] as String?) ?? '';
    final parts = raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet();
    if (parts.isEmpty) {
      return const {
        'heroSummary',
        'revisitItems',
        'repeatCandidates',
        'editorialPicks',
        'offerSlots',
        'savedContext',
        'storeContextPromo',
      };
    }
    return parts;
  }

  String _normalizeExploreState(String? value) {
    switch (value?.trim()) {
      case 'active':
      case _exploreStateActiveShopping:
        return _exploreStateActiveShopping;
      case _exploreStatePostSave:
        return _exploreStatePostSave;
      case 'idle':
      case _exploreStateIdlePlanning:
        return _exploreStateIdlePlanning;
      case 'store':
      case _exploreStateStoreContext:
        return _exploreStateStoreContext;
      default:
        return 'auto';
    }
  }

  bool _isLikelyPostSave(SavedCart? latest) {
    if (latest == null) return false;
    return DateTime.now().difference(latest.createdAt).inHours <= 18;
  }

  String _resolveExploreState(Map<String, dynamic> config, SavedCart? latest) {
    final previewState = _normalizeExploreState(
      config['__previewState'] as String?,
    );
    if (previewState != 'auto') {
      return previewState;
    }

    final forcedState = _normalizeExploreState(config['stateMode'] as String?);
    if (forcedState != 'auto') {
      return forcedState;
    }

    if (_showShoppingMode) {
      return _exploreStateActiveShopping;
    }
    if (_isLikelyPostSave(latest)) {
      return _exploreStatePostSave;
    }
    return _exploreStateIdlePlanning;
  }

  String _stateOrderKey(String state) {
    switch (state) {
      case _exploreStatePostSave:
        return 'postSaveSectionOrder';
      case _exploreStateStoreContext:
        return 'storeContextSectionOrder';
      case _exploreStateIdlePlanning:
        return 'idlePlanningSectionOrder';
      case _exploreStateActiveShopping:
      default:
        return 'activeShoppingSectionOrder';
    }
  }

  List<String> _dynamicSectionOrder(
    Map<String, dynamic> config, {
    required bool hasOfferSlots,
    required bool hasEditorialPicks,
    required bool hasStoreContextPromos,
    required String state,
  }) {
    final enabled = _enabledSections(config);
    final fallback = switch (state) {
      _exploreStatePostSave => const [
        'savedContext',
        'offerSlots',
        'repeatCandidates',
        'editorialPicks',
      ],
      _exploreStateStoreContext => const [
        'storeContextPromo',
        'offerSlots',
        'savedContext',
        'editorialPicks',
        'repeatCandidates',
      ],
      _exploreStateIdlePlanning => const [
        'savedContext',
        'repeatCandidates',
        'editorialPicks',
        'offerSlots',
      ],
      _ => const ['heroSummary', 'offerSlots', 'revisitItems'],
    };

    final configured = (config[_stateOrderKey(state)] as String? ?? '')
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    final ordered = <String>[];

    void addSection(String sectionId) {
      if (!enabled.contains(sectionId) || ordered.contains(sectionId)) {
        return;
      }
      if (sectionId == 'decisionInbox') {
        return;
      }
      if (sectionId == 'offerSlots' && !hasOfferSlots) {
        return;
      }
      if (sectionId == 'editorialPicks' && !hasEditorialPicks) {
        return;
      }
      if (sectionId == 'storeContextPromo' && !hasStoreContextPromos) {
        return;
      }
      ordered.add(sectionId);
    }

    for (final sectionId in configured) {
      addSection(sectionId);
    }
    for (final sectionId in fallback) {
      addSection(sectionId);
    }

    return ordered;
  }

  bool _isEditorialOfferActive(ExploreAlternativeOffer offer) {
    DateTime? parseSchedule(String? value) {
      final text = value?.trim();
      if (text == null || text.isEmpty) {
        return null;
      }
      return DateTime.tryParse(text.replaceFirst(' ', 'T'));
    }

    final now = DateTime.now();
    final startsAt = parseSchedule(offer.startsAt);
    final endsAt = parseSchedule(offer.endsAt);
    if (startsAt != null && now.isBefore(startsAt)) {
      return false;
    }
    if (endsAt != null && now.isAfter(endsAt)) {
      return false;
    }
    return true;
  }

  List<ExploreAlternativeOffer> _editorialPoolFromConfig(
    Map<String, dynamic> config,
  ) {
    int? parsePrice(String value) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) {
        return null;
      }
      return int.tryParse(digits);
    }

    final itemPool = (config['editorialRecommendationsItems'] as List?)
        ?.whereType<Map>()
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          final url =
              (data['deeplinkUrl'] as String?)?.trim() ??
              (data['url'] as String?)?.trim() ??
              '';
          final title = (data['title'] as String?)?.trim();
          final subtitle = (data['subtitle'] as String?)?.trim();
          final provider = (data['provider'] as String?)?.trim();
          final thumbnailUrl = (data['thumbnailUrl'] as String?)?.trim();
          final rawPrice = data['price'];
          final price = rawPrice is int
              ? rawPrice
              : rawPrice is num
              ? rawPrice.toInt()
              : int.tryParse('${data['price'] ?? ''}');
          if ((title == null || title.isEmpty) &&
              url.isEmpty &&
              (thumbnailUrl == null || thumbnailUrl.isEmpty)) {
            return null;
          }
          final providerUrl = url.isNotEmpty ? url : thumbnailUrl;
          return ExploreAlternativeOffer(
            provider: provider == null || provider.isEmpty
                ? _providerLabelFromUrl(providerUrl)
                : provider,
            title: title == null || title.isEmpty ? '추천 상품' : title,
            subtitle: subtitle == null || subtitle.isEmpty ? null : subtitle,
            price: price,
            thumbnailUrl: thumbnailUrl == null || thumbnailUrl.isEmpty
                ? null
                : thumbnailUrl,
            deeplinkUrl: url.isEmpty ? null : url,
            displaySlot: data['displaySlot'] is int
                ? data['displaySlot'] as int
                : int.tryParse('${data['displaySlot'] ?? ''}') ?? 999,
            startsAt: (data['startsAt'] as String?)?.trim(),
            endsAt: (data['endsAt'] as String?)?.trim(),
          );
        })
        .whereType<ExploreAlternativeOffer>()
        .where(_isEditorialOfferActive)
        .toList(growable: false);
    if (itemPool != null && itemPool.isNotEmpty) {
      return itemPool;
    }

    final raw = config['editorialRecommendationsPoolRaw'];
    if (raw is String && raw.trim().isNotEmpty) {
      final seen = <String>{};
      final parsed = <ExploreAlternativeOffer>[];
      for (final line in raw.split(RegExp(r'\r?\n'))) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }
        final iframeMatch = RegExp(
          r'''<iframe[^>]+src=["']([^"']+)["']''',
          caseSensitive: false,
        ).firstMatch(trimmed);
        final anchorHrefMatch = RegExp(
          r'''<a[^>]+href=["']([^"']+)["']''',
          caseSensitive: false,
        ).firstMatch(trimmed);
        final imageSrcMatch = RegExp(
          r'''<img[^>]+src=["']([^"']+)["']''',
          caseSensitive: false,
        ).firstMatch(trimmed);
        final imageAltMatch = RegExp(
          r'''<img[^>]+alt=["']([^"']+)["']''',
          caseSensitive: false,
        ).firstMatch(trimmed);
        final normalizedLine = iframeMatch?.group(1)?.trim() ?? trimmed;
        final parts = normalizedLine
            .split('|')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList(growable: false);

        var title = imageAltMatch?.group(1)?.trim() ?? '';
        var deeplinkUrl = anchorHrefMatch?.group(1)?.trim() ?? '';
        var thumbnailUrl = imageSrcMatch?.group(1)?.trim() ?? '';
        int? price;

        if (deeplinkUrl.isNotEmpty) {
          // keep parsed html values
        } else if (parts.length == 1 &&
            Uri.tryParse(normalizedLine)?.hasScheme == true) {
          deeplinkUrl = normalizedLine;
        } else {
          title = title.isEmpty && parts.isNotEmpty ? parts.first : title;
          final urlParts = parts
              .skip(1)
              .where((part) => Uri.tryParse(part)?.hasScheme == true)
              .toList(growable: false);
          final nonUrlParts = parts
              .skip(1)
              .where((part) => Uri.tryParse(part)?.hasScheme != true)
              .toList(growable: false);

          for (final part in nonUrlParts) {
            price ??= parsePrice(part);
          }

          if (urlParts.length >= 2) {
            thumbnailUrl = urlParts.first;
            deeplinkUrl = urlParts.last;
          } else if (urlParts.length == 1) {
            final candidateUrl = urlParts.first;
            final looksLikeImage =
                RegExp(
                  r'\.(jpg|jpeg|png|webp|gif)(\?|$)',
                  caseSensitive: false,
                ).hasMatch(candidateUrl) ||
                candidateUrl.toLowerCase().contains('image') ||
                candidateUrl.toLowerCase().contains('thumb');
            if (price != null && looksLikeImage) {
              thumbnailUrl = candidateUrl;
            } else {
              deeplinkUrl = candidateUrl;
            }
          }
        }

        final dedupeKey = deeplinkUrl.isNotEmpty
            ? deeplinkUrl
            : thumbnailUrl.isNotEmpty
            ? thumbnailUrl
            : title;
        if (dedupeKey.isEmpty || !seen.add(dedupeKey)) {
          continue;
        }
        final itemIndex = parsed.length + 1;
        final providerUrl = deeplinkUrl.isNotEmpty ? deeplinkUrl : thumbnailUrl;
        parsed.add(
          ExploreAlternativeOffer(
            provider: _providerLabelFromUrl(providerUrl),
            title: title.isEmpty ? '추천 상품 $itemIndex' : title,
            price: price,
            thumbnailUrl: thumbnailUrl.isEmpty ? null : thumbnailUrl,
            deeplinkUrl: deeplinkUrl.isEmpty ? null : deeplinkUrl,
            displaySlot: 999,
          ),
        );
      }
      if (parsed.isNotEmpty) {
        return parsed.where(_isEditorialOfferActive).toList(growable: false);
      }
    }

    return const [];
  }

  List<ExploreAlternativeOffer> _buildEditorialOffers(
    Map<String, dynamic> config, {
    required String state,
    required List<ExploreAlternativeOffer> pool,
  }) {
    if (state == _exploreStateActiveShopping) {
      return const [];
    }
    if (!_configBool(config, 'editorialRecommendationsEnabled', true)) {
      return const [];
    }
    if (pool.isEmpty) {
      return const [];
    }

    final visibleCount = _configInt(
      config,
      'editorialRecommendationsCount',
      5,
    ).clamp(1, 50);
    final fixedBySlot = <int, ExploreAlternativeOffer>{};
    final randomPool = <ExploreAlternativeOffer>[];

    for (final offer in pool) {
      final slot = offer.displaySlot;
      if (slot >= 1 && slot <= 10 && !fixedBySlot.containsKey(slot)) {
        fixedBySlot[slot] = offer;
      } else {
        randomPool.add(offer);
      }
    }

    final shuffled = [...randomPool]..shuffle(Random(_editorialRefreshSeed));
    final arranged = List<ExploreAlternativeOffer?>.filled(visibleCount, null);

    for (final entry in fixedBySlot.entries) {
      final index = entry.key - 1;
      if (index >= 0 && index < visibleCount) {
        arranged[index] = entry.value;
      }
    }

    var randomIndex = 0;
    for (var index = 0; index < arranged.length; index += 1) {
      if (arranged[index] != null) continue;
      if (randomIndex >= shuffled.length) break;
      arranged[index] = shuffled[randomIndex];
      randomIndex += 1;
    }

    return arranged.whereType<ExploreAlternativeOffer>().toList(
      growable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: AppConfigStore.instance.explore,
      builder: (context, exploreConfig, _) {
        return ValueListenableBuilder<List<SavedCart>>(
          valueListenable: CartStore.instance.carts,
          builder: (context, carts, _) {
            final latest = carts.isEmpty ? null : carts.first;
            final currentState = _resolveExploreState(exploreConfig, latest);
            final revisitItems = _buildRevisitItems(
              exploreConfig,
              currentState,
            );
            final repeatCandidates = _buildRepeatCandidates(
              carts,
              exploreConfig,
              currentState,
            );
            final editorialPool = _editorialPoolFromConfig(exploreConfig);
            final editorialOffers = _buildEditorialOffers(
              exploreConfig,
              state: currentState,
              pool: editorialPool,
            );
            final baseOfferSlots = _buildOfferSlots(
              revisitItems: revisitItems,
              repeatCandidates: repeatCandidates,
              exploreConfig: exploreConfig,
              repeatOnly: currentState != _exploreStateActiveShopping,
              state: currentState,
            );
            final offerSlots = baseOfferSlots
                .where(
                  (slot) => !_dismissedOfferIntentKeys.contains(slot.intentKey),
                )
                .toList(growable: false);
            final hiddenOfferCount = baseOfferSlots.length - offerSlots.length;
            final visibleOfferIntentKeys = offerSlots
                .map((slot) => slot.intentKey)
                .toSet();
            final visibleRevisitItems = revisitItems
                .where(
                  (item) => !visibleOfferIntentKeys.contains(_normalize(item.name)),
                )
                .toList(growable: false);
            final visibleRepeatCandidates = repeatCandidates
                .where(
                  (candidate) =>
                      !visibleOfferIntentKeys.contains(_normalize(candidate.name)),
                )
                .toList(growable: false);
            final storeContextPromos = _buildStoreContextPromos(
              exploreConfig,
              currentState,
            );
            final orderedSections = _dynamicSectionOrder(
              exploreConfig,
              hasOfferSlots: offerSlots.isNotEmpty || hiddenOfferCount > 0,
              hasEditorialPicks: editorialOffers.isNotEmpty,
              hasStoreContextPromos: storeContextPromos.isNotEmpty,
              state: currentState,
            );
            final sectionWidgets = <Widget>[];

            for (final sectionId in orderedSections) {
              switch (sectionId) {
                case 'heroSummary':
                  sectionWidgets.add(
                    _ExploreHeroCard(
                      itemCount: _totalCount,
                      totalPrice: _totalPrice,
                      recentScanCount: widget.recentScans.length,
                      compareCandidateCount: offerSlots.length,
                      onGoHome: widget.onGoHome,
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 20));
                  break;
                case 'revisitItems':
                  sectionWidgets.add(
                    SectionHeader(
                      title: '다시 볼 상품',
                      subtitle: '비교 후보로 올리지 않은 최근 스캔과 현재 카트만 골라 보여드려요',
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 10));
                  if (visibleRevisitItems.isEmpty) {
                    sectionWidgets.add(
                      const _EmptyInfoCard(
                        title: '다시 볼 상품이 아직 없어요',
                        body: '지금 다시 볼 상품은 비교 후보에 먼저 반영됐거나, 아직 후보가 충분하지 않아요.',
                      ),
                    );
                  } else {
                    sectionWidgets.addAll(
                      visibleRevisitItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DecisionItemCard(
                            item: item,
                            onTap: () => _showIntentDetailSheet(
                              context,
                              _IntentDetail.fromRevisitItem(item),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  sectionWidgets.add(const SizedBox(height: 8));
                  break;
                case 'repeatCandidates':
                  sectionWidgets.add(
                    SectionHeader(
                      title: '반복 구매',
                      subtitle: '비교 후보로 아직 올리지 않은 반복 구매 상품만 따로 보여드려요',
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 10));
                  if (visibleRepeatCandidates.isEmpty) {
                    sectionWidgets.add(
                      const _EmptyInfoCard(
                        title: '아직 반복 패턴이 부족해요',
                        body: '반복 구매 후보는 이미 비교 후보에 반영됐거나, 아직 반복 패턴이 더 필요해요.',
                      ),
                    );
                  } else {
                    sectionWidgets.addAll(
                      visibleRepeatCandidates.map(
                        (candidate) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RepeatCandidateCard(
                            candidate: candidate,
                            onTap: () => _showIntentDetailSheet(
                              context,
                              _IntentDetail.fromRepeatCandidate(candidate),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  sectionWidgets.add(const SizedBox(height: 20));
                  break;
                case 'editorialPicks':
                  sectionWidgets.add(
                    SectionHeader(
                      title: _configText(
                        exploreConfig,
                        'editorialRecommendationsTitle',
                        '추천 제품',
                      ),
                      subtitle: _configText(
                        exploreConfig,
                        'editorialRecommendationsSubtitle',
                        '지금 카트에 많이 담는 TOP5',
                      ),
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 10));
                  if (editorialPool.length > editorialOffers.length) {
                    sectionWidgets.add(
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style:
                              CartlyButtonStyles.quiet(
                                foregroundColor: const Color(0xFF6B2B35),
                              ).copyWith(
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 0,
                                  ),
                                ),
                                textStyle: const WidgetStatePropertyAll(
                                  TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          onPressed: () {
                            setState(() {
                              _editorialRefreshSeed =
                                  DateTime.now().microsecondsSinceEpoch;
                            });
                          },
                          icon: const CartlySymbolIcon.sf(
                            'arrow.clockwise',
                            size: 18,
                          ),
                          label: const Text('다른 추천 보기'),
                        ),
                      ),
                    );
                    sectionWidgets.add(const SizedBox(height: 6));
                  }
                  sectionWidgets.addAll(
                    editorialOffers.map(
                      (offer) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AlternativeOfferPreviewCard(offer: offer),
                      ),
                    ),
                  );
                  final disclaimer =
                      (exploreConfig['editorialRecommendationsDisclaimer']
                              as String?)
                          ?.trim() ??
                      '';
                  if (disclaimer.isNotEmpty) {
                    sectionWidgets.add(
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          disclaimer,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: CartlyColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    );
                  }
                  sectionWidgets.add(const SizedBox(height: 20));
                  break;
                case 'offerSlots':
                  sectionWidgets.add(
                    const SectionHeader(
                      title: '비교 후보',
                      subtitle: '비슷한 대안을 함께 확인해보세요',
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 10));
                  if (hiddenOfferCount > 0) {
                    sectionWidgets.add(
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style:
                              CartlyButtonStyles.quiet(
                                foregroundColor: const Color(0xFF6B2B35),
                              ).copyWith(
                                padding: const WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 0,
                                  ),
                                ),
                                textStyle: const WidgetStatePropertyAll(
                                  TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          onPressed: () {
                            setState(() {
                              _dismissedOfferIntentKeys.clear();
                            });
                          },
                          icon: const CartlySymbolIcon.sf(
                            'eyeglasses',
                            size: 18,
                          ),
                          label: const Text('가린 대안 다시 보기'),
                        ),
                      ),
                    );
                    sectionWidgets.add(const SizedBox(height: 6));
                  }
                  sectionWidgets.addAll(
                    offerSlots.map(
                      (slot) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OfferSlotCard(
                          slot: slot,
                          onTap: () => _showIntentDetailSheet(
                            context,
                            _IntentDetail.fromOfferSlot(slot),
                          ),
                          onDismiss: () {
                            setState(() {
                              _dismissedOfferIntentKeys.add(slot.intentKey);
                            });
                          },
                        ),
                      ),
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 20));
                  break;
                case 'storeContextPromo':
                  sectionWidgets.add(
                    SectionHeader(
                      title: '지금 이 마트 세일',
                      subtitle: '매장 정보가 있으면 지금 볼 만한 할인과 대안을 먼저 보여드려요',
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 10));
                  sectionWidgets.add(
                    _StoreContextPromoCard(
                      title: _configText(
                        exploreConfig,
                        'storeContextPromoTitle',
                        '지금 이 마트 세일',
                      ),
                      body: _configText(
                        exploreConfig,
                        'storeContextPromoBody',
                        '자주 사는 상품군과 겹치는 할인 행사부터 먼저 보여줘요.',
                      ),
                      enabled: _configBool(
                        exploreConfig,
                        'storeContextEnabled',
                        false,
                      ),
                      promos: storeContextPromos,
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 20));
                  break;
                case 'savedContext':
                  final openLatestCart = latest == null
                      ? widget.onGoHome
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CartDetailPage(cart: latest),
                            ),
                          );
                        };
                  sectionWidgets.add(
                    SectionHeader(
                      title: '지난 장보기 맥락',
                      subtitle: '최근 저장한 카트를 바로 열거나 전체 기록을 이어서 보실 수 있어요',
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 10));
                  sectionWidgets.add(
                    _SavedContextHeroCard(
                      cart: latest,
                      onOpenLatest: openLatestCart,
                      onOpenAll: widget.onGoSaved,
                      onStartShopping: widget.onGoHome,
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 20));
                  break;
              }
            }

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                ValueListenableBuilder<AppLocationSnapshot?>(
                  valueListenable: AppLocationService.instance.snapshot,
                  builder: (context, locationSnapshot, _) {
                    final shoppingMode = _showShoppingMode;
                    final subtitle = _pageSubtitle(locationSnapshot);
                    final quietAction = shoppingMode
                        ? widget.onUseDefaultExploreMode
                        : widget.onUseShoppingMode;
                    final topInset = MediaQuery.paddingOf(context).top;

                    return Container(
                      width: double.infinity,
                      color: shoppingMode
                          ? CartlyColors.brand
                          : Colors.transparent,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        shoppingMode ? topInset + 12 : 12,
                        16,
                        0,
                      ),
                      child: SizedBox(
                        height: 84,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 40,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _pageTitle(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: shoppingMode
                                            ? CartlyText.pageHeroCompact.copyWith(
                                                color: CartlyColors.onBrandPrimary,
                                              )
                                            : CartlyText.pageHero.copyWith(
                                                color: CartlyColors.subBrand,
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: _modeToggleIconButton(
                                      shoppingMode: shoppingMode,
                                      onPressed: quietAction,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 24,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CartlyText.pageSubtitle.copyWith(
                                    color: shoppingMode
                                        ? Colors.white.withValues(alpha: 0.92)
                                        : CartlyColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    CartlySpacing.sectionLoose,
                    16,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sectionWidgets,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _decisionCopyText(
    Map<String, dynamic> config,
    String key,
    String fallback,
  ) {
    final copy = config['decisionCopy'];
    if (copy is Map) {
      final value = copy[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  List<_RevisitItem> _buildRevisitItems(
    Map<String, dynamic> exploreConfig,
    String state,
  ) {
    final currentNames = widget.items
        .map((item) => _normalize(item.name))
        .toSet();
    final results = <_RevisitItem>[];
    final recentScanLimit = _stateRuleInt(
      exploreConfig,
      state,
      'revisitRecentScanLimit',
      3,
    );
    final consideredItemLimit = _stateRuleInt(
      exploreConfig,
      state,
      'revisitConsideredItemLimit',
      3,
    );
    final cartItemLimit = _stateRuleInt(
      exploreConfig,
      state,
      'revisitCartItemLimit',
      3,
    );
    final maxItems = _stateRuleInt(exploreConfig, state, 'revisitMaxItems', 4);

    for (final entry in widget.recentScans.take(recentScanLimit)) {
      final normalizedName = _normalize(entry.item.name);
      final inCart = currentNames.contains(normalizedName);
      results.add(
        _RevisitItem(
          decisionKey: inCart ? 'recentScanInCart' : 'recentScanPending',
          name: entry.item.name,
          price: entry.item.price,
          reason: inCart
              ? _decisionCopyText(
                  exploreConfig,
                  'recentScanInCartBody',
                  '이미 카트에 담았어요. 결제 전에 다른 선택지가 있는지만 가볍게 확인해보세요.',
                )
              : _decisionCopyText(
                  exploreConfig,
                  'recentScanPendingBody',
                  '스캔은 끝났지만 아직 카트에 담지 않았어요. 고민 중인 상품이라면 대체안도 같이 확인해보세요.',
                ),
          badge: inCart ? '재확인' : '미결정',
          reasonLabel: inCart
              ? _decisionCopyText(
                  exploreConfig,
                  'recentScanInCartReasonLabel',
                  '담은 뒤 한 번 더 보기',
                )
              : _decisionCopyText(
                  exploreConfig,
                  'recentScanPendingReasonLabel',
                  '스캔만 해둔 상품이에요',
                ),
        ),
      );
    }

    for (final entry in widget.consideredItems.take(consideredItemLimit)) {
      final normalizedName = _normalize(entry.name);
      if (currentNames.contains(normalizedName)) {
        continue;
      }
      final isRemovedFromCart = entry.source == 'removedFromCart';
      results.add(
        _RevisitItem(
          decisionKey: isRemovedFromCart
              ? 'removedCartCandidate'
              : 'scanNotAddedCandidate',
          name: entry.name,
          price: entry.price,
          reason: isRemovedFromCart
              ? _decisionCopyText(
                  exploreConfig,
                  'removedCartCandidateBody',
                  '한번 담았다가 다시 뺀 상품이에요. 아직 고민 중이라면 비슷한 대체안도 같이 볼 수 있어요.',
                )
              : _decisionCopyText(
                  exploreConfig,
                  'scanNotAddedCandidateBody',
                  '스캔까지는 했지만 담지 않은 상품이에요. 망설였던 후보라면 대체안 비교가 도움이 될 수 있어요.',
                ),
          badge: isRemovedFromCart ? '보류' : '미결정',
          reasonLabel: isRemovedFromCart
              ? _decisionCopyText(
                  exploreConfig,
                  'removedCartCandidateReasonLabel',
                  '담았다가 다시 뺐어요',
                )
              : _decisionCopyText(
                  exploreConfig,
                  'scanNotAddedCandidateReasonLabel',
                  '스캔만 하고 넘겼어요',
                ),
        ),
      );
    }

    for (final item in widget.items.take(cartItemLimit)) {
      results.add(
        _RevisitItem(
          decisionKey: item.quantity > 1
              ? 'currentCartHighImpact'
              : 'currentCartDefault',
          name: item.name,
          price: item.price,
          reason: item.quantity > 1
              ? _decisionCopyText(
                  exploreConfig,
                  'currentCartHighImpactBody',
                  '수량이나 가격 영향이 큰 상품이에요. 비슷한 대안과 비교하면 체감 차이가 날 수 있어요.',
                )
              : _decisionCopyText(
                  exploreConfig,
                  'currentCartDefaultBody',
                  '지금 카트에 담아둔 상품이에요. 결제 전에 한 번만 더 비교해보세요.',
                ),
          badge: '현재 카트',
          reasonLabel: item.quantity > 1
              ? _decisionCopyText(
                  exploreConfig,
                  'currentCartHighImpactReasonLabel',
                  '합계 영향이 커요',
                )
              : _decisionCopyText(
                  exploreConfig,
                  'currentCartDefaultReasonLabel',
                  '결제 전에 확인해보세요',
                ),
        ),
      );
    }

    final deduped = <String>{};
    return results
        .where((item) => deduped.add(_normalize(item.name)))
        .take(maxItems)
        .toList();
  }

  List<_RepeatCandidate> _buildRepeatCandidates(
    List<SavedCart> carts,
    Map<String, dynamic> exploreConfig,
    String state,
  ) {
    final currentNames = widget.items
        .map((item) => _normalize(item.name))
        .toSet();
    final Map<String, _RepeatAccumulator> map = {};

    final repeatSourceCarts = carts
        .where((cart) => cart.isPurchaseCompleted())
        .toList(growable: false);

    for (final cart in repeatSourceCarts) {
      final seenInCart = <String>{};
      for (final item in cart.items) {
        final key = _normalize(item.name);
        if (key.isEmpty || !seenInCart.add(key)) continue;
        final entry = map.putIfAbsent(
          key,
          () => _RepeatAccumulator(name: item.name, lastPrice: item.price),
        );
        entry.count += 1;
        entry.lastPrice = item.price;
      }
    }

    final repeatMinCount = _stateRuleInt(
      exploreConfig,
      state,
      'repeatMinCount',
      2,
    );
    final repeatMaxItems = _stateRuleInt(
      exploreConfig,
      state,
      'repeatMaxItems',
      4,
    );

    final candidates =
        map.entries
            .where(
              (entry) =>
                  entry.value.count >= repeatMinCount &&
                  !currentNames.contains(entry.key),
            )
            .map(
              (entry) => _RepeatCandidate(
                name: entry.value.name,
                price: entry.value.lastPrice,
                repeatCount: entry.value.count,
              ),
            )
            .toList()
          ..sort((a, b) => b.repeatCount.compareTo(a.repeatCount));

    return candidates.take(repeatMaxItems).toList();
  }

  List<ExploreOfferSlot> _buildOfferSlots({
    required List<_RevisitItem> revisitItems,
    required List<_RepeatCandidate> repeatCandidates,
    required Map<String, dynamic> exploreConfig,
    required bool repeatOnly,
    required String state,
  }) {
    final signals = <ExploreOfferSignal>[
      if (!repeatOnly)
        ...revisitItems
            .take(2)
            .map(
              (item) => ExploreOfferSignal(
                intentKey: _normalize(item.name),
                anchorName: item.name,
                anchorPrice: item.price,
                sourceType: item.badge == '현재 카트'
                    ? ExploreOfferSourceType.currentCart
                    : ExploreOfferSourceType.pendingReview,
                sourceLabel: item.badge,
                context: item.badge == '현재 카트' ? '현재 담은 상품 기준' : '검토 중인 상품 기준',
                ctaLabel: '비슷한 상품 보기',
                comparePoints: const ['가격', '용량', '묶음 구성'],
              ),
            ),
      ...repeatCandidates
          .take(
            repeatOnly
                ? _stateRuleInt(exploreConfig, state, 'offerMaxSlots', 3)
                : 1,
          )
          .map(
            (candidate) => ExploreOfferSignal(
              intentKey: _normalize(candidate.name),
              anchorName: candidate.name,
              anchorPrice: candidate.price,
              sourceType: ExploreOfferSourceType.repeatPurchase,
              sourceLabel: '반복 구매',
              context: '반복 구매 후보 기준',
              ctaLabel: '비슷한 상품 보기',
              comparePoints: const ['재구매 가격', '단가', '후기 품질'],
            ),
          ),
    ];

    final offerMaxSlots = _stateRuleInt(
      exploreConfig,
      state,
      'offerMaxSlots',
      3,
    );
    return ExploreOfferSlotFactory.build(signals).take(offerMaxSlots).toList();
  }

  Future<void> _showIntentDetailSheet(
    BuildContext context,
    _IntentDetail detail,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: CartlyColors.surface0,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        detail.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                    ),
                    CartlyBadge(
                      label: detail.badge,
                      backgroundColor: CartlyColors.surfaceNeutral,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '₩${formatPrice(detail.price)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail.summary,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CartlyColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '앞으로 여기서 볼 것',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...detail.comparePoints.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: CartlySymbolIcon.sf(
                            'checkmark.circle',
                            size: 18,
                            color: CartlyColors.subBrand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: CartlyColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (detail.offerQuery == null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CartlyColors.surfaceNeutral,
                      borderRadius: BorderRadius.circular(CartlyRadii.control),
                    ),
                    child: Text(
                      detail.futureNote,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CartlyColors.subBrand,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                if (detail.offerQuery != null) ...[
                  const SizedBox(height: 18),
                  const Text(
                    '네이버쇼핑 결과',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<ExploreOfferResult>(
                    future: _offerProvider.fetchOffers(detail.offerQuery!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(minHeight: 3),
                        );
                      }

                      final result = snapshot.data ?? const ExploreOfferResult.none();
                      if (result.shouldShowGenericHint) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _EmptyInfoCard(
                            title: '대안이 있을 수 있어요',
                            body: result.genericMessage!,
                          ),
                        );
                      }

                      if (!result.hasVisibleOffers) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: _EmptyInfoCard(
                            title: '네이버쇼핑 결과를 아직 못 찾았어요',
                            body: '이 상품은 검색어를 더 다듬거나 묶음 구성을 다시 확인해봐야 해요.',
                          ),
                        );
                      }

                      final offers = result.offers;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '바로 비교할 수 있는 상품',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...offers.map(
                            (offer) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AlternativeOfferPreviewCard(offer: offer),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _normalize(String value) {
    return ExploreIntentNormalizer.normalize(value).intentKey;
  }
}

class _ExploreHeroCard extends StatelessWidget {
  final int itemCount;
  final int totalPrice;
  final int recentScanCount;
  final int compareCandidateCount;
  final VoidCallback onGoHome;

  const _ExploreHeroCard({
    required this.itemCount,
    required this.totalPrice,
    required this.recentScanCount,
    required this.compareCandidateCount,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return CartlySurfaceCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: CartlyColors.brand,
      radius: CartlyRadii.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '지금 확인할 것만 모아봤어요',
            style: TextStyle(
              color: CartlyColors.onBrandPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$itemCount개 상품 · ₩${formatPrice(totalPrice)}',
            style: const TextStyle(
              color: CartlyColors.onBrandPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroStat(label: '현재 카트', value: '$itemCount개'),
              _HeroStat(label: '최근 스캔', value: '$recentScanCount개'),
              _HeroStat(label: '비교 후보', value: '$compareCandidateCount개'),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onGoHome,
            style: CartlyButtonStyles.primary(
              backgroundColor: CartlyColors.surface1,
              foregroundColor: CartlyColors.brand,
            ),
            child: const Text('현재 카트 이어서 보기'),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CartlyColors.contrast,
        borderRadius: BorderRadius.circular(CartlyRadii.control),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: CartlyColors.onBrandPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DecisionItemCard extends StatelessWidget {
  final _RevisitItem item;
  final VoidCallback onTap;

  const _DecisionItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CartlyColors.surface1,
      borderRadius: BorderRadius.circular(CartlyRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CartlyRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CartlyBadge(label: item.badge),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₩${formatPrice(item.price)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.reason,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: CartlyColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '비교 준비 보기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CartlyColors.subBrand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RepeatCandidateCard extends StatelessWidget {
  final _RepeatCandidate candidate;
  final VoidCallback onTap;

  const _RepeatCandidateCard({required this.candidate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CartlyColors.surface1,
      borderRadius: BorderRadius.circular(CartlyRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CartlyRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CartlySymbolIcon.sf(
                'arrow.uturn.backward.circle',
                color: CartlyColors.subBrand,
                size: CartlyIconSizes.control,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '저장 카트 ${candidate.repeatCount}번 등장 · 최근 확인 가격 ₩${formatPrice(candidate.price)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: CartlyColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '비슷한 상품 보기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CartlyColors.subBrand,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferSlotCard extends StatelessWidget {
  final ExploreOfferSlot slot;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const _OfferSlotCard({
    required this.slot,
    required this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CartlyColors.contrast,
      borderRadius: BorderRadius.circular(CartlyRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CartlyRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CartlyBadge(label: '비슷한 상품', dark: true),
                  const SizedBox(width: 8),
                  CartlyBadge(label: slot.sourceLabel, dark: true),
                  const Spacer(),
                  if (onDismiss != null)
                    Tooltip(
                      message: '이번 화면에서만 가리기',
                      child: InkWell(
                        onTap: onDismiss,
                        borderRadius: BorderRadius.circular(CartlyRadii.pill),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF232323),
                            shape: BoxShape.circle,
                          ),
                          child: const CartlySymbolIcon.sf(
                            'eyeglasses.slash',
                            size: 16,
                            color: CartlyColors.onBrandPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${slot.anchorName} 대체안',
                style: const TextStyle(
                  color: CartlyColors.onBrandPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${slot.context} 함께 살펴볼 만한 비슷한 상품이에요. 가격이나 구성 차이를 가볍게 비교해보세요.',
                style: const TextStyle(
                  color: CartlyColors.onBrandMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF232323),
                  borderRadius: BorderRadius.circular(CartlyRadii.control),
                  border: Border.all(color: const Color(0xFF363636)),
                ),
                child: Text(
                  slot.ctaLabel,
                  style: const TextStyle(
                    color: CartlyColors.onBrandPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreContextPromoCard extends StatelessWidget {
  final String title;
  final String body;
  final bool enabled;
  final List<ExploreStorePromo> promos;

  const _StoreContextPromoCard({
    required this.title,
    required this.body,
    required this.enabled,
    required this.promos,
  });

  @override
  Widget build(BuildContext context) {
    final storeName = promos.isEmpty ? '이마트 양재점' : promos.first.storeName;

    return CartlySurfaceCard(
      radius: CartlyRadii.hero,
      gradient: const LinearGradient(
        colors: [
          CartlyColors.softWarmSurface,
          CartlyColors.surface1,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: CartlyColors.lineWarm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const CartlyBadge(label: 'store context'),
              CartlyBadge(label: enabled ? 'lane on' : 'lane off'),
              CartlyBadge(label: storeName),
              CartlyBadge(label: 'promo ${promos.length}개'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CartlyColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ...promos.map(
            (promo) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CartlyColors.surface1,
                  borderRadius: BorderRadius.circular(CartlyRadii.control),
                  border: Border.all(color: CartlyColors.lineWarm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CartlyBadge(label: promo.badgeLabel),
                        CartlyBadge(label: promo.placementLabel),
                        CartlyBadge(label: promo.intentHint),
                        CartlyBadge(label: promo.sourceType),
                        CartlyBadge(label: 'priority ${promo.priority}'),
                        CartlyBadge(
                          label: promo.isSponsored ? 'sponsored' : 'organic',
                        ),
                        if (promo.sponsorLabel != null)
                          CartlyBadge(label: promo.sponsorLabel!),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      promo.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      promo.body,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CartlyColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      promo.ctaLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: CartlyColors.subBrand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedContextHeroCard extends StatelessWidget {
  final SavedCart? cart;
  final VoidCallback onOpenLatest;
  final VoidCallback onOpenAll;
  final VoidCallback onStartShopping;

  const _SavedContextHeroCard({
    required this.cart,
    required this.onOpenLatest,
    required this.onOpenAll,
    required this.onStartShopping,
  });

  @override
  Widget build(BuildContext context) {
    final latest = cart;

    return CartlySurfaceCard(
      radius: CartlyRadii.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CartlyBadge(label: '다음 장보기 시작점'),
          const SizedBox(height: 10),
          Text(
            latest == null ? '지난 장보기부터 다시 시작해보세요' : '최근 저장한 장보기에서 바로 이어보세요',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            latest == null
                ? '카트를 저장해두시면 여기서 지난 장보기와 자주 사는 상품을 바로 이어서 보실 수 있어요.'
                : '${normalizeCartTitleForDisplay(latest.title) ?? '최근 저장 카트'} · ${latest.totalCount}개 · ₩${formatPrice(latest.totalPrice)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CartlyColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: CartlyButtonStyles.primary(
                  backgroundColor: CartlyColors.surfaceNeutral,
                  foregroundColor: CartlyColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ).copyWith(elevation: const WidgetStatePropertyAll(0)),
                onPressed: latest == null ? onStartShopping : onOpenLatest,
                icon: CartlySymbolIcon.sf(
                  latest == null ? 'cart' : 'cart.circle.fill',
                  color: CartlyColors.textPrimary,
                ),
                label: Text(latest == null ? '홈에서 시작하기' : '이 장보기 이어보기'),
              ),
              if (latest != null)
                TextButton.icon(
                  onPressed: onOpenAll,
                  icon: const CartlySymbolIcon.sf('clock.arrow.circlepath'),
                  label: const Text('지난 카트 전체 보기'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlternativeOfferPreviewCard extends StatelessWidget {
  final ExploreAlternativeOffer offer;

  const _AlternativeOfferPreviewCard({required this.offer});

  String _ctaLabel() {
    if (offer.price != null) {
      return '₩${formatPrice(offer.price!)}';
    }
    final provider = offer.provider.trim();
    if (provider.isEmpty) {
      return '상세 페이지에서 확인하기';
    }
    return '$provider에서 확인하기';
  }

  Future<void> _openLink(String deeplink) async {
    final uri = Uri.tryParse(deeplink);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final deeplink = offer.deeplinkUrl?.trim();
    final canOpen = deeplink != null && deeplink.isNotEmpty;

    return CartlySurfaceCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: CartlyColors.surface1,
      radius: CartlyRadii.control,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AlternativeOfferThumbnail(imageUrl: offer.thumbnailUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: canOpen ? () => _openLink(deeplink) : null,
                  style: CartlyButtonStyles.secondaryOutline(
                    foregroundColor: CartlyColors.textPrimary,
                    borderColor: CartlyColors.line,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _ctaLabel(),
                        style: TextStyle(
                          fontSize: offer.price != null ? 14 : 13,
                          fontWeight: FontWeight.w800,
                          color: canOpen
                              ? CartlyColors.textPrimary
                              : CartlyColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CartlySymbolIcon.sf(
                        'square.and.arrow.up',
                        size: CartlyIconSizes.inline,
                        color: CartlyColors.subBrand,
                      ),
                    ],
                  ),
                ),
                if (offer.subtitle != null &&
                    offer.subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    offer.subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CartlyColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
                if (offer.highlights.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...offer.highlights.map(
                    (highlight) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• $highlight',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CartlyColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlternativeOfferThumbnail extends StatelessWidget {
  final String? imageUrl;

  const _AlternativeOfferThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl?.trim() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(CartlyRadii.control),
      child: Container(
        width: 72,
        height: 72,
        color: CartlyColors.surface2,
        child: trimmed.isEmpty
            ? const Center(
                child: CartlySymbolIcon.sf(
                  'photo.on.rectangle.angled',
                  size: 22,
                  color: CartlyColors.textTertiary,
                ),
              )
            : Image.network(
                trimmed,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: CartlySymbolIcon.sf(
                      'photo.on.rectangle.angled',
                      size: 22,
                      color: CartlyColors.textTertiary,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyInfoCard extends StatelessWidget {
  final String title;
  final String body;

  const _EmptyInfoCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return CartlySurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CartlyColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisitItem {
  final String decisionKey;
  final String name;
  final int price;
  final String reason;
  final String badge;
  final String reasonLabel;

  const _RevisitItem({
    required this.decisionKey,
    required this.name,
    required this.price,
    required this.reason,
    required this.badge,
    required this.reasonLabel,
  });
}

class _RepeatCandidate {
  final String name;
  final int price;
  final int repeatCount;

  const _RepeatCandidate({
    required this.name,
    required this.price,
    required this.repeatCount,
  });
}

class _IntentDetail {
  final String name;
  final int price;
  final String badge;
  final String summary;
  final List<String> comparePoints;
  final String futureNote;
  final ExploreOfferQuery? offerQuery;

  const _IntentDetail({
    required this.name,
    required this.price,
    required this.badge,
    required this.summary,
    required this.comparePoints,
    required this.futureNote,
    this.offerQuery,
  });

  factory _IntentDetail.fromRevisitItem(_RevisitItem item) {
    return _IntentDetail(
      name: item.name,
      price: item.price,
      badge: item.badge,
      summary: '${item.reasonLabel} · ${item.reason}',
      comparePoints: const [
        '현재 담은 가격과 이후 대체안 가격 비교',
        '같은 용도의 다른 브랜드/구성 비교',
        '묶음 상품 또는 대용량 단가 비교',
      ],
      futureNote: '여기서 필터된 네이버쇼핑 결과를 바로 비교해볼 수 있어요.',
      offerQuery: ExploreOfferQuery(
        intentKey: ExploreIntentNormalizer.normalize(item.name).intentKey,
        queryText: ExploreIntentNormalizer.normalize(
          item.name,
        ).normalizedQueryText,
        sourceType: item.badge == '현재 카트'
            ? ExploreOfferSourceType.currentCart
            : ExploreOfferSourceType.pendingReview,
        referencePrice: item.price,
      ),
    );
  }

  factory _IntentDetail.fromRepeatCandidate(_RepeatCandidate candidate) {
    return _IntentDetail(
      name: candidate.name,
      price: candidate.price,
      badge: '반복 구매',
      summary: '저장한 카트에 ${candidate.repeatCount}번 담았어요. 자주 다시 찾는 상품으로 보고 있어요.',
      comparePoints: const [
        '지난에 샀던 가격과 지금 보이는 가격 비교',
        '묶음 상품이나 대용량 옵션 비교',
        '다시 살 만한 구성인지 확인',
      ],
      futureNote: '자주 사는 상품도 필터된 네이버쇼핑 결과로 먼저 비교해볼 수 있어요.',
      offerQuery: ExploreOfferQuery(
        intentKey: ExploreIntentNormalizer.normalize(candidate.name).intentKey,
        queryText: ExploreIntentNormalizer.normalize(
          candidate.name,
        ).normalizedQueryText,
        sourceType: ExploreOfferSourceType.repeatPurchase,
        referencePrice: candidate.price,
      ),
    );
  }

  factory _IntentDetail.fromOfferSlot(ExploreOfferSlot slot) {
    return _IntentDetail(
      name: slot.anchorName,
      price: slot.anchorPrice,
      badge: slot.sourceLabel,
      summary: '${slot.sourceLabel} 기준으로 함께 볼 만한 비슷한 상품을 모아둔 자리예요.',
      comparePoints: slot.comparePoints,
      futureNote: '이 자리에서 필터된 네이버쇼핑 결과를 먼저 비교해볼 수 있어요.',
      offerQuery: slot.query,
    );
  }
}

class _RepeatAccumulator {
  final String name;
  int lastPrice;
  int count = 0;

  _RepeatAccumulator({required this.name, required this.lastPrice});
}
