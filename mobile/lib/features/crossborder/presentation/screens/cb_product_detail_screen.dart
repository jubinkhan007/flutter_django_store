import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/cb_models.dart';
import '../providers/crossborder_provider.dart';
import 'cb_checkout_screen.dart';

class CbProductDetailScreen extends StatefulWidget {
  final CrossBorderProduct product;

  const CbProductDetailScreen({super.key, required this.product});

  @override
  State<CbProductDetailScreen> createState() => _CbProductDetailScreenState();
}

class _CbProductDetailScreenState extends State<CbProductDetailScreen> {
  final _variantCtrl = TextEditingController();
  int _quantity = 1;
  String _shippingMethod = 'AIR';
  int _currentImage = 0;

  @override
  void dispose() {
    _variantCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestQuote() async {
    final provider = context.read<CrossBorderProvider>();
    final req = await provider.createRequest(
      productId: widget.product.id,
      marketplace: widget.product.originMarketplace,
      variantNotes: _variantCtrl.text.trim(),
      quantity: _quantity,
      shippingMethod: _shippingMethod,
    );
    if (!mounted) return;
    if (req == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.actionError ?? 'Failed to get quote'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CbCheckoutScreen(request: req),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = p.images.isNotEmpty ? p.images : (p.primaryImage.isNotEmpty ? [p.primaryImage] : <String>[]);

    return Scaffold(
      appBar: AppBar(title: Text(p.title, overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image gallery ──
            if (images.isNotEmpty)
              SizedBox(
                height: 280,
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _currentImage = i),
                      itemBuilder: (context, i) => Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.lightSurface,
                          child: const Icon(Icons.image_not_supported, size: 60, color: AppColors.lightTextSecondary),
                        ),
                      ),
                    ),
                    if (images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _currentImage ? 10 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == _currentImage ? AppColors.lightPrimary : Colors.white54,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Container(
                height: 200,
                color: AppColors.lightSurface,
                child: const Center(child: Icon(Icons.shopping_bag_outlined, size: 60, color: AppColors.lightTextSecondary)),
              ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Marketplace + price ──
                  Row(
                    children: [
                      _Pill(label: p.originMarketplace),
                      const Spacer(),
                      Text(
                        '${p.currency} ${p.basePriceForeign.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.lightPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.leadTimeDaysMin}–${p.leadTimeDaysMax} day delivery estimate',
                    style: const TextStyle(color: AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 12),
                  Text(p.description, style: const TextStyle(fontSize: 14, height: 1.5)),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // ── Variant / notes ──
                  const Text('Variant / Specifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _variantCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'E.g. Color: Red, Size: XL, Model: 2024',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Quantity ──
                  Row(
                    children: [
                      const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      _QuantitySelector(
                        value: _quantity,
                        onChanged: (v) => setState(() => _quantity = v),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Shipping method ──
                  const Text('Shipping Method', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ShippingChip(
                        label: 'Air (Faster)',
                        icon: Icons.flight,
                        selected: _shippingMethod == 'AIR',
                        onTap: () => setState(() => _shippingMethod = 'AIR'),
                      ),
                      const SizedBox(width: 10),
                      _ShippingChip(
                        label: 'Sea (Cheaper)',
                        icon: Icons.directions_boat,
                        selected: _shippingMethod == 'SEA',
                        onTap: () => setState(() => _shippingMethod = 'SEA'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Policy summary ──
                  if (p.policySummary.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning.withAlpha(60)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.policySummary,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Consumer<CrossBorderProvider>(
            builder: (context, provider, _) => FilledButton.icon(
              onPressed: provider.actionLoading ? null : _requestQuote,
              icon: provider.actionLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.calculate_outlined),
              label: Text(provider.actionLoading ? 'Getting quote...' : 'Get Quote & Checkout'),
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

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightPrimary.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.lightPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _QuantitySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        IconButton(
          onPressed: value < 20 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _ShippingChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ShippingChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightPrimary : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.lightPrimary : AppColors.lightTextSecondary.withAlpha(60),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : AppColors.lightTextSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
