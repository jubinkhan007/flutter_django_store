import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/cb_models.dart';
import '../providers/crossborder_provider.dart';
import 'cb_checkout_screen.dart';

const _marketplaces = ['AMAZON', 'ALIEXPRESS', 'ALIBABA', '1688', 'OTHER'];

class CbBuyByLinkScreen extends StatefulWidget {
  const CbBuyByLinkScreen({super.key});

  @override
  State<CbBuyByLinkScreen> createState() => _CbBuyByLinkScreenState();
}

class _CbBuyByLinkScreenState extends State<CbBuyByLinkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController();
  final _variantCtrl = TextEditingController();
  String _marketplace = 'AMAZON';
  int _quantity = 1;
  String _shippingMethod = 'AIR';

  @override
  void dispose() {
    _urlCtrl.dispose();
    _variantCtrl.dispose();
    super.dispose();
  }

  String _detectMarketplace(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('amazon')) return 'AMAZON';
    if (lower.contains('aliexpress')) return 'ALIEXPRESS';
    if (lower.contains('alibaba')) return 'ALIBABA';
    if (lower.contains('1688')) return '1688';
    return 'OTHER';
  }

  Future<void> _fetchPreview() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid product URL first')),
      );
      return;
    }
    setState(() => _marketplace = _detectMarketplace(url));
    final provider = context.read<CrossBorderProvider>();
    final preview = await provider.fetchLinkPreview(url);
    if (mounted && preview != null && _marketplaces.contains(preview.marketplace)) {
      setState(() => _marketplace = preview.marketplace);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<CrossBorderProvider>();
    final preview = provider.linkPreview;

    final req = await provider.createRequest(
      sourceUrl: _urlCtrl.text.trim(),
      marketplace: _marketplace,
      variantNotes: _variantCtrl.text.trim(),
      quantity: _quantity,
      shippingMethod: _shippingMethod,
      itemPriceForeign: (preview != null && preview.hasPrice)
          ? double.tryParse(preview.priceText.replaceAll(RegExp(r'[^\d.]'), ''))
          : null,
      currency: preview?.currency,
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CbCheckoutScreen(request: req)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy by Link')),
      body: Consumer<CrossBorderProvider>(
        builder: (context, provider, _) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // ── Info banner ──
                _InfoBanner(
                  text: 'Paste the product URL from Amazon, AliExpress, Alibaba, or any '
                      'international marketplace. Tap "Preview" to fetch product details, '
                      'then Get Quote.',
                ),
                const SizedBox(height: 16),

                // ── URL field + Preview button ──
                const Text('Product URL', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _urlCtrl,
                        keyboardType: TextInputType.url,
                        onChanged: (_) {
                          if (provider.linkPreview != null) {
                            provider.clearLinkPreview();
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: 'https://www.amazon.com/dp/...',
                          prefixIcon: Icon(Icons.link),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter a product URL';
                          if (!v.trim().startsWith('http')) return 'Enter a valid URL starting with http';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: provider.previewLoading ? null : _fetchPreview,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: provider.previewLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Preview'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Preview area ──
                if (provider.previewLoading)
                  const _PreviewSkeleton()
                else if (provider.previewError != null)
                  _PreviewError(message: provider.previewError!)
                else if (provider.linkPreview != null)
                  _ProductPreviewCard(preview: provider.linkPreview!),

                const SizedBox(height: 16),

                // ── Marketplace ──
                const Text('Marketplace', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _marketplace,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: _marketplaces
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) { if (v != null) setState(() => _marketplace = v); },
                ),
                const SizedBox(height: 16),

                // ── Variant notes ──
                const Text('Variant / Specifications', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _variantCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'E.g. Color: Blue, Size: M',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Quantity ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: _quantity < 20 ? () => setState(() => _quantity++) : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Shipping method ──
                const Text('Shipping Method', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MethodTile(
                        icon: Icons.flight,
                        title: 'Air',
                        subtitle: 'Faster, higher cost',
                        selected: _shippingMethod == 'AIR',
                        onTap: () => setState(() => _shippingMethod = 'AIR'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MethodTile(
                        icon: Icons.directions_boat,
                        title: 'Sea',
                        subtitle: 'Slower, lower cost',
                        selected: _shippingMethod == 'SEA',
                        onTap: () => setState(() => _shippingMethod = 'SEA'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Get Quote ──
                FilledButton.icon(
                  onPressed: provider.actionLoading ? null : _submit,
                  icon: provider.actionLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.calculate_outlined),
                  label: Text(provider.actionLoading ? 'Getting quote...' : 'Get Quote'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Sub-widgets ──

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightPrimary.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightPrimary.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.lightPrimary, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _ProductPreviewCard extends StatelessWidget {
  final CbLinkPreview preview;
  const _ProductPreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withAlpha(100), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 16),
                SizedBox(width: 6),
                Text(
                  'Product details fetched',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),

          // ── Content ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: preview.hasImage
                      ? Image.network(
                          preview.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgPlaceholder(),
                        )
                      : _imgPlaceholder(),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (preview.title.isNotEmpty)
                        Text(
                          preview.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Pill(preview.marketplace),
                          if (preview.hasPrice) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${preview.currency} ${preview.priceText}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.lightPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (preview.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          preview.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Note ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Text(
              'If anything looks wrong, proceed anyway — our team verifies the price before purchase.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.lightTextSecondary.withAlpha(180),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _imgPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_not_supported_outlined, color: AppColors.lightTextSecondary),
    );
  }
}

class _PreviewSkeleton extends StatelessWidget {
  const _PreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Fetching product details...'),
          ],
        ),
      ),
    );
  }
}

class _PreviewError extends StatelessWidget {
  final String message;
  const _PreviewError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Could not fetch product details', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(message, style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary)),
                const SizedBox(height: 4),
                const Text(
                  'You can still proceed — our team will verify the item manually.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.lightPrimary.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.lightPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTile({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightPrimary : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.lightPrimary : AppColors.lightTextSecondary.withAlpha(60),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : AppColors.lightTextSecondary),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: selected ? Colors.white : AppColors.lightTextPrimary, fontWeight: FontWeight.w700)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : AppColors.lightTextSecondary)),
          ],
        ),
      ),
    );
  }
}
