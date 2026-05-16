import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../app_support.dart';
import 'cart_title_formatter.dart';

class CartTitleSuggestion {
  final String suggestedTitle;
  final String? subtitle;

  const CartTitleSuggestion({required this.suggestedTitle, this.subtitle});
}

class CartTitleSuggester {
  const CartTitleSuggester._();

  static Future<CartTitleSuggestion> suggest(List<CartItem> items) async {
    final now = DateTime.now();
    final brand = _inferMartBrand(items);
    String? areaLabel;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever &&
            permission != LocationPermission.unableToDetermine) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          ).timeout(const Duration(seconds: 4));

          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          ).timeout(const Duration(seconds: 4));

          if (placemarks.isNotEmpty) {
            areaLabel = _bestAreaLabel(placemarks.first);
          }
        }
      }
    } catch (_) {
      // 위치 기반 추천은 best-effort. 실패하면 날짜 fallback.
    }

    final title = _buildTitle(brand: brand, areaLabel: areaLabel, now: now);
    final subtitle = _buildSubtitle(brand: brand, areaLabel: areaLabel);

    return CartTitleSuggestion(suggestedTitle: title, subtitle: subtitle);
  }

  static String _buildTitle({
    required String? brand,
    required String? areaLabel,
    required DateTime now,
  }) {
    return buildUnifiedCartTitle(
      merchantOrBrand: brand,
      areaLabel: areaLabel,
      date: now,
      appendShoppingForAreaOnly: true,
    );
  }

  static String? _buildSubtitle({
    required String? brand,
    required String? areaLabel,
  }) {
    if (brand != null && areaLabel != null) {
      return '상품명과 현재 위치를 기준으로 $brand, $areaLabel 근처로 추정했어요.';
    }
    if (brand != null) {
      return '상품명 기준으로 $brand 장보기로 보여요.';
    }
    if (areaLabel != null) {
      return '현재 위치 기준으로 $areaLabel 근처 장보기로 이름을 제안했어요.';
    }
    return '위치나 브랜드 힌트를 찾지 못해서 날짜 기준 이름으로 제안했어요.';
  }

  static String? _inferMartBrand(List<CartItem> items) {
    final joined = items.map((item) => item.name.toLowerCase()).join(' ');

    const patterns = <String, List<String>>{
      '코스트코': ['kirkland', '커클랜드', 'costco', '코스트코'],
      '노브랜드': ['no brand', 'nobrand', '노브랜드'],
      '이마트 트레이더스': ['traders', '트레이더스'],
      '이마트': ['peacock', '피코크', 'e-mart', 'emart', '이마트'],
      '홈플러스': ['homeplus', '홈플러스'],
      '롯데마트': ['lotte mart', '롯데마트'],
    };

    for (final entry in patterns.entries) {
      for (final keyword in entry.value) {
        if (joined.contains(keyword)) return entry.key;
      }
    }
    return null;
  }

  static String? _bestAreaLabel(Placemark placemark) {
    final candidates = [
      placemark.subLocality,
      placemark.locality,
      placemark.subAdministrativeArea,
      placemark.administrativeArea,
    ];

    for (final value in candidates) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}
