import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/crossborder_provider.dart';
import 'cb_checkout_screen.dart';

const _marketplaces = [
  'AMAZON',
  'ALIEXPRESS',
  'ALIBABA',
  '1688',
  'OTHER',
];

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<CrossBorderProvider>();
    final req = await provider.createRequest(
      sourceUrl: _urlCtrl.text.trim(),
      marketplace: _marketplace,
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CbCheckoutScreen(request: req)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy by Link')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // ── Info banner ──
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.lightPrimary.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.lightPrimary.withAlpha(50)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.lightPrimary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Paste the product URL from Amazon, AliExpress, Alibaba or any international marketplace. We\'ll purchase it on your behalf and deliver it to you.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // ── URL field ──
            const Text('Product URL', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://www.amazon.com/dp/...',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter a product URL';
                if (!v.trim().startsWith('http')) return 'Enter a valid URL';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Marketplace ──
            const Text('Marketplace', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _marketplace,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _marketplaces.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
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
                hintText: 'E.g. Color: Blue, Size: M, Quantity: 2 pcs',
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

            // ── Submit ──
            Consumer<CrossBorderProvider>(
              builder: (context, provider, _) => FilledButton.icon(
                onPressed: provider.actionLoading ? null : _submit,
                icon: provider.actionLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.calculate_outlined),
                label: Text(provider.actionLoading ? 'Getting quote...' : 'Get Quote'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
            ),
          ],
        ),
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
