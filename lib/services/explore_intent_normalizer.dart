class ExploreIntentNormalization {
  final String rawText;
  final String normalizedQueryText;
  final String intentKey;
  final List<String> intentTokens;

  const ExploreIntentNormalization({
    required this.rawText,
    required this.normalizedQueryText,
    required this.intentKey,
    required this.intentTokens,
  });
}

class ExploreIntentNormalizer {
  static const Set<String> _stopTokens = {
    '특가',
    '행사',
    '기획',
    '기획팩',
    '증정',
    '사은품',
    '무료배송',
    '번들',
    'bundle',
    'set',
    'pack',
    '대용량',
    '소용량',
    '정품',
    '국내산',
    '수입산',
    '추천',
    'best',
    'best상품',
    'hot',
  };

  static const Set<String> _unitTokens = {
    'ml',
    'l',
    'g',
    'kg',
    '개',
    '입',
    '팩',
    '봉',
    '병',
    '캔',
    '매',
    '세트',
  };

  static ExploreIntentNormalization normalize(String rawText) {
    final base = rawText
        .toLowerCase()
        .replaceAll('ℓ', 'l')
        .replaceAll(RegExp(r'[^0-9a-z가-힣]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final merged = _mergeUnitTokens(
      base.isEmpty ? const [] : base.split(' '),
    );

    final filtered = merged.where((token) {
      if (token.isEmpty) return false;
      if (_stopTokens.contains(token)) return false;
      return true;
    }).toList(growable: false);

    final normalizedQueryText = filtered.join(' ').trim();
    final intentTokens = filtered.map(_normalizeToken).where((token) => token.isNotEmpty).toList(growable: false);
    final intentKey = intentTokens.join('|');

    return ExploreIntentNormalization(
      rawText: rawText,
      normalizedQueryText: normalizedQueryText.isEmpty ? rawText.trim() : normalizedQueryText,
      intentKey: intentKey.isEmpty ? rawText.trim().toLowerCase() : intentKey,
      intentTokens: intentTokens,
    );
  }

  static List<String> _mergeUnitTokens(List<String> tokens) {
    final merged = <String>[];
    var index = 0;
    while (index < tokens.length) {
      final current = _normalizeToken(tokens[index]);
      if (current.isEmpty) {
        index += 1;
        continue;
      }

      if (index + 1 < tokens.length) {
        final next = _normalizeToken(tokens[index + 1]);
        if (_isNumberToken(current) && _unitTokens.contains(next)) {
          merged.add('$current$next');
          index += 2;
          continue;
        }
      }

      merged.add(current);
      index += 1;
    }
    return merged;
  }

  static bool _isNumberToken(String token) {
    return RegExp(r'^\d+(?:\.\d+)?$').hasMatch(token);
  }

  static String _normalizeToken(String token) {
    return token.trim().toLowerCase();
  }
}
