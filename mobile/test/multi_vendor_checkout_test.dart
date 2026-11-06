import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/orders/data/models/checkout_quote_model.dart';

void main() {
  group('MultiVendorCheckoutQuote', () {
    test('parses vendor packages and computes multi-vendor status correctly', () {
      final json = {
        'subtotal': '2500.00',
        'discount': '300.00',
        'shipping': '120.00',
        'tax': '0.00',
        'total': '2320.00',
        'coupon_label': 'MEGASALE',
        'user_wallet_balance': '500.00',
        'wallet_amount_applied': '500.00',
        'payable_amount': '1820.00',
        'is_fully_covered_by_wallet': false,
        'loyalty_points_redeemed': 100,
        'loyalty_discount': '10.00',
        'items': [
          {
            'product_id': 101,
            'product_name': 'Nike Shoes',
            'unit_price': '1500.00',
            'quantity': 1,
            'line_total': '1500.00',
          },
          {
            'product_id': 202,
            'product_name': 'Denim Jacket',
            'unit_price': '1000.00',
            'quantity': 1,
            'line_total': '1000.00',
          },
        ],
        'stock_warnings': [],
        'vendor_packages': [
          {
            'vendor_id': 1,
            'store_name': 'Footwear Outlet',
            'items_count': 1,
            'subtotal': '1500.00',
            'coupon_discount': '180.00',
            'loyalty_discount': '6.00',
            'shipping_fee': '60.00',
            'total': '1374.00',
            'items': [
              {
                'product_id': 101,
                'product_name': 'Nike Shoes',
                'unit_price': '1500.00',
                'quantity': 1,
                'line_total': '1500.00',
              }
            ],
          },
          {
            'vendor_id': 2,
            'store_name': 'Apparel Hub',
            'items_count': 1,
            'subtotal': '1000.00',
            'coupon_discount': '120.00',
            'loyalty_discount': '4.00',
            'shipping_fee': '60.00',
            'total': '936.00',
            'items': [
              {
                'product_id': 202,
                'product_name': 'Denim Jacket',
                'unit_price': '1000.00',
                'quantity': 1,
                'line_total': '1000.00',
              }
            ],
          },
        ],
      };

      final quote = CheckoutQuote.fromJson(json);

      expect(quote.isMultiVendor, isTrue);
      expect(quote.vendorPackages.length, equals(2));
      expect(quote.vendorPackages[0].storeName, equals('Footwear Outlet'));
      expect(quote.vendorPackages[0].total, equals(1374.00));
      expect(quote.vendorPackages[0].couponDiscount, equals(180.00));
      expect(quote.vendorPackages[1].storeName, equals('Apparel Hub'));
      expect(quote.vendorPackages[1].total, equals(936.00));
      expect(quote.vendorPackages[1].couponDiscount, equals(120.00));
      expect(quote.payableAmount, equals(1820.00));
      expect(quote.walletAmountApplied, equals(500.00));
    });
  });
}
