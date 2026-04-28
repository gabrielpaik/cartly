import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_support.dart';
import '../models/explore_offer.dart';
import '../models/saved_cart.dart';
import '../services/app_runtime_copy.dart';
import '../services/cart_store.dart';
import '../services/explore_intent_normalizer.dart';
import '../services/explore_offer_service.dart';
import '../widgets/recent_saved_preview_card.dart';
import '../widgets/section_header.dart';

class ShoppingHelpPage extends StatelessWidget {
  static const ExploreOfferProvider _offerProvider =
      PendingCoupangPartnersOfferProvider();

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

  int get _totalPrice => items.fold(0, (sum, item) => sum + item.totalPrice);
  int get _totalCount => items.fold(0, (sum, item) => sum + item.quantity);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedCart>>(
      valueListenable: CartStore.instance.carts,
      builder: (context, carts, _) {
        final revisitItems = _buildRevisitItems();
        final repeatCandidates = _buildRepeatCandidates(carts);
        final offerSlots = _buildOfferSlots(
          revisitItems: revisitItems,
          repeatCandidates: repeatCandidates,
        );
        final latest = carts.isEmpty ? null : carts.first;

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
                '지금 살 상품 결정과 지난 장보기 회고를 한 곳에서 이어가요',
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _ExploreHeroCard(
              itemCount: _totalCount,
              totalPrice: _totalPrice,
              recentScanCount: recentScans.length,
              revisitCount: revisitItems.length,
              repeatCandidateCount: repeatCandidates.length,
              onGoHome: onGoHome,
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: '결정 인박스',
              subtitle: '지금 구매 의도를 깨지 않는 일만 먼저 모았어',
            ),
            const SizedBox(height: 10),
            _DecisionSummaryCard(
              currentCartCount: _totalCount,
              recentScanCount: recentScans.length,
              revisitCount: revisitItems.length,
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.shopping_cart_checkout_rounded,
              title: items.isEmpty ? '현재 카트 비어 있음' : '현재 카트 이어서 보기',
              body: items.isEmpty
                  ? '홈에서 상품을 담기 시작하면 Explore도 같은 의도 기준으로 정리돼요.'
                  : '$_totalCount개 상품, ₩${formatPrice(_totalPrice)} 상태예요. 저장 전 마지막 확인에 좋아요.',
              actionLabel: items.isEmpty ? '상품 담으러 가기' : '카트 확인하기',
              onTap: onGoHome,
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.document_scanner_outlined,
              title: recentScans.isEmpty ? '검토 대기 스캔 없음' : '최근 스캔 다시 보기',
              body: recentScans.isEmpty
                  ? '아직 판단이 남은 스캔 결과는 없어요.'
                  : '${recentScans.first.item.name}${recentScans.length > 1 ? ' 외 ${recentScans.length - 1}건' : ''}이(가) 아직 확인 대기 중이에요.',
              actionLabel: '홈에서 검토하기',
              onTap: onGoHome,
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: '다시 볼 상품',
              subtitle: '최근 스캔, 현재 카트, 지난 저장 이력에서 다시 판단할 후보만 추렸어',
            ),
            const SizedBox(height: 10),
            if (revisitItems.isEmpty)
              const _EmptyInfoCard(
                title: '다시 볼 상품이 아직 없어요',
                body: '현재 카트나 최근 스캔이 쌓이면 같은 구매 의도 안에서 재검토 후보를 여기 모아둘게요.',
              )
            else
              ...revisitItems.map(
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
            const SizedBox(height: 8),
            SectionHeader(
              title: '반복 구매 후보',
              subtitle: '저장된 카트에서 자주 다시 등장한 상품만 보여줘요',
            ),
            const SizedBox(height: 10),
            if (repeatCandidates.isEmpty)
              const _EmptyInfoCard(
                title: '아직 반복 패턴이 부족해요',
                body: '저장 카트가 더 쌓이면 다시 살 가능성이 높은 상품을 자동으로 올려둘게요.',
              )
            else
              ...repeatCandidates.take(4).map(
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
            const SizedBox(height: 20),
            SectionHeader(
              title: '대체 상품 오퍼 슬롯',
              subtitle: '곧 들어올 Coupang Partners 오퍼가 same-intent 기준으로 꽂힐 자리예요',
            ),
            const SizedBox(height: 10),
            if (offerSlots.isEmpty)
              const _EmptyInfoCard(
                title: '오퍼 슬롯 준비 완료',
                body: '현재 카트나 반복 구매 후보가 생기면 이 영역에 같은 상품군 대체안이 붙어요.',
              )
            else
              ...offerSlots.map(
                (slot) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OfferSlotCard(
                    slot: slot,
                    onTap: () => _showIntentDetailSheet(
                      context,
                      _IntentDetail.fromOfferSlot(slot),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SectionHeader(
              title: '지난 장보기 맥락',
              subtitle: '최근 저장 카트에서 바로 돌아가 비교할 수 있어',
            ),
            const SizedBox(height: 10),
            RecentSavedPreviewCard(cart: latest),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onGoSaved,
                icon: const Icon(Icons.history_rounded),
                label: const Text('지난 카트 전체 보기'),
              ),
            ),
          ],
        );
      },
    );
  }

