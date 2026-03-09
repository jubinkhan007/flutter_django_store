import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../addresses/data/models/address_model.dart';
import '../../../addresses/presentation/providers/address_provider.dart';
import '../../data/models/cb_models.dart';
import '../providers/crossborder_provider.dart';
import 'cb_order_tracking_screen.dart';

class CbCheckoutScreen extends StatefulWidget {
  final CrossBorderOrderRequest request;

  const CbCheckoutScreen({super.key, required this.request});

  @override
  State<CbCheckoutScreen> createState() => _CbCheckoutScreenState();
}

class _CbCheckoutScreenState extends State<CbCheckoutScreen> {
  AddressModel? _selectedAddress;
  bool _customsAcknowledged = false;
  bool _termsAcknowledged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final addrProvider = context.read<AddressProvider>();
      if (addrProvider.addresses.isEmpty) {
        addrProvider.loadAddresses().then((_) {
          if (mounted)
            setState(() => _selectedAddress = addrProvider.defaultAddress);
        });
      } else {
        setState(() => _selectedAddress = addrProvider.defaultAddress);
      }
    });
  }

  Future<void> _confirm() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a delivery address'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!_customsAcknowledged || !_termsAcknowledged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please acknowledge all required disclosures'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final provider = context.read<CrossBorderProvider>();
    final confirmed = await provider.checkout(
      requestId: widget.request.id,
      addressId: _selectedAddress!.id,
      customsPolicyAcknowledged: true,
    );
    if (!mounted) return;
    if (confirmed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.actionError ?? 'Checkout failed'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    // Replace the whole stack up to this screen with tracking
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CbOrderTrackingScreen(requestId: confirmed.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final breakdown = req.costBreakdown;
    final isQuoteValid = req.isQuoteValid;
    final missingLinkPrice =
        req.requestType == 'LINK_PURCHASE' &&
        (breakdown?.itemPriceForeign ?? 0) <= 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Review & Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (missingLinkPrice)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withAlpha(80)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Item price is missing for this Buy by Link request. Please go back and enter an estimated item price to get an accurate quote.',
                    ),
                  ),
                ],
              ),
            ),
          // ── Quote validity warning ──
          if (!isQuoteValid)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withAlpha(60)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This quote has expired. Please go back and request a new quote.',
                    ),
                  ),
                ],
              ),
            ),

          // ── Order summary ──
          _SectionCard(
            title: 'Order Summary',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${req.quantity}  ·  ${req.shippingMethod} Shipping',
                  style: const TextStyle(
                    color: AppColors.lightTextSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Marketplace: ${req.marketplace}',
                  style: const TextStyle(
                    color: AppColors.lightTextSecondary,
                    fontSize: 13,
                  ),
                ),
                if (req.quoteExpiresAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Quote valid until: ${req.quoteExpiresAt}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Cost breakdown ──
          if (breakdown != null)
            _SectionCard(
              title: 'Cost Breakdown',
              child: Column(
                children: [
                  _CostRow(
                    'Item Price',
                    '${breakdown.currency} ${breakdown.itemPriceForeign.toStringAsFixed(2)}',
                  ),
                  _CostRow(
                    'Item Price (BDT)',
                    '৳${breakdown.itemPriceBdt.toStringAsFixed(0)}',
                  ),
                  _CostRow(
                    'International Shipping',
                    '৳${breakdown.intlShippingBdt.toStringAsFixed(0)}',
                  ),
                  _CostRow(
                    'Service Fee',
                    '৳${breakdown.serviceFeeBdt.toStringAsFixed(0)}',
                  ),
                  _CostRow(
                    'Customs (estimate only)',
                    '৳${breakdown.customsEstBdt.toStringAsFixed(0)}',
                    note: 'Paid directly to courier on delivery',
                    noteColor: AppColors.warning,
                  ),
                  const Divider(height: 16),
                  _CostRow(
                    'Total Charged Now',
                    '৳${breakdown.totalBdt.toStringAsFixed(0)}',
                    bold: true,
                    primary: true,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // ── Delivery address ──
          _SectionCard(
            title: 'Delivery Address',
            child: Consumer<AddressProvider>(
              builder: (context, addrProvider, _) {
                if (addrProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final addresses = addrProvider.addresses;
                if (addresses.isEmpty) {
                  return const Text(
                    'No addresses found. Please add one in your profile.',
                    style: TextStyle(color: AppColors.lightTextSecondary),
                  );
                }
                return Column(
                  children: addresses.map((addr) {
                    final selected = _selectedAddress?.id == addr.id;
                    return RadioListTile<int>(
                      value: addr.id,
                      groupValue: _selectedAddress?.id,
                      onChanged: (_) => setState(() => _selectedAddress = addr),
                      dense: true,
                      title: Text('${addr.label} — ${addr.addressLine}'),
                      subtitle: Text(
                        '${addr.area}, ${addr.city}  ${addr.phoneNumber}',
                      ),
                      selected: selected,
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // ── Delivery estimate ──
          _SectionCard(
            title: 'Delivery Estimate',
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.lightPrimary,
                ),
                const SizedBox(width: 10),
                Text(
                  '${req.expectedDeliveryDaysMin}–${req.expectedDeliveryDaysMax} business days after order confirmation',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Disclosures ──
          const Text(
            'Disclosures',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),

          _DisclosureCheckbox(
            value: _customsAcknowledged,
            onChanged: (v) => setState(() => _customsAcknowledged = v ?? false),
            text:
                'I understand that customs/import duties are NOT included in the total above. '
                'I agree to pay any applicable customs fees directly to the courier upon delivery.',
          ),
          const SizedBox(height: 8),
          _DisclosureCheckbox(
            value: _termsAcknowledged,
            onChanged: (v) => setState(() => _termsAcknowledged = v ?? false),
            text:
                'I understand that this is a purchase-on-behalf service. '
                'Returns and refunds are subject to the original marketplace\'s policy and may not be guaranteed.',
          ),

          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Consumer<CrossBorderProvider>(
            builder: (context, provider, _) => FilledButton.icon(
              onPressed:
                  (!isQuoteValid || missingLinkPrice || provider.actionLoading)
                  ? null
                  : _confirm,
              icon: provider.actionLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                provider.actionLoading
                    ? 'Processing...'
                    : breakdown != null
                    ? 'Confirm & Pay  ৳${breakdown.totalBdt.toStringAsFixed(0)}'
                    : 'Confirm Order',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightTextSecondary.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool primary;
  final String? note;
  final Color? noteColor;
  const _CostRow(
    this.label,
    this.value, {
    this.bold = false,
    this.primary = false,
    this.note,
    this.noteColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                  color: primary ? AppColors.lightPrimary : null,
                  fontSize: bold ? 15 : 14,
                ),
              ),
            ],
          ),
          if (note != null)
            Text(
              note!,
              style: TextStyle(
                fontSize: 11,
                color: noteColor ?? AppColors.lightTextSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _DisclosureCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String text;
  const _DisclosureCheckbox({
    required this.value,
    required this.onChanged,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value
              ? AppColors.lightPrimary.withAlpha(80)
              : AppColors.lightTextSecondary.withAlpha(40),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(value: value, onChanged: onChanged),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
