import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_support.dart';
import '../models/explore_offer.dart';
import '../models/saved_cart.dart';
import '../pages/cart_detail_page.dart';
import '../services/app_config_store.dart';
import '../services/app_runtime_copy.dart';
import '../services/cart_store.dart';
import '../services/explore_intent_normalizer.dart';
import '../services/explore_offer_service.dart';
import '../widgets/section_header.dart';

const ExploreOfferProvider _offerProvider =
    PendingCoupangPartnersOfferProvider();

const String _exploreStateActiveShopping = 'activeShopping';
const String _exploreStatePostSave = 'postSave';
const String _exploreStateIdlePlanning = 'idlePlanning';
const String _exploreStateStoreContext = 'storeContext';

class ShoppingHelpPage extends StatefulWidget {
  final List<CartItem> items;
  final List<RecentScanEntry> recentScans;
  final VoidCallback onGoHome;
  final VoidCallback onGoSaved;

  const ShoppingHelpPage({
    super.key,
    required this.items,
    required this.recentScans,
    required this.onGoHome,
    required this.onGoSaved,
  });

  @override
  State<ShoppingHelpPage> createState() => _ShoppingHelpPageState();
}

class _ShoppingHelpPageState extends State<ShoppingHelpPage> {
  final Set<String> _dismissedOfferIntentKeys = <String>{};

