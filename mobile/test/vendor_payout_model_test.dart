import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/vendor/data/models/vendor_wallet_model.dart';

void main() {
  group('Vendor Payout & Auto-Payout Models', () {
    test('VendorAutoPayoutSettings parses from JSON and serializes to JSON', () {
      final json = {
        'is_auto_payout_enabled': true,
        'auto_payout_schedule': 'BIWEEKLY',
        'auto_payout_threshold': '2500.00',
        'preferred_payout_method': 3,
        'last_payout_at': '2026-11-01T10:00:00Z',
      };

      final settings = VendorAutoPayoutSettings.fromJson(json);

      expect(settings.isEnabled, isTrue);
      expect(settings.schedule, equals('BIWEEKLY'));
      expect(settings.threshold, equals(2500.0));
      expect(settings.preferredMethodId, equals(3));
      expect(settings.lastPayoutAt, equals('2026-11-01T10:00:00Z'));

      final serialized = settings.toJson();
      expect(serialized['is_auto_payout_enabled'], isTrue);
      expect(serialized['auto_payout_schedule'], equals('BIWEEKLY'));
      expect(serialized['auto_payout_threshold'], equals('2500.00'));
      expect(serialized['preferred_payout_method'], equals(3));
    });

    test('VendorPayoutMethodModel parses verification details and converts to bank details text', () {
      final json = {
        'id': 12,
        'method': 'BKASH',
        'label': 'bKash Merchant Account',
        'details': {'phone': '01711223344'},
        'is_verified': true,
        'verified_at': '2026-11-02T12:00:00Z',
        'verification_notes': 'Auto-verified valid Bangladeshi mobile number.',
      };

      final method = VendorPayoutMethodModel.fromJson(json);

      expect(method.id, equals(12));
      expect(method.method, equals('BKASH'));
      expect(method.label, equals('bKash Merchant Account'));
      expect(method.isVerified, isTrue);
      expect(method.verifiedAt, equals('2026-11-02T12:00:00Z'));
      expect(method.verificationNotes, contains('valid Bangladeshi mobile'));
      expect(method.toBankDetailsText(), contains('bKash Merchant Account'));
    });

    test('VendorPayoutRequestModel parses disbursal channel, fee, and automation fields', () {
      final json = {
        'id': 45,
        'amount': '1500.00',
        'status': 'PAID',
        'payout_method': 12,
        'disbursal_channel': 'BKASH',
        'bank_details': 'bKash Merchant: 01711223344',
        'gateway_reference': 'TRX-BKASH-20261105-ABCD',
        'gateway_fee': '22.50',
        'failure_reason': '',
        'is_automated': true,
        'admin_note': 'Disbursed via automated scheduled batch',
        'requested_at': '2026-11-05T08:00:00Z',
        'processed_at': '2026-11-05T08:00:05Z',
      };

      final payout = VendorPayoutRequestModel.fromJson(json);

      expect(payout.id, equals(45));
      expect(payout.amount, equals(1500.0));
      expect(payout.status, equals('PAID'));
      expect(payout.payoutMethodId, equals(12));
      expect(payout.disbursalChannel, equals('BKASH'));
      expect(payout.gatewayReference, equals('TRX-BKASH-20261105-ABCD'));
      expect(payout.gatewayFee, equals(22.50));
      expect(payout.isAutomated, isTrue);
      expect(payout.adminNote, contains('automated scheduled batch'));
    });

    test('VendorWalletSummary parses complete payload including auto_payout and payout_requests', () {
      final json = {
        'balances': {
          'pending': 500.0,
          'available': 3500.0,
          'held': 0.0,
          'debt': 0.0,
          'total': 4000.0,
          'lifetime_earned': 25000.0,
          'lifetime_withdrawn': 21000.0,
          'min_withdrawal': 500.0,
        },
        'auto_payout': {
          'is_auto_payout_enabled': true,
          'auto_payout_schedule': 'WEEKLY',
          'auto_payout_threshold': '1000.00',
          'preferred_payout_method': null,
        },
        'entries': [
          {
            'id': 1,
            'entry_type': 'ORDER_SETTLEMENT',
            'bucket': 'AVAILABLE',
            'direction': 'CREDIT',
            'status': 'POSTED',
            'amount': '1200.00',
            'reference_type': 'ORDER',
            'reference_id': 99,
            'description': 'Order #99 payout',
            'createdAt': '2026-11-05T07:00:00Z',
          }
        ],
        'payout_methods': [
          {
            'id': 1,
            'method': 'NAGAD',
            'label': 'Nagad Personal',
            'details': {'phone': '01811223344'},
            'is_verified': true,
          }
        ],
        'payout_requests': [
          {
            'id': 10,
            'amount': '2000.00',
            'status': 'PAID',
            'disbursal_channel': 'NAGAD',
            'bank_details': 'Nagad: 01811223344',
            'gateway_reference': 'NGD-DISBURSE-20261105-WXYZ',
            'gateway_fee': '30.00',
            'failure_reason': '',
            'is_automated': false,
            'admin_note': '',
            'requested_at': '2026-11-05T06:00:00Z',
          }
        ],
      };

      final summary = VendorWalletSummary.fromJson(json);

      expect(summary.balances.available, equals(3500.0));
      expect(summary.autoPayout, isNotNull);
      expect(summary.autoPayout!.isEnabled, isTrue);
      expect(summary.autoPayout!.schedule, equals('WEEKLY'));
      expect(summary.entries.length, equals(1));
      expect(summary.payoutMethods.length, equals(1));
      expect(summary.payoutMethods[0].method, equals('NAGAD'));
      expect(summary.payoutRequests.length, equals(1));
      expect(summary.payoutRequests[0].gatewayReference, contains('NGD-DISBURSE'));
    });
  });
}
