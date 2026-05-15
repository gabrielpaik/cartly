import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_ad_slot.dart';
import '../models/user_session.dart';
import '../services/ad_tracking_service.dart';
import '../services/app_config_store.dart';
import '../services/app_navigation_service.dart';
import '../services/auth_store.dart';
import '../widgets/admob_banner_slot.dart';
import 'cartly_symbol_icon.dart';

class AudienceBannerSlot extends StatelessWidget {
  final bool showForGuests;
  final bool showForMembers;

  const AudienceBannerSlot({
    super.key,
    required this.showForGuests,
    required this.showForMembers,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserSession?>(
      valueListenable: AuthStore.instance.session,
      builder: (context, session, _) {
        if (session == null) {
          return const SizedBox.shrink();
        }

        final showBanner = session.isGuest ? showForGuests : showForMembers;
        if (!showBanner) {
          return const SizedBox.shrink();
        }

        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Center(child: AdMobBannerSlot()),
        );
      },
    );
  }
}

class InlinePromoSlot extends StatefulWidget {
  final String slotKey;
  final String title;
  final String message;
  final double height;

  const InlinePromoSlot({
    super.key,
    required this.slotKey,
    required this.title,
    required this.message,
    required this.height,
  });

  @override
  State<InlinePromoSlot> createState() => _InlinePromoSlotState();
}

class _InlinePromoSlotState extends State<InlinePromoSlot> {
  Timer? _rotationTimer;
  int _rotationTick = 0;
  String? _lastImpressionKey;

  @override
  void initState() {
    super.initState();
    _rotationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _rotationTick += 1;
      });
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  int _activeCreativeIndex(AppAdSlot slot) {
    final creatives = slot.config.creatives;
    if (creatives.length <= 1) return 0;
    if (slot.config.rotationMode == 'random') {
      final seed = slot.slotKey.codeUnits.fold<int>(17, (sum, item) => sum + item);
      return Random(seed + _rotationTick).nextInt(creatives.length);
    }
    return _rotationTick % creatives.length;
  }

  AppAdCreative? _activeCreative(AppAdSlot? slot) {
    if (slot == null) return null;
    final creatives = slot.config.creatives;
    if (creatives.isNotEmpty) {
      return creatives[_activeCreativeIndex(slot)];
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

  Future<void> _handleTap(AppAdSlot slot, AppAdCreative creative) async {
    if (!creative.hasAction) return;

    await AdTrackingService.instance.recordClick(
      slot: slot,
      creative: creative,
      screenName: slot.config.screen ?? widget.slotKey,
    );

    final landing = creative.landing;
    if (landing != null && landing.isValid) {
      switch (landing.type) {
        case 'explore_section':
          AppNavigationService.instance.selectTab(1);
          return;
        case 'my_section':
          AppNavigationService.instance.selectTab(2);
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

  String _resolveText(String? value, String fallback) {
    final trimmed = value?.trim();
    return trimmed != null && trimmed.isNotEmpty ? trimmed : fallback;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppAdSlot>>(
      valueListenable: AppConfigStore.instance.adSlots,
      builder: (context, slots, child) {
        AppAdSlot? liveSlot;
        for (final slot in slots) {
          if (slot.slotKey == widget.slotKey) {
            liveSlot = slot;
            break;
          }
        }
        if (liveSlot != null && !liveSlot.enabled) {
          return const SizedBox.shrink();
        }

        final activeCreative = _activeCreative(liveSlot);
        if (liveSlot != null && activeCreative != null) {
          final trackedSlot = liveSlot;
          final trackedCreative = activeCreative;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _maybeRecordImpression(trackedSlot, trackedCreative);
          });
        }

        final slotTitle = _resolveText(activeCreative?.title, _resolveText(liveSlot?.config.title, widget.title));
        final slotMessage = _resolveText(activeCreative?.message, _resolveText(liveSlot?.config.message, widget.message));
        final slotHeight = liveSlot?.config.maxHeight ?? widget.height;
        final ctaLabel = _resolveText(activeCreative?.ctaLabel, _resolveText(liveSlot?.config.ctaLabel, widget.slotKey));
        final imageUrl = activeCreative?.imageUrl?.trim().isNotEmpty == true
            ? activeCreative!.imageUrl!.trim()
            : liveSlot?.config.imageUrl?.trim();
        final creatives = liveSlot?.config.creatives ?? const <AppAdCreative>[];
        final activeIndex = liveSlot == null ? 0 : _activeCreativeIndex(liveSlot);
        final hasTapAction = activeCreative?.hasAction ?? false;

        final card = AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: Container(
            key: ValueKey('${widget.slotKey}:${activeCreative?.campaignId ?? 'fallback'}'),
            constraints: BoxConstraints(minHeight: slotHeight),
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF4F5), Color(0xFFF7F9FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9E9E9)),
            ),
            child: Row(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return PromoSlotIcon(hasTapAction: hasTapAction);
                      },
                    ),
                  ),
                ] else ...[
                  PromoSlotIcon(hasTapAction: hasTapAction),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slotTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slotMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      if (creatives.length > 1) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(creatives.length, (index) {
                            final selected = index == activeIndex;
                            return Container(
                              width: selected ? 14 : 6,
                              height: 6,
                              margin: EdgeInsets.only(right: index == creatives.length - 1 ? 0 : 4),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFE31837) : const Color(0xFFD0D5DD),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ctaLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: hasTapAction
                          ? const Color(0xFFE31837)
                          : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (!hasTapAction || liveSlot == null || activeCreative == null) {
          return card;
        }

        final tappableSlot = liveSlot;
        final tappableCreative = activeCreative;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleTap(tappableSlot, tappableCreative),
          child: card,
        );
      },
    );
  }
}

class PromoSlotIcon extends StatelessWidget {
  final bool hasTapAction;

  const PromoSlotIcon({super.key, required this.hasTapAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFE31837).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CartlySymbolIcon.sf(
        hasTapAction ? 'square.and.arrow.up' : 'tag',
        color: const Color(0xFFE31837),
      ),
    );
  }
}
