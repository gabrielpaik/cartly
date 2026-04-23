import 'package:flutter_test/flutter_test.dart';
import 'package:wimc/models/saved_cart.dart';
import 'package:wimc/pages/cart_detail_page_helpers.dart';

void main() {
  group('cart_detail_page_helpers', () {
    test('cloneSavedCartSnapshot deep copies items and receipt status', () {
      final source = SavedCart(
        id: 'cart-1',
        title: '장보기',
        createdAt: DateTime(2026, 4, 23),
        items: [
          SavedCartItem(name: '사과', price: 1000, quantity: 2),
        ],
        receiptStatus: SavedCartReceiptStatus(
          receiptId: 'receipt-1',
          receiptStatus: 'ready',
          merchantName: 'Cartly Mart',
          hasReceipt: true,
          updatedAt: DateTime(2026, 4, 23, 12),
          completedAt: DateTime(2026, 4, 23, 12, 5),
        ),
      );

      final cloned = cloneSavedCartSnapshot(source);
      cloned.items.first.name = '배';

      expect(source.items.first.name, '사과');
      expect(cloned.items.first.name, '배');
      expect(identical(source.items.first, cloned.items.first), isFalse);
      expect(identical(source.receiptStatus, cloned.receiptStatus), isFalse);
      expect(cloned.receiptStatus?.receiptId, 'receipt-1');
    });

    test('cartDetailInlineEditValidationMessage rejects empty name or invalid price', () {
      expect(
        cartDetailInlineEditValidationMessage(nameText: '  ', priceText: '1000'),
        '상품명/가격을 확인해주세요',
      );
      expect(
        cartDetailInlineEditValidationMessage(nameText: '사과', priceText: '0'),
        '상품명/가격을 확인해주세요',
      );
      expect(
        cartDetailInlineEditValidationMessage(nameText: '사과', priceText: '1,200'),
        isNull,
      );
    });

    test('cartDetailSaveValidationMessage trims names and rejects invalid rows', () {
      final items = [
        SavedCartItem(name: '  사과  ', price: 1000, quantity: 2),
        SavedCartItem(name: '', price: 500, quantity: 1),
      ];

      final message = cartDetailSaveValidationMessage(items);

      expect(message, '상품명이 비어있어요');
      expect(items.first.name, '사과');
    });
  });
}
