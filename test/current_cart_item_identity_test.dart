import 'package:cartly/app_support.dart';
import 'package:cartly/models/recognized_item.dart';
import 'package:cartly/pages/home_page_cart_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'home page cart controller assigns stable ids and preserves them on quantity updates',
    () {
      final items = <CartItem>[];
      final recentScans = <RecentScanEntry>[];
      final consideredItems = <ConsideredProductEntry>[];
      final controller = HomePageCartController(
        items: items,
        recentScans: recentScans,
        consideredItems: consideredItems,
        setState: (fn) => fn(),
      );

      final added = controller.addRecognizedItem(
        RecognizedItem(name: 'Milk', price: 2500, scanJobId: 'scan-1'),
      );
      final originalId = added.id;

      final updated = controller.increaseMatchingCartItem(
        added,
        RecognizedItem(name: 'Milk', price: 2500, scanJobId: 'scan-1'),
      );

      expect(items, hasLength(1));
      expect(updated.id, originalId);
      expect(updated.quantity, 2);
    },
  );
}