  @override
  void didUpdateWidget(covariant ShoppingHelpPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldActive =
        oldWidget.items.isNotEmpty || oldWidget.recentScans.isNotEmpty;
    final nextActive =
        widget.items.isNotEmpty || widget.recentScans.isNotEmpty;
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

  int _configInt(
    Map<String, dynamic> config,
    String key,
    int fallback,
  ) {
    final value = config[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  bool _configBool(
    Map<String, dynamic> config,
    String key,
    bool fallback,
  ) {
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

  String _configText(
    Map<String, dynamic> config,
    String key,
    String fallback,
  ) {
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
          if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
            return true;
          }
          if (normalized == 'false' || normalized == '0' || normalized == 'no') {
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
    return sorted.where((promo) {
      if (!promo.isSponsored) return true;
      if (!allowSponsored) return false;
      if (sponsoredCount >= policyMaxSponsored) return false;
      sponsoredCount += 1;
      return true;
    }).toList(growable: false);
  }

  List<ExploreStorePromo> _buildStoreContextPromos(
    Map<String, dynamic> config,
    String state,
  ) {
    final promos = (config['storeContextPromos'] as List?)
        ?.whereType<Map>()
        .map((item) => ExploreStorePromo.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    if (promos != null && promos.isNotEmpty) {
      return _applyPromoPolicy(promos, config, state);
    }

    final body = _configText(
      config,
      'storeContextPromoBody',
      '자주 사는 상품군과 겹치는 할인 행사부터 먼저 보여줘요.',
    );
    final storeName = _configText(
      config,
      'storeContextStoreName',
      '이마트 양재점',
    );
    final ctaLabel = _configText(
      config,
      'storeContextPromoCtaLabel',
      '행사 보기',
    );
    final seeds = _configText(
      config,
      'storeContextPromoSeedLabels',
      '유제품 세일,음료 행사,오늘의 마트 추천',
    )
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final maxPromos = _stateRuleInt(
      config,
      state,
      'storeContextMaxPromos',
      3,
    );
    final sourceType = _configText(
      config,
      'storeContextPromoSourceType',
      'storeSale',
    );
    final isSponsored = _configBool(
      config,
      'storeContextPromoSponsored',
      false,
    );
    final sponsorLabel = _configText(
      config,
      'storeContextPromoSponsorLabel',
      '',
    );
    final priorityStart = _configInt(
      config,
      'storeContextPromoPriorityStart',
      100,
    );

    final generated = List.generate(
      seeds.take(maxPromos).length,
      (index) => ExploreStorePromo(
        id: 'store-promo-${index + 1}',
        title: '${seeds[index]} 확인',
        body: body,
        badgeLabel: seeds[index],
        storeName: storeName,
        ctaLabel: ctaLabel,
        placementLabel: '매장 프로모션',
        intentHint: '같은 구매 의도 기준',
        source: 'store-context-preview',
        sourceType: isSponsored && index == 0 ? 'sponsoredPlacement' : sourceType,
        priority: (priorityStart - (index * 10)) < 0
            ? 0
            : (priorityStart - (index * 10)),
        isSponsored: isSponsored && index == 0,
        sponsorLabel: isSponsored && sponsorLabel.isNotEmpty && index == 0
            ? sponsorLabel
            : null,
      ),
    );
    return _applyPromoPolicy(generated, config, state);
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
        'decisionInbox',
        'revisitItems',
        'repeatCandidates',
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

  String _resolveExploreState(
    Map<String, dynamic> config,
    SavedCart? latest,
  ) {
    final previewState = _normalizeExploreState(config['__previewState'] as String?);
    if (previewState != 'auto') {
      return previewState;
    }

    final forcedState = _normalizeExploreState(config['stateMode'] as String?);
    if (forcedState != 'auto') {
      return forcedState;
    }

    if (_hasActiveShoppingContext) {
      return _exploreStateActiveShopping;
    }
    if (_isLikelyPostSave(latest)) {
      return _exploreStatePostSave;
    }
    return _exploreStateIdlePlanning;
  }

  String _sectionOrderKeyForState(String state) {
    switch (state) {
      case _exploreStateActiveShopping:
        return 'activeShoppingSectionOrder';
      case _exploreStatePostSave:
        return 'postSaveSectionOrder';
      case _exploreStateStoreContext:
        return 'storeContextSectionOrder';
      case _exploreStateIdlePlanning:
      default:
        return 'idlePlanningSectionOrder';
    }
  }

  List<String> _dynamicSectionOrder(
    Map<String, dynamic> config, {
    required bool hasOfferSlots,
    required String state,
  }) {
    final enabled = _enabledSections(config);
    final base = (config[_sectionOrderKeyForState(state)] as String?) ??
        (config['sectionOrder'] as String?) ??
        '';
    final order = base
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .where(enabled.contains)
        .where((part) => hasOfferSlots || part != 'offerSlots')
        .toList(growable: false);
    if (order.isNotEmpty) {
      return order;
    }
    return (config['sectionOrder'] as String? ?? '')
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .where(enabled.contains)
        .where((part) => hasOfferSlots || part != 'offerSlots')
        .toList(growable: false);
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
            final baseOfferSlots = _buildOfferSlots(
              revisitItems: revisitItems,
              repeatCandidates: repeatCandidates,
              exploreConfig: exploreConfig,
              repeatOnly: currentState != _exploreStateActiveShopping,
              state: currentState,
            );
            final offerSlots = baseOfferSlots
                .where((slot) => !_dismissedOfferIntentKeys.contains(slot.intentKey))
                .toList(growable: false);
            final hiddenOfferCount =
                baseOfferSlots.length - offerSlots.length;
            final decisionInboxEntries = _buildDecisionInboxEntries(
              revisitItems: revisitItems,
              offerSlots: offerSlots,
              exploreConfig: exploreConfig,
              state: currentState,
            );
            final orderedSections = _dynamicSectionOrder(
              exploreConfig,
              hasOfferSlots: offerSlots.isNotEmpty || hiddenOfferCount > 0,
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
                      revisitCount: decisionInboxEntries.length,
                      repeatCandidateCount: repeatCandidates.length,
                      onGoHome: widget.onGoHome,
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 20));
                  break;
                case 'decisionInbox':
                  sectionWidgets.add(
                    SectionHeader(
                      title: '결정 인박스',
                      subtitle: '지금 다시 볼 것만 먼저 모아드릴게요',
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 10));
                  sectionWidgets.add(
                    _DecisionSummaryCard(
                      currentCartCount: _totalCount,
                      recentScanCount: decisionInboxEntries.length,
                      revisitCount: offerSlots.length,
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 12));
                  if (decisionInboxEntries.isEmpty) {
                    sectionWidgets.add(
                      const _EmptyInfoCard(
                        title: '지금 다시 볼 결정이 없어요',
                        body: '홈의 전체 목록을 그대로 가져오지 않고, 지금 다시 볼 만한 항목만 보여드릴게요.',
                      ),
                    );
                  } else {
                    sectionWidgets.addAll(
                      decisionInboxEntries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DecisionInboxCard(
                            entry: entry,
                            onTap: () => _showIntentDetailSheet(context, entry.detail),
                          ),
                        ),
                      ),
                    );
                  }
                  sectionWidgets.add(
                    _ActionTile(
                      icon: Icons.shopping_cart_checkout_rounded,
                      title: widget.items.isEmpty ? '홈에서 장보기 시작하기' : '홈에서 실행 이어가기',
                      body: widget.items.isEmpty
                          ? '촬영하고 담고 저장하는 흐름은 홈에서 바로 이어가실 수 있어요.'
                          : '수량 수정이나 저장 같은 실행은 홈에서, 비교와 판단은 Explore에서 이어가시면 돼요.',
                      actionLabel: widget.items.isEmpty ? '홈으로 가기' : '홈에서 실행하기',
                      onTap: widget.onGoHome,
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 20));
                  break;
                case 'revisitItems':
                  sectionWidgets.add(
                    SectionHeader(
                      title: '다시 볼 상품',
                      subtitle: '최근 스캔과 현재 카트에서 다시 볼 상품만 골라 보여드려요',
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 10));
                  if (revisitItems.isEmpty) {
                    sectionWidgets.add(
                      const _EmptyInfoCard(
                        title: '다시 볼 상품이 아직 없어요',
                        body: '현재 카트와 최근 스캔이 쌓이면 다시 볼 후보를 여기 모아드릴게요.',
                      ),
                    );
                  } else {
                    sectionWidgets.addAll(
                      revisitItems.map(
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
                      title: '반복 구매 후보',
                      subtitle: '지난 장보기에서 자주 샀던 상품을 먼저 보여드려요',
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 10));
                  if (repeatCandidates.isEmpty) {
                    sectionWidgets.add(
                      const _EmptyInfoCard(
                        title: '아직 반복 패턴이 부족해요',
                        body: '저장한 카트가 더 쌓이면 자주 사는 상품을 자동으로 보여드릴게요.',
                      ),
                    );
                  } else {
                    sectionWidgets.addAll(
                      repeatCandidates.map(
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
                case 'offerSlots':
                  sectionWidgets.add(
                    SectionHeader(
                      title: '비슷한 상품 비교',
                      subtitle: currentState == _exploreStateActiveShopping
                          ? '지금 담은 상품과 비슷한 대안을 함께 볼 수 있어요'
                          : currentState == _exploreStateStoreContext
                              ? '매장에서 함께 볼 만한 비슷한 상품을 먼저 보여드려요'
                              : currentState == _exploreStatePostSave
                                  ? '방금 저장한 장보기를 바탕으로 비슷한 대안을 보여드려요'
                                  : '자주 사는 상품을 기준으로 비슷한 대안을 보여드려요',
                    ),
                  );
                  sectionWidgets.add(const SizedBox(height: 10));
                  if (hiddenOfferCount > 0) {
                    sectionWidgets.add(
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                            foregroundColor: const Color(0xFF6B2B35),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _dismissedOfferIntentKeys.clear();
                            });
                          },
                          icon: const Icon(Icons.visibility_rounded, size: 18),
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
                      promos: _buildStoreContextPromos(
                        exploreConfig,
                        currentState,
                      ),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                Text(
                  AppRuntimeCopy.text(['help', 'pageTitle'], 'Explore'),
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.2,
                    height: 0.95,
                    color: Color(0xFFE31837),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppRuntimeCopy.text(
                    ['help', 'subtitle'],
                    '지금 필요한 비교를 한곳에서 이어서 보실 수 있어요',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ...sectionWidgets,
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

  String _offerReasonLabelForState(Map<String, dynamic> config, String state) {
    switch (state) {
      case _exploreStatePostSave:
        return _decisionCopyText(
          config,
          'offerReasonLabelPostSave',
          '저장한 뒤 다시 보기',
        );
      case _exploreStateIdlePlanning:
        return _decisionCopyText(
          config,
          'offerReasonLabelIdlePlanning',
          '다음 장보기 준비',
        );
      case _exploreStateStoreContext:
        return _decisionCopyText(
          config,
          'offerReasonLabelStoreContext',
          '지금 매장 할인 보기',
        );
      case _exploreStateActiveShopping:
      default:
        return _decisionCopyText(
          config,
          'offerReasonLabelActiveShopping',
          '지금 비교해보세요',
        );
    }
  }

  int _decisionPriorityInt(
    Map<String, dynamic> config,
    String state,
    String key,
    int fallback,
  ) {
    final priorities = config['stateDecisionPriorities'];
    if (priorities is Map) {
      final rawStatePriorities = priorities[state];
      if (rawStatePriorities is Map) {
        final value = rawStatePriorities[key];
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

  int _decisionMaxCountInt(
    Map<String, dynamic> config,
    String state,
    String key,
    int fallback,
  ) {
    final maxCounts = config['stateDecisionMaxCounts'];
    if (maxCounts is Map) {
      final rawStateMaxCounts = maxCounts[state];
      if (rawStateMaxCounts is Map) {
        final value = rawStateMaxCounts[key];
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

  List<_RevisitItem> _buildRevisitItems(
    Map<String, dynamic> exploreConfig,
    String state,
  ) {
    final currentNames = widget.items.map((item) => _normalize(item.name)).toSet();
    final results = <_RevisitItem>[];
    final recentScanLimit = _stateRuleInt(
      exploreConfig,
      state,
      'revisitRecentScanLimit',
      3,
    );
    final cartItemLimit = _stateRuleInt(
      exploreConfig,
      state,
      'revisitCartItemLimit',
      3,
    );
    final maxItems = _stateRuleInt(
      exploreConfig,
      state,
      'revisitMaxItems',
      4,
    );

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
                  '방금 스캔했지만 아직 카트에 담지 않았어요. 지금 확인해 두시면 놓치지 않아요.',
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
                  '아직 담기 전이에요',
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

  List<_DecisionInboxEntry> _buildDecisionInboxEntries({
    required List<_RevisitItem> revisitItems,
    required List<ExploreOfferSlot> offerSlots,
    required Map<String, dynamic> exploreConfig,
    required String state,
  }) {
    final entries = <_DecisionInboxEntry>[];
    final offeredIntentKeys = offerSlots.map((slot) => slot.intentKey).toSet();

    for (final slot in offerSlots) {
      final offerReasonLabel = _offerReasonLabelForState(exploreConfig, state);
      final offerBody = _decisionCopyText(
        exploreConfig,
        'offerBody',
        '같은 용도의 다른 선택지를 바로 비교하실 수 있어요. 가격이나 구성만 가볍게 확인해보세요.',
      );
      final decisionKey = switch (slot.sourceType) {
        ExploreOfferSourceType.currentCart => 'offerCurrentCart',
        ExploreOfferSourceType.pendingReview => 'offerPendingReview',
        ExploreOfferSourceType.repeatPurchase => 'offerRepeatPurchase',
      };
      final fallbackPriority = switch (decisionKey) {
        'offerCurrentCart' => 280,
        'offerRepeatPurchase' => 220,
        _ => 300,
      };
      entries.add(
        _DecisionInboxEntry(
          title: '${slot.anchorName} 대체안 확인',
          body: '${slot.context} $offerBody',
          badge: '오퍼 도착',
          decisionKey: decisionKey,
          reasonLabel: offerReasonLabel,
          detail: _IntentDetail.fromOfferSlot(slot),
          priority: _decisionPriorityInt(
            exploreConfig,
            state,
            decisionKey,
            fallbackPriority,
          ),
        ),
      );
    }

    for (final item in revisitItems) {
      final intentKey = _normalize(item.name);
      if (offeredIntentKeys.contains(intentKey)) continue;
      entries.add(
        _DecisionInboxEntry(
          title: item.badge == '미결정'
              ? '${item.name} 아직 담기 전이에요'
              : item.badge == '재확인'
                  ? '${item.name} 다시 확인 권장'
                  : '${item.name} 비교 후보',
          body: item.reason,
          badge: item.badge,
          decisionKey: item.decisionKey,
          reasonLabel: item.reasonLabel,
          detail: _IntentDetail.fromRevisitItem(item),
          priority: _decisionPriorityInt(
            exploreConfig,
            state,
            item.decisionKey,
            item.badge == '미결정' ? 220 : 180,
          ),
        ),
      );
    }

    entries.sort((a, b) => b.priority.compareTo(a.priority));
    final counts = <String, int>{};
    final filtered = <_DecisionInboxEntry>[];
    for (final entry in entries) {
      final maxCount = _decisionMaxCountInt(
        exploreConfig,
        state,
        entry.decisionKey,
        4,
      );
      final currentCount = counts[entry.decisionKey] ?? 0;
      if (currentCount >= maxCount) {
        continue;
      }
      counts[entry.decisionKey] = currentCount + 1;
      filtered.add(entry);
      if (filtered.length >= 4) {
        break;
      }
    }
    return filtered;
  }

  List<_RepeatCandidate> _buildRepeatCandidates(
    List<SavedCart> carts,
    Map<String, dynamic> exploreConfig,
    String state,
  ) {
    final currentNames = widget.items.map((item) => _normalize(item.name)).toSet();
    final Map<String, _RepeatAccumulator> map = {};

    for (final cart in carts) {
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

    final candidates = map.entries
        .where((entry) => entry.value.count >= repeatMinCount && !currentNames.contains(entry.key))
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
        ...revisitItems.take(2).map(
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
      ...repeatCandidates.take(repeatOnly
              ? _stateRuleInt(exploreConfig, state, 'offerMaxSlots', 3)
              : 1).map(
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
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ),
                    _Badge(label: detail.badge),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '₩${formatPrice(detail.price)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail.summary,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '앞으로 여기서 볼 것',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
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
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: Color(0xFFE31837),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    detail.futureNote,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE31837),
                      height: 1.45,
                    ),
                  ),
                ),
                if (detail.offerQuery != null) ...[
                  const SizedBox(height: 18),
                  FutureBuilder<List<ExploreAlternativeOffer>>(
                    future: _offerProvider.fetchOffers(detail.offerQuery!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(minHeight: 3),
                        );
                      }

                      final offers = snapshot.data ?? const [];
                      if (offers.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '함께 볼 수 있는 상품',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
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
  final int revisitCount;
  final int repeatCandidateCount;
  final VoidCallback onGoHome;

  const _ExploreHeroCard({
    required this.itemCount,
    required this.totalPrice,
    required this.recentScanCount,
    required this.revisitCount,
    required this.repeatCandidateCount,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE31837),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            itemCount == 0 ? '오늘 살 것부터 정리해요' : '같은 구매 의도 안에서 결정 이어가기',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            itemCount == 0
                ? 'Explore는 추천 피드가 아니라, 장보기 결정을 밀어주는 인박스로 갈 거예요.'
                : '$itemCount개 상품 · ₩${formatPrice(totalPrice)} · 재검토 $revisitCount건 · 반복 후보 $repeatCandidateCount건',
            style: const TextStyle(
              color: Colors.white,
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
              _HeroStat(label: '최근 스캔', value: '$recentScanCount개'),
              _HeroStat(label: '다시 볼 상품', value: '$revisitCount개'),
              _HeroStat(label: '비교 후보', value: '${revisitCount == 0 && repeatCandidateCount == 0 ? 0 : (revisitCount >= 2 ? 2 : revisitCount) + (repeatCandidateCount > 0 ? 1 : 0)}개'),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onGoHome,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFE31837),
            ),
            child: Text(itemCount == 0 ? '상품 담으러 가기' : '현재 카트 이어서 보기'),
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
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DecisionSummaryCard extends StatelessWidget {
  final int currentCartCount;
  final int recentScanCount;
  final int revisitCount;

  const _DecisionSummaryCard({
    required this.currentCartCount,
    required this.recentScanCount,
    required this.revisitCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(label: '현재 카트', value: '$currentCartCount개'),
          ),
          Expanded(
            child: _SummaryMetric(label: '결정 카드', value: '$recentScanCount건'),
          ),
          Expanded(
            child: _SummaryMetric(label: '비교 후보', value: '$revisitCount건'),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
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
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _Badge(label: item.badge),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₩${formatPrice(item.price)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                item.reason,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '비교 준비 보기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE31837),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecisionInboxCard extends StatelessWidget {
  final _DecisionInboxEntry entry;
  final VoidCallback onTap;

  const _DecisionInboxCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _Badge(label: entry.badge),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(label: entry.reasonLabel),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₩${formatPrice(entry.detail.price)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                entry.body,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '결정 이유 보기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE31837),
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
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFFE31837)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '저장 카트 ${candidate.repeatCount}번 등장 · 최근 확인 가격 ₩${formatPrice(candidate.price)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '비슷한 상품 보기',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE31837),
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
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _Badge(label: '비슷한 상품', dark: true),
                  const SizedBox(width: 8),
                  _Badge(label: slot.sourceLabel, dark: true),
                  const Spacer(),
                  if (onDismiss != null)
                    Tooltip(
                      message: '이번 화면에서만 가리기',
                      child: InkWell(
                        onTap: onDismiss,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.visibility_off_rounded,
                            size: 16,
                            color: Colors.white,
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
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${slot.context} 함께 살펴볼 만한 비슷한 상품이에요. 가격이나 구성 차이를 가볍게 비교해보세요.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Text(
                  slot.ctaLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF2F2), Color(0xFFFFFBEB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _Badge(label: 'store context'),
              _Badge(label: enabled ? 'lane on' : 'lane off'),
              _Badge(label: storeName),
              _Badge(label: 'promo ${promos.length}개'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
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
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Badge(label: promo.badgeLabel),
                        _Badge(label: promo.placementLabel),
                        _Badge(label: promo.intentHint),
                        _Badge(label: promo.sourceType),
                        _Badge(label: 'priority ${promo.priority}'),
                        _Badge(label: promo.isSponsored ? 'sponsored' : 'organic'),
                        if (promo.sponsorLabel != null)
                          _Badge(label: promo.sponsorLabel!),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      promo.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      promo.body,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      promo.ctaLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE31837),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Badge(label: '다음 장보기 시작점'),
          const SizedBox(height: 10),
          Text(
            latest == null ? '지난 장보기부터 다시 시작해보세요' : '최근 저장한 장보기에서 바로 이어보세요',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            latest == null
                ? '카트를 저장해두시면 여기서 지난 장보기와 자주 사는 상품을 바로 이어서 보실 수 있어요.'
                : '${latest.title ?? '최근 저장 카트'} · ${latest.totalCount}개 · ₩${formatPrice(latest.totalPrice)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: latest == null ? onStartShopping : onOpenLatest,
                icon: Icon(
                  latest == null ? Icons.home_rounded : Icons.shopping_bag_rounded,
                ),
                label: Text(
                  latest == null ? '홈에서 시작하기' : '이 장보기 이어보기',
                ),
              ),
              if (latest != null)
                TextButton.icon(
                  onPressed: onOpenAll,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('지난 카트 전체 보기'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFE31837)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(onPressed: onTap, child: Text(actionLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlternativeOfferPreviewCard extends StatelessWidget {
  final ExploreAlternativeOffer offer;

  const _AlternativeOfferPreviewCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final deeplink = offer.deeplinkUrl?.trim();
    final canOpen = deeplink != null && deeplink.isNotEmpty;

    return InkWell(
      onTap: canOpen
          ? () async {
              final uri = Uri.tryParse(deeplink);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    offer.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _Badge(label: offer.provider),
                if (canOpen) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: Color(0xFFE31837),
                  ),
                ],
              ],
            ),
            if (offer.subtitle != null && offer.subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                offer.subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
            ],
            if (offer.price != null) ...[
              const SizedBox(height: 6),
              Text(
                '₩${formatPrice(offer.price!)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
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
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
            if (canOpen) ...[
              const SizedBox(height: 8),
              Text(
                deeplink,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE31837),
                ),
              ),
            ],
          ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool dark;

  const _Badge({required this.label, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = dark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFFFE5E8);
    final foregroundColor = dark ? Colors.white : const Color(0xFFE31837);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _DecisionInboxEntry {
  final String title;
  final String body;
  final String badge;
  final String decisionKey;
  final String reasonLabel;
  final _IntentDetail detail;
  final int priority;

  const _DecisionInboxEntry({
    required this.title,
    required this.body,
    required this.badge,
    required this.decisionKey,
    required this.reasonLabel,
    required this.detail,
    required this.priority,
  });
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
      futureNote: '여기에 같은 구매 의도를 유지하는 Coupang Partners 대안 CTA가 연결될 예정이에요.',
      offerQuery: ExploreOfferQuery(
        intentKey: ExploreIntentNormalizer.normalize(item.name).intentKey,
        queryText: ExploreIntentNormalizer
            .normalize(item.name)
            .normalizedQueryText,
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
      futureNote: '자주 사는 상품일수록 비슷한 대안을 함께 보는 게 더 자연스러워요.',
      offerQuery: ExploreOfferQuery(
        intentKey: ExploreIntentNormalizer.normalize(candidate.name).intentKey,
        queryText: ExploreIntentNormalizer
            .normalize(candidate.name)
            .normalizedQueryText,
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
      futureNote: '연결이 준비되면 이 자리에서 비슷한 상품을 바로 이어서 비교하실 수 있어요.',
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
