import 'package:flutter_test/flutter_test.dart';
import 'package:wimc/widgets/scan_ui_helpers.dart';

void main() {
  group('scan_ui_helpers', () {
    test('fmtScanPrice formats thousands separators', () {
      expect(fmtScanPrice(12345), '12,345');
    });

    test('scanReviewMessage returns fallback copy by confidence range', () {
      expect(scanReviewMessage(null), '상품명과 가격만 확인해 주세요.');
      expect(scanReviewMessage(0.9), '결과만 빠르게 확인하고 담아주세요.');
      expect(scanReviewMessage(0.7), '한 번 확인하고 담아주세요.');
      expect(scanReviewMessage(0.4), '정확하지 않으면 수정하거나 다시 찍어주세요.');
    });

    test('scanConfidenceLabel returns fallback copy by confidence range', () {
      expect(scanConfidenceLabel(0.9), '신뢰 높음');
      expect(scanConfidenceLabel(0.7), '확인 권장');
      expect(scanConfidenceLabel(0.4), '확인 필요');
    });
  });
}