  List<_RevisitItem> _buildRevisitItems() {
    final currentNames = items.map((item) => _normalize(item.name)).toSet();
    final results = <_RevisitItem>[];

    for (final entry in recentScans.take(3)) {
      final normalizedName = _normalize(entry.item.name);
      final inCart = currentNames.contains(normalizedName);
      results.add(
        _RevisitItem(
          name: entry.item.name,
          price: entry.item.price,
          reason: inCart ? '최근 스캔 후 카트에 담김, 다시 확인 권장' : '최근 스캔 후 아직 카트 반영 전',
          badge: inCart ? '재확인' : '미결정',
        ),
      );
    }

    for (final item in items.take(3)) {
      results.add(
        _RevisitItem(
          name: item.name,
          price: item.price,
          reason: item.quantity > 1 ? '수량 ${item.quantity}개로 담겨 있어 가격 비교 가치가 커요' : '현재 카트에 담긴 핵심 구매 후보예요',
          badge: '현재 카트',
        ),
      );
    }

    final deduped = <String>{};
    return results.where((item) => deduped.add(_normalize(item.name))).take(4).toList();
  }

  List<_RepeatCandidate> _buildRepeatCandidates(List<SavedCart> carts) {
    final currentNames = items.map((item) => _normalize(item.name)).toSet();
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

    final candidates = map.entries
        .where((entry) => entry.value.count >= 2 && !currentNames.contains(entry.key))
        .map(
          (entry) => _RepeatCandidate(
            name: entry.value.name,
            price: entry.value.lastPrice,
            repeatCount: entry.value.count,
          ),
        )
        .toList()
      ..sort((a, b) => b.repeatCount.compareTo(a.repeatCount));

    return candidates;
  }

  List<ExploreOfferSlot> _buildOfferSlots({
    required List<_RevisitItem> revisitItems,
    required List<_RepeatCandidate> repeatCandidates,
  }) {
    final signals = <ExploreOfferSignal>[
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
          ctaLabel: '같은 상품군 대체안 준비 보기',
          comparePoints: const ['가격', '용량', '묶음 구성'],
        ),
      ),
      ...repeatCandidates.take(1).map(
        (candidate) => ExploreOfferSignal(
          intentKey: _normalize(candidate.name),
          anchorName: candidate.name,
          anchorPrice: candidate.price,
          sourceType: ExploreOfferSourceType.repeatPurchase,
          sourceLabel: '반복 구매',
          context: '반복 구매 후보 기준',
          ctaLabel: '재구매 대체안 준비 보기',
          comparePoints: const ['재구매 가격', '단가', '후기 품질'],
        ),
      ),
    ];

    return ExploreOfferSlotFactory.build(signals).take(3).toList();
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
                  const Text(
                    '파트너 오퍼 준비 상태',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
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
                        return const _EmptyInfoCard(
                          title: '아직 준비된 오퍼가 없어요',
                          body: '파트너 provider가 연결되면 이 영역에 같은 상품군 대체안이 채워져요.',
                        );
                      }

                      return Column(
                        children: offers
                            .map(
                              (offer) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _AlternativeOfferPreviewCard(offer: offer),
                              ),
                            )
                            .toList(),
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
              _HeroStat(label: '오퍼 슬롯', value: '${revisitCount == 0 && repeatCandidateCount == 0 ? 0 : (revisitCount >= 2 ? 2 : revisitCount) + (repeatCandidateCount > 0 ? 1 : 0)}개'),
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
            child: _SummaryMetric(label: '검토 대기', value: '$recentScanCount건'),
          ),
          Expanded(
            child: _SummaryMetric(label: '재방문 후보', value: '$revisitCount건'),
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
                      '재구매 비교 준비 보기',
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

  const _OfferSlotCard({required this.slot, required this.onTap});

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
                  const _Badge(label: 'Coupang slot', dark: true),
                  const SizedBox(width: 8),
                  _Badge(label: slot.sourceLabel, dark: true),
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
                '${slot.context} 같은 구매 의도의 대체 상품만 노출 예정이에요. 가격, 용량, 묶음 구성을 비교하는 CTA가 여기에 연결됩니다.',
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

class _RevisitItem {
  final String name;
  final int price;
  final String reason;
  final String badge;

  const _RevisitItem({
    required this.name,
    required this.price,
    required this.reason,
    required this.badge,
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
      summary: item.reason,
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
      summary: '저장 카트에 ${candidate.repeatCount}번 등장했어요. 다시 살 가능성이 높은 품목이에요.',
      comparePoints: const [
        '지난 구매 이력 대비 현재 대안 가격 비교',
        '자주 사는 상품의 묶음/대용량 옵션 비교',
        '재구매에 적합한 후기/구성 확인',
      ],
      futureNote: '반복 구매 품목은 재구매 전환이 높아서, 먼저 같은 상품군 대체안부터 붙이는 게 좋아요.',
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
      summary: '${slot.context} 오퍼 슬롯이에요. 아직 외부 링크는 없지만, same-intent 대체안 진입점으로 설계된 상태예요.',
      comparePoints: slot.comparePoints,
      futureNote: '쿠팡 파트너스 연결 시 이 슬롯에서 바로 동일 구매 의도 대체안 상세로 넘어가게 할 수 있어요.',
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
