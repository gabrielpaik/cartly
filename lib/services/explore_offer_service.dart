import 'dart:convert';
import 'dart:io';

import '../config/explore_partner_config.dart';
import '../models/explore_offer.dart';
import 'api_base.dart';
import 'auth_store.dart';
import 'explore_intent_normalizer.dart';

abstract class ExploreOfferProvider {
  const ExploreOfferProvider();

  Future<ExploreOfferResult> fetchOffers(ExploreOfferQuery query);
}

ExploreAlternativeOffer _mergeQueryMetaIntoOffer(
  ExploreAlternativeOffer offer,
  Map<String, dynamic>? queryMeta,
) {
  final referencePriceRaw = queryMeta?['referencePrice'];
  final referencePrice = referencePriceRaw is int
      ? referencePriceRaw
      : referencePriceRaw is num
      ? referencePriceRaw.toInt()
      : int.tryParse('$referencePriceRaw');

  final highlights = <String>[...offer.highlights];
  if (referencePrice != null && offer.price != null) {
    final priceHighlight = _referencePriceHighlight(
      referencePrice,
      offer.price!,
    );
    if (!highlights.contains(priceHighlight)) {
      highlights.add(priceHighlight);
    }
  }

  return offer.copyWith(highlights: highlights.toSet().toList(growable: false));
}

String _referencePriceHighlight(int referencePrice, int offerPrice) {
  final diff = offerPrice - referencePrice;
  if (diff == 0) return '기준 가격과 같아요';
  final absDiff = diff.abs();
  return diff > 0 ? '기준가 대비 $absDiff원 비싸요' : '기준가 대비 $absDiff원 저렴해요';
}

ExploreOfferPresentationMode _presentationModeFromValue(String? rawValue) {
  switch ((rawValue ?? '').trim()) {
    case 'show_offers':
      return ExploreOfferPresentationMode.showOffers;
    case 'generic_hint':
      return ExploreOfferPresentationMode.genericHint;
    default:
      return ExploreOfferPresentationMode.none;
  }
}

class ExploreApiUrlBuilder {
  final ExplorePartnerConfig config;

  const ExploreApiUrlBuilder({this.config = ExplorePartnerConfig.current});

  String get _baseUrl =>
      config.normalizedBridgeBaseUrl ?? getCartlyApiBaseUrl();

  Uri buildNaverShoppingUri(ExploreOfferQuery query) {
    return Uri.parse(
      '$_baseUrl/v1/explore/offers/naver-shopping',
    ).replace(queryParameters: query.toQueryParameters());
  }

  Uri buildCoupangPreviewUri(ExploreOfferQuery query) {
    return Uri.parse(
      '$_baseUrl/v1/explore/offers/coupang-partners',
    ).replace(queryParameters: query.toQueryParameters());
  }

  Uri buildCoupangBridgeUri(ExploreOfferQuery query) {
    return Uri.parse(
      '$_baseUrl/v1/explore/offers/coupang-partners/deeplink',
    ).replace(queryParameters: query.toQueryParameters());
  }

  String resolveUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      return parsed.toString();
    }
    return Uri.parse('$_baseUrl$trimmed').toString();
  }
}

class NaverShoppingOfferProvider extends ExploreOfferProvider {
  final ExploreApiUrlBuilder urlBuilder;

  const NaverShoppingOfferProvider({
    this.urlBuilder = const ExploreApiUrlBuilder(),
  });

  @override
  Future<ExploreOfferResult> fetchOffers(ExploreOfferQuery query) async {
    return _fetchRemoteOffers(
      urlBuilder.buildNaverShoppingUri(query),
      urlBuilder: urlBuilder,
    );
  }
}

class PendingCoupangPartnersOfferProvider extends ExploreOfferProvider {
  final ExploreApiUrlBuilder urlBuilder;

  const PendingCoupangPartnersOfferProvider({
    this.urlBuilder = const ExploreApiUrlBuilder(),
  });

  @override
  Future<ExploreOfferResult> fetchOffers(ExploreOfferQuery query) async {
    return _fetchRemoteOffers(
      urlBuilder.buildCoupangPreviewUri(query),
      urlBuilder: urlBuilder,
    );
  }
}

class HybridExploreOfferProvider extends ExploreOfferProvider {
  final ExploreOfferProvider primary;

  const HybridExploreOfferProvider({
    this.primary = const NaverShoppingOfferProvider(),
  });

  @override
  Future<ExploreOfferResult> fetchOffers(ExploreOfferQuery query) async {
    try {
      return await primary.fetchOffers(query);
    } catch (_) {
      return const ExploreOfferResult.none();
    }
  }
}

Future<ExploreOfferResult> _fetchRemoteOffers(
  Uri uri, {
  required ExploreApiUrlBuilder urlBuilder,
}) async {
  HttpClient? client;
  try {
    client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    final session =
        AuthStore.instance.session.value ??
        await AuthStore.instance.ensureGuestSession();
    final authToken = session?.authToken.trim() ?? '';

    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (authToken.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    }

    final res = await req.close();
    final body = await utf8.decodeStream(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return const ExploreOfferResult.none();
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    final offersJson = (data?['offers'] as List?) ?? const [];
    final queryMeta = data?['query'] as Map<String, dynamic>?;
    final presentation = data?['presentation'] as Map<String, dynamic>?;

    final offers = offersJson
        .whereType<Map>()
        .map(
          (item) =>
              ExploreAlternativeOffer.fromJson(Map<String, dynamic>.from(item)),
        )
        .map(
          (offer) =>
              offer.deeplinkUrl == null || offer.deeplinkUrl!.trim().isEmpty
              ? offer
              : offer.copyWith(
                  deeplinkUrl: urlBuilder.resolveUrl(offer.deeplinkUrl!),
                ),
        )
        .map((offer) => _mergeQueryMetaIntoOffer(offer, queryMeta))
        .toList(growable: false);

    final mode = _presentationModeFromValue(
      (presentation?['mode'] as String?)?.trim(),
    );
    final genericMessage = (presentation?['genericMessage'] as String?)?.trim();

    return ExploreOfferResult(
      mode: mode,
      offers: mode == ExploreOfferPresentationMode.showOffers
          ? offers
          : const [],
      genericMessage: genericMessage,
    );
  } catch (_) {
    return const ExploreOfferResult.none();
  } finally {
    client?.close(force: true);
  }
}

class ExploreOfferSlotFactory {
  const ExploreOfferSlotFactory._();

  static List<ExploreOfferSlot> build(Iterable<ExploreOfferSignal> signals) {
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
            queryText: ExploreIntentNormalizer.normalize(
              signal.anchorName,
            ).normalizedQueryText,
            sourceType: signal.sourceType,
            referencePrice: signal.anchorPrice,
          ),
        ),
      );
    }

    return List.unmodifiable(slots);
  }
}
