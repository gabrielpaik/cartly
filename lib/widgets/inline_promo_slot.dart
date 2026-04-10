import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_ad_slot.dart';
import '../models/user_session.dart';
import '../services/ad_tracking_service.dart';
import '../services/app_config_store.dart';
import '../services/auth_store.dart';
import '../widgets/admob_banner_slot.dart';

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
  String? _lastImpressionKey;

  void _maybeRecordImpression(AppAdSlot slot) {
    final campaignId = slot.config.campaignId?.trim();
    if (campaignId == null || campaignId.isEmpty || !slot.enabled) return;

    final impressionKey = '${slot.slotKey}:$campaignId';
    if (_lastImpressionKey == impressionKey) return;
    _lastImpressionKey = impressionKey;

    unawaited(
      AdTrackingService.instance.recordImpression(
        slot: slot,
        screenName: slot.config.screen ?? widget.slotKey,
      ),
    );
  }

  Future<void> _handleTap(AppAdSlot slot) async {
    final rawUrl = slot.config.targetUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) return;

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;

    await AdTrackingService.instance.recordClick(
      slot: slot,
      screenName: slot.config.screen ?? widget.slotKey,
    );
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

        if (liveSlot != null) {
          final trackedSlot = liveSlot;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _maybeRecordImpression(trackedSlot);
          });
        }

        final slotTitle = _resolveText(liveSlot?.config.title, widget.title);
        final slotMessage = _resolveText(liveSlot?.config.message, widget.message);
        final slotHeight = liveSlot?.config.maxHeight ?? widget.height;
        final ctaLabel = _resolveText(liveSlot?.config.ctaLabel, widget.slotKey);
        final imageUrl = liveSlot?.config.imageUrl?.trim();
        final hasTapAction = (liveSlot?.config.targetUrl?.trim().isNotEmpty ?? false);

        final card = Container(
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
                    color: hasTapAction ? const Color(0xFFE31837) : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        );

        if (!hasTapAction || liveSlot == null) {
          return card;
        }

        final tappableSlot = liveSlot;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleTap(tappableSlot),
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
      child: Icon(
        hasTapAction ? Icons.open_in_new : Icons.local_offer_outlined,
        color: const Color(0xFFE31837),
      ),
    );
  }
}
