import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/cartly_ui.dart';
import '../models/app_ad_slot.dart';
import '../services/ad_tracking_service.dart';
import '../services/app_config_store.dart';
import '../services/app_navigation_service.dart';
import '../services/auth_store.dart';
import 'cartly_symbol_icon.dart';

class HomeFloatingPromoSlot extends StatefulWidget {
  final String slotKey;
  final Duration delay;
  final double bottomOffset;

  const HomeFloatingPromoSlot({
    super.key,
    required this.slotKey,
    required this.delay,
    required this.bottomOffset,
  });

  @override
  State<HomeFloatingPromoSlot> createState() => _HomeFloatingPromoSlotState();
}

class _HomeFloatingPromoSlotState extends State<HomeFloatingPromoSlot> {
  Timer? _showTimer;
  bool _ready = false;
  bool _closed = false;
  bool _hiddenForToday = false;
  String? _lastImpressionKey;

  @override
  void initState() {
    super.initState();
    _primeVisibility();
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  Future<void> _primeVisibility() async {
    final hidden = await _isHiddenForToday();
    if (!mounted) return;
    setState(() {
      _hiddenForToday = hidden;
    });
    if (hidden) return;
    _showTimer?.cancel();
    _showTimer = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    });
  }

  Future<bool> _isHiddenForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _todayHideKey();
    final stored = prefs.getString(key)?.trim();
    final today = _dayKey(DateTime.now());
    if (stored == today) {
      return true;
    }
    if (stored != null && stored.isNotEmpty && stored != today) {
      await prefs.remove(key);
    }
    return false;
  }

  String _todayHideKey() => 'cartly.ad.${widget.slotKey}.hiddenUntilDay';

  String _dayKey(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  AppAdCreative? _activeCreative(AppAdSlot slot) {
    final creatives = slot.config.creatives;
    if (creatives.isNotEmpty) {
      return creatives.first;
    }
    return slot.config.primaryCreative;
  }

  void _maybeRecordImpression(AppAdSlot slot, AppAdCreative creative) {
    final campaignId = creative.campaignId.trim();
    if (campaignId.isEmpty || !slot.enabled) return;
    final impressionKey = '${slot.slotKey}:$campaignId';
    if (_lastImpressionKey == impressionKey) return;
    _lastImpressionKey = impressionKey;
    unawaited(
      AdTrackingService.instance.recordImpression(
        slot: slot,
        creative: creative,
        screenName: slot.config.screen ?? widget.slotKey,
      ),
    );
  }

  AppAdLanding? _resolveLanding(AppAdCreative creative) {
    final landing = creative.landing;
    if (landing == null) return null;

    final isGuest = AuthStore.instance.session.value?.isGuest ?? true;
    final params = landing.params;
    final prefix = isGuest ? 'guest' : 'member';
    final type = (params['${prefix}LandingType'] as String?)?.trim() ?? '';
    final key = (params['${prefix}LandingKey'] as String?)?.trim() ?? '';
    if (type.isEmpty || key.isEmpty) {
      return landing;
    }
    final nestedParams = params['${prefix}LandingParams'];
    return AppAdLanding(
      type: type,
      key: key,
      params: nestedParams is Map<String, dynamic>
          ? nestedParams
          : nestedParams is Map
          ? Map<String, dynamic>.from(nestedParams)
          : const <String, dynamic>{},
    );
  }

  bool _opensAccountSettings(String key) {
    return {
      'account_settings',
      'profile_edit',
      'settings_share',
      'settings',
    }.contains(key.trim());
  }

  bool _usesFullBanner(AppAdSlot slot, AppAdCreative creative) {
    final creativeStyle = (creative.landing?.params['renderStyle'] as String?)
        ?.trim();
    final slotStyle = (slot.config.landing?.params['renderStyle'] as String?)
        ?.trim();
    final style = creativeStyle?.isNotEmpty == true ? creativeStyle : slotStyle;
    return style == 'full_banner';
  }

  Widget _buildActionButtons({
    required String ctaLabel,
    required VoidCallback onHideForToday,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onHideForToday,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('오늘 하루 보지 않기'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: CartlyColors.brand,
              foregroundColor: CartlyColors.onBrandPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(ctaLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildLegacyPromoContent({
    required String title,
    required String message,
    required String? imageUrl,
    required String ctaLabel,
    required bool hasTapAction,
    required VoidCallback onHideForToday,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CartlyColors.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'PROMO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: CartlyColors.brand,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    imageUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _FloatingPromoIcon(hasTapAction: hasTapAction);
                    },
                  ),
                ),
              ] else ...[
                _FloatingPromoIcon(hasTapAction: hasTapAction),
              ],
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: CartlyColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CartlyColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildActionButtons(
            ctaLabel: ctaLabel,
            onHideForToday: onHideForToday,
            onTap: onTap,
          ),
        ],
      ),
    );
  }

  Widget _buildFullBannerContent({
    required double bannerHeight,
    required String title,
    required String message,
    required String imageUrl,
    required String ctaLabel,
    required bool hasTapAction,
    required VoidCallback onHideForToday,
    required VoidCallback onTap,
  }) {
    final hasText = title.trim().isNotEmpty || message.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SizedBox(
            height: bannerHeight,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        CartlyColors.softWarmSurface,
                        CartlyColors.surface1,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      _FloatingPromoIcon(hasTapAction: hasTapAction),
                      if (hasText) ...[
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (title.trim().isNotEmpty)
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: CartlyColors.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                              if (title.trim().isNotEmpty &&
                                  message.trim().isNotEmpty)
                                const SizedBox(height: 6),
                              if (message.trim().isNotEmpty)
                                Text(
                                  message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: CartlyColors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: _buildActionButtons(
            ctaLabel: ctaLabel,
            onHideForToday: onHideForToday,
            onTap: onTap,
          ),
        ),
      ],
    );
  }

  Future<void> _handleTap(AppAdSlot slot, AppAdCreative creative) async {
    if (!creative.hasAction) return;

    unawaited(
      AdTrackingService.instance.recordClick(
        slot: slot,
        creative: creative,
        screenName: slot.config.screen ?? widget.slotKey,
      ),
    );

    final landing = _resolveLanding(creative);
    if (landing != null && landing.isValid) {
      switch (landing.type) {
        case 'explore_section':
          AppNavigationService.instance.selectTab(1);
          return;
        case 'my_section':
          AppNavigationService.instance.selectTab(2);
          if (_opensAccountSettings(landing.key)) {
            await AppNavigationService.instance.openAccountSettings();
          }
          return;
        case 'auth_flow':
          AppNavigationService.instance.selectTab(2);
          await AppNavigationService.instance.openLogin(
            preferSignup: landing.key == 'signup',
          );
          return;
        case 'saved_flow':
          await AppNavigationService.instance.openSaved();
          return;
        case 'home_tab':
          AppNavigationService.instance.selectTab(0);
          return;
      }
    }

    final rawUrl = creative.targetUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _close({required bool hideForToday}) async {
    if (hideForToday) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_todayHideKey(), _dayKey(DateTime.now()));
    }
    if (!mounted) return;
    setState(() {
      _closed = true;
      if (hideForToday) {
        _hiddenForToday = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppAdSlot>>(
      valueListenable: AppConfigStore.instance.adSlots,
      builder: (context, slots, _) {
        AppAdSlot? liveSlot;
        for (final slot in slots) {
          if (slot.slotKey == widget.slotKey) {
            liveSlot = slot;
            break;
          }
        }
        final activeCreative = liveSlot == null
            ? null
            : _activeCreative(liveSlot);
        if (liveSlot == null || activeCreative == null) {
          return const SizedBox.shrink();
        }

        final slot = liveSlot;
        final creative = activeCreative;
        final title = creative.title.trim().isNotEmpty
            ? creative.title.trim()
            : slot.config.title;
        final message = creative.message.trim().isNotEmpty
            ? creative.message.trim()
            : slot.config.message;
        final ctaLabel = (creative.ctaLabel ?? '').trim().isNotEmpty
            ? creative.ctaLabel!.trim()
            : (slot.config.ctaLabel?.trim().isNotEmpty ?? false)
            ? slot.config.ctaLabel!.trim()
            : '자세히 보기';
        final imageUrl = creative.imageUrl?.trim().isNotEmpty == true
            ? creative.imageUrl!.trim()
            : slot.config.imageUrl?.trim();
        final hasTapAction = creative.hasAction;
        final useFullBanner =
            imageUrl != null &&
            imageUrl.isNotEmpty &&
            _usesFullBanner(slot, creative);
        final hasRenderableContent =
            title.trim().isNotEmpty ||
            message.trim().isNotEmpty ||
            (imageUrl?.isNotEmpty ?? false);
        final visible =
            _ready &&
            !_closed &&
            !_hiddenForToday &&
            slot.enabled &&
            hasRenderableContent &&
            hasTapAction;
        if (!visible) {
          return const SizedBox.shrink();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _maybeRecordImpression(slot, creative);
        });

        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _close(hideForToday: false),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: widget.bottomOffset,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 8),
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 240),
                    offset: visible ? Offset.zero : const Offset(0, 1),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: visible ? 1 : 0,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => _handleTap(slot, creative),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: CartlyColors.surface0,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A101828),
                                  blurRadius: 24,
                                  offset: Offset(0, 10),
                                ),
                              ],
                              border: Border.all(color: CartlyColors.line),
                            ),
                            child: useFullBanner
                                ? _buildFullBannerContent(
                                    bannerHeight: slot.config.maxHeight,
                                    title: title,
                                    message: message,
                                    imageUrl: imageUrl,
                                    ctaLabel: ctaLabel,
                                    hasTapAction: hasTapAction,
                                    onHideForToday: () =>
                                        _close(hideForToday: true),
                                    onTap: () => _handleTap(slot, creative),
                                  )
                                : _buildLegacyPromoContent(
                                    title: title,
                                    message: message,
                                    imageUrl: imageUrl,
                                    ctaLabel: ctaLabel,
                                    hasTapAction: hasTapAction,
                                    onHideForToday: () =>
                                        _close(hideForToday: true),
                                    onTap: () => _handleTap(slot, creative),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FloatingPromoIcon extends StatelessWidget {
  final bool hasTapAction;

  const _FloatingPromoIcon({required this.hasTapAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: CartlyColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: CartlySymbolIcon.sf(
          hasTapAction ? 'square.and.arrow.up' : 'tag',
          color: CartlyColors.brand,
          size: 28,
        ),
      ),
    );
  }
}
