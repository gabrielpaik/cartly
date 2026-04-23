import 'package:intl/intl.dart';

import '../services/app_runtime_copy.dart';

final _scanPriceFormatter = NumberFormat('#,###');

String fmtScanPrice(int value) => _scanPriceFormatter.format(value);

String scanText(String key, String fallback) =>
    AppRuntimeCopy.text(['scan', key], fallback);

String scanNestedText(String group, String key, String fallback) =>
    AppRuntimeCopy.text(['scan', group, key], fallback);

String scanReviewMessage(double? confidence) {
  if (confidence == null) {
    return scanNestedText('review', 'default', '상품명과 가격만 확인해 주세요.');
  }
  if (confidence >= 0.85) {
    return scanNestedText('review', 'high', '결과만 빠르게 확인하고 담아주세요.');
  }
  if (confidence >= 0.65) {
    return scanNestedText('review', 'medium', '한 번 확인하고 담아주세요.');
  }
  return scanNestedText('review', 'low', '정확하지 않으면 수정하거나 다시 찍어주세요.');
}

String scanConfidenceLabel(double confidence) {
  if (confidence >= 0.85) {
    return scanNestedText('confidence', 'high', '신뢰 높음');
  }
  if (confidence >= 0.65) {
    return scanNestedText('confidence', 'medium', '확인 권장');
  }
  return scanNestedText('confidence', 'low', '확인 필요');
}
