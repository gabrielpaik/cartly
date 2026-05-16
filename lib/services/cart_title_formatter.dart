import 'package:intl/intl.dart';

String buildUnifiedCartTitle({
  String? merchantOrBrand,
  String? areaLabel,
  DateTime? date,
  String? fallbackTitle,
  bool appendShoppingForAreaOnly = true,
}) {
  final merchant = _cleanTitleSegment(merchantOrBrand);
  final area = _cleanTitleSegment(areaLabel);
  final effectiveDate = date?.toLocal() ?? DateTime.now();
  final dateText = DateFormat('M월 d일').format(effectiveDate);

  if (merchant != null &&
      merchant.isNotEmpty &&
      area != null &&
      area.isNotEmpty) {
    return '$merchant $area $dateText';
  }
  if (merchant != null && merchant.isNotEmpty) {
    return '$merchant $dateText';
  }
  if (area != null && area.isNotEmpty) {
    return appendShoppingForAreaOnly
        ? '$area 장보기 $dateText'
        : '$area $dateText';
  }
  final safeFallback = normalizeCartTitleForDisplay(fallbackTitle);
  if (safeFallback != null && safeFallback.isNotEmpty) {
    return safeFallback;
  }
  return '$dateText 카트';
}

String? normalizeCartTitleForDisplay(String? rawTitle) {
  final trimmed = rawTitle?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final parts = trimmed
      .split(RegExp(r'\s*·\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.length >= 2 &&
      (_looksLikeCartDate(parts.last) || _looksLikeCartSuffix(parts.last))) {
    return parts.join(' ');
  }

  return trimmed.replaceAll(RegExp(r'\s+'), ' ');
}

String? _cleanTitleSegment(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed.replaceAll(RegExp(r'\s+'), ' ');
}

bool _looksLikeCartDate(String value) {
  return RegExp(r'^\d{1,2}월\s*\d{1,2}일$').hasMatch(value.trim());
}

bool _looksLikeCartSuffix(String value) {
  final trimmed = value.trim();
  return trimmed == '카트' || trimmed == '장보기';
}
