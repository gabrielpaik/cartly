import unittest
from datetime import datetime

from app.db.models import Receipt, ReceiptLineItem
from app.services import receipt_service


class ReceiptServiceHelperTests(unittest.TestCase):
    def test_derive_discount_counts_discount_and_coupon_as_positive_amounts(self):
        line_items = [
            ReceiptLineItem(
                receipt_id='r1',
                raw_name='할인',
                normalized_name='할인',
                quantity=None,
                unit_price=None,
                line_amount=-1500,
                final_amount=None,
                category='discount',
            ),
            ReceiptLineItem(
                receipt_id='r1',
                raw_name='쿠폰',
                normalized_name='쿠폰',
                quantity=None,
                unit_price=None,
                line_amount=0,
                final_amount=-500,
                category='coupon',
            ),
            ReceiptLineItem(
                receipt_id='r1',
                raw_name='상품',
                normalized_name='상품',
                quantity=1,
                unit_price=1000,
                line_amount=1000,
                final_amount=1000,
                category='item',
            ),
        ]

        self.assertEqual(receipt_service._derive_discount(line_items), 2000)

    def test_derive_total_amount_prefers_payment_rows_over_formula(self):
        line_items = [
            ReceiptLineItem(
                receipt_id='r1',
                raw_name='카드결제',
                normalized_name='카드결제',
                quantity=None,
                unit_price=None,
                line_amount=-8700,
                final_amount=None,
                category='payment',
            )
        ]

        total = receipt_service._derive_total_amount(
            subtotal=10000,
            tax=1000,
            discount=500,
            line_items=line_items,
        )

        self.assertEqual(total, 8700)

    def test_serialize_receipt_result_keeps_summary_and_line_items_shape(self):
        receipt = Receipt(
            id='receipt-1',
            user_id='user-1',
            saved_cart_id='cart-1',
            status='ready',
            image_path='/tmp/receipt.jpg',
            merchant_name='Cartly Mart',
            purchased_at=datetime(2026, 4, 23, 12, 30, 0),
            currency='KRW',
            subtotal=10000,
            tax=1000,
            total_amount=9500,
            total_discount_amount=1500,
            raw_text='raw text',
            error_message=None,
            created_at=datetime(2026, 4, 23, 12, 31, 0),
            updated_at=datetime(2026, 4, 23, 12, 32, 0),
        )
        receipt.line_items = [
            ReceiptLineItem(
                id='line-1',
                receipt_id='receipt-1',
                raw_name='사과',
                normalized_name='사과',
                quantity=2,
                unit_price=1500,
                line_amount=3000,
                final_amount=3000,
                category='item',
                confidence=0.91,
            )
        ]

        payload = receipt_service.serialize_receipt_result(receipt)

        self.assertEqual(payload['receipt']['id'], 'receipt-1')
        self.assertEqual(payload['receipt']['merchantName'], 'Cartly Mart')
        self.assertEqual(payload['lineItems'][0]['id'], 'line-1')
        self.assertEqual(payload['lineItems'][0]['rawName'], '사과')
        self.assertEqual(payload['lineItems'][0]['finalAmount'], 3000)
        self.assertEqual(payload['lineItems'][0]['confidence'], 0.91)


if __name__ == '__main__':
    unittest.main()
