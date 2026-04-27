import 'dart:convert';
import 'dart:io';

import '../config/explore_partner_config.dart';
import '../models/explore_offer.dart';
import 'api_base.dart';
import 'explore_intent_normalizer.dart';

abstract class ExploreOfferProvider {
  const ExploreOfferProvider();

  Future<List<ExploreAlternativeOffer>> fetchOffers(ExploreOfferQuery query);
}

ExploreAlternativeOffer _mergeQueryMetaIntoOffer(
  ExploreAlternativeOffer offer,
  Map<String, dynamic>? queryMeta,
) {
  if (queryMeta == null) return offer;

  final normalizedQueryText = (queryMeta['normalizedQueryText'] as String?)
      ?.trim();
  final intentTokens = (queryMeta['intentTokens'] as List?)
      ?.map((item) => item?.toString().trim())
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList();

  final nextHighlights = [...offer.highlights];
  final normalizedHighlight = normalizedQueryText != null && normalizedQueryText.isNotEmpty
      ? '정규화 쿼리: $normalizedQueryText'
      : null;
  final tokenHighlight = intentTokens != null && intentTokens.isNotEmpty
      ? '의도 토큰: ${intentTokens.join(', ')}'
      : null;

  if (normalizedHighlight != null && !nextHighlights.contains(normalizedHighlight)) {
    nextHighlights.add(normalizedHighlight);
  }
  if (tokenHighlight != null && !nextHighlights.contains(tokenHighlight)) {
    nextHighlights.add(tokenHighlight);
  }

  if (nextHighlights.length == offer.highlights.length) {
    return offer;
  }

  return offer.copyWith(highlights: nextHighlights);
}

class CoupangPartnersBridgeUrlBuilder {
  final ExplorePartnerConfig config;

  const CoupangPartnersBridgeUrlBuilder({
    this.config = ExplorePartnerConfig.current,
  });

  String get _baseUrl => config.normalizedBridgeBaseUrl ?? getCartlyApiBaseUrl();

  Uri buildPreviewUri(ExploreOfferQuery query) {
    return Uri.parse('$_baseUrl/v1/explore/offers/coupang-partners').replace(
      queryParameters: query.toQueryParameters(),
    );
  }

  Uri buildFallbackSearchUri(ExploreOfferQuery query) {
    return Uri.https('www.coupang.com', '/np/search', {'q': query.queryText});
  }

  Uri buildBridgeUri(ExploreOfferQuery query) {
    return Uri.parse('$_baseUrl/v1/explore/offers/coupang-partners/deeplink').replace(
      queryParameters: query.toQueryParameters(),
    );
  }

  String resolveBridgeUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return parsed.toString();
    }
    return Uri.parse('$_baseUrl$trimmed').toString();
  }
}

class PendingCoupangPartnersOfferProvider extends ExploreOfferProvider {
  final ExplorePartnerConfig config;
  final CoupangPartnersBridgeUrlBuilder urlBuilder;

  const PendingCoupangPartnersOfferProvider({
    this.config = ExplorePartnerConfig.current,
    this.urlBuilder = const CoupangPartnersBridgeUrlBuilder(),
  });

  @override
  Future<List<ExploreAlternativeOffer>> fetchOffers(ExploreOfferQuery query) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(urlBuilder.buildPreviewUri(query));
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      client.close(force: true);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        final offersJson = (data?['offers'] as List?) ?? const [];
        final queryMeta = data?['query'] as Map<String, dynamic>?;
        final offers = offersJson
            .whereType<Map>()
            .map(
              (item) => ExploreAlternativeOffer.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .map(
              (offer) => offer.deeplinkUrl == null || offer.deeplinkUrl!.trim().isEmpty
                  ? offer
                  : offer.copyWith(
                      deeplinkUrl: urlBuilder.resolveBridgeUrl(offer.deeplinkUrl!),
                    ),
            )
            .map((offer) => _mergeQueryMetaIntoOffer(offer, queryMeta))
            .toList();
        if (offers.isNotEmpty) {
          return offers;
        }
      }
    } catch (_) {
      // fall back to local preview below
    }

    final normalized = ExploreIntentNormalizer.normalize(query.queryText);

    return [
      ExploreAlternativeOffer(
        provider: 'coupang-partners',
        title: '${normalized.normalizedQueryText} same-intent 오퍼 준비 중',
        subtitle: config.coupangPartnersEnabled
            ? '클라이언트 구조는 준비됐고, 다음엔 서버에서 파트너 딥링크를 발급하면 돼요.'
            : '파트너 기능은 아직 비활성 상태예요. 구조만 먼저 붙여둔 단계예요.',
        deeplinkUrl: config.coupangPartnersEnabled
            ? urlBuilder.buildBridgeUri(query).toString()
            : null,
        highlights: [
          if (query.referencePrice != null)
            '기준 가격 ₩${query.referencePrice}',
          '비교 쿼리: ${normalized.normalizedQueryText}',
          '다음 단계: 서버에서 쿠팡 파트너스 딥링크 연결',
        ],
      ),
      ExploreAlternativeOffer(
        provider: 'coupang-search-preview',
        title: '쿠팡 검색어 프리뷰',
        subtitle: normalized.normalizedQueryText,
        deeplinkUrl: urlBuilder.buildFallbackSearchUri(query).toString(),
        highlights: const [
          '비제휴 검색 프리뷰 URL',
          '실제 파트너 전환 전 쿼리 검증용',
        ],
      ),
    ];
  }
}

class ExploreOfferSlotFactory {
  const ExploreOfferSlotFactory._();

  static List<ExploreOfferSlot> build(
    Iterable<ExploreOfferSignal> signals,
  ) {
    final deduped = <String>{};
    final slots = <ExploreOfferSlot>[];

    for (final signal in signals) {
      if (!deduped.add(signal.intentKey)) continue;
      slots.add(
        ExploreOfferSlot(
          intentKey: signal.intentKey,
          anchorName: signal.anchorName,
          anchorPrice: signal.anchorPrice,
          sourceType: signal.sourceType,
          sourceLabel: signal.sourceLabel,
          context: signal.context,
          ctaLabel: signal.ctaLabel,
          comparePoints: List.unmodifiable(signal.comparePoints),
          query: ExploreOfferQuery(
            intentKey: signal.intentKey,
            queryText: ExploreIntentNormalizer
                .normalize(signal.anchorName)
                .normalizedQueryText,
            sourceType: signal.sourceType,
            referencePrice: signal.anchorPrice,
          ),
        ),
      );
    }

    return List.unmodifiable(slots);
  }
}
