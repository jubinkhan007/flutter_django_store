import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/return_request_model.dart';


class ReturnDetailScreen extends StatelessWidget {
  final ReturnRequestModel returnRequest;

  const ReturnDetailScreen({super.key, required this.returnRequest});

  @override
  Widget build(BuildContext context) {
    final refund = returnRequest.refunds.isEmpty ? null : returnRequest.refunds.first;

    return Scaffold(
      appBar: AppBar(title: Text(returnRequest.rmaNumber)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ListView(
          children: [
            _kv('Status', returnRequest.status),
            _kv('Type', returnRequest.requestType),
            _kv('Reason', returnRequest.reason),
            if (returnRequest.reasonDetails.isNotEmpty)
              _kv('Reason details', returnRequest.reasonDetails),
            _kv('Fulfillment', returnRequest.fulfillment),
            if (returnRequest.fulfillment == 'PICKUP' &&
                (returnRequest.pickupWindowStart != null ||
                    returnRequest.pickupWindowEnd != null))
              _kv(
                'Pickup window',
                '${returnRequest.pickupWindowStart?.toLocal().toString() ?? '-'} → ${returnRequest.pickupWindowEnd?.toLocal().toString() ?? '-'}',
              ),
            if (returnRequest.fulfillment == 'DROPOFF' &&
                returnRequest.dropoffInstructions.isNotEmpty)
              _kv('Drop-off', returnRequest.dropoffInstructions),
            _kv('Refund preference', returnRequest.refundMethodPreference),
            if (returnRequest.customerNote.isNotEmpty)
              _kv('Your note', returnRequest.customerNote),
            if (returnRequest.vendorNote.isNotEmpty)
              _kv('Vendor note', returnRequest.vendorNote),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Items',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...returnRequest.items.map(
              (it) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${it.productName} × ${it.quantity} (${it.condition})',
                  style: TextStyle(color: AppColors.lightTextSecondary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (refund != null) ...[
              const Text(
                'Refund',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _kv('Status', refund.status),
              _kv('Method', refund.method),
              _kv('Amount', '\$${refund.amount.toStringAsFixed(2)}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              k,
              style: TextStyle(color: AppColors.lightTextSecondary),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(color: AppColors.lightTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
