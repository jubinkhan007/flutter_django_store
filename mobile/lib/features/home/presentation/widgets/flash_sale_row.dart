import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:provider/provider.dart';

import 'package:mobile/features/cart/presentation/providers/cart_provider.dart';
import 'package:mobile/features/home/data/models/home_feed_model.dart';
import 'package:mobile/core/services/analytics_service.dart';
import 'package:mobile/features/products/presentation/screens/product_detail_screen.dart';
import 'package:mobile/features/products/presentation/widgets/product_card.dart';

class FlashSaleRow extends StatefulWidget {
  final FlashSaleSection sale;
  final DateTime serverNow;

  const FlashSaleRow({super.key, required this.sale, required this.serverNow});

  @override
  State<FlashSaleRow> createState() => _FlashSaleRowState();
}

class _FlashSaleRowState extends State<FlashSaleRow> {
  late Timer _timer;
  late Duration _remaining;
  late DateTime _endTime;
  late Duration _serverOffset;

  @override
  void initState() {
    super.initState();
    _endTime = widget.sale.endsAt;

    // The constant difference between server time and local time
    _serverOffset = widget.serverNow.difference(DateTime.now());

    _remaining = _endTime.difference(DateTime.now().add(_serverOffset));
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        // Current server time is local time + constant offset
        final currentServerTime = DateTime.now().add(_serverOffset);
        _remaining = _endTime.difference(currentServerTime);

        if (_remaining.isNegative) {
          _timer.cancel();
          _remaining = Duration.zero;
        }
      });
    });
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return "00:00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative && _remaining.inSeconds == 0)
      return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '⚡ Flash Sale',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(_remaining),
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('See All')),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: widget.sale.products.length,
            itemBuilder: (context, index) {
              final saleProduct = widget.sale.products[index];
              return _FlashSaleCard(
                saleProduct: saleProduct,
                onTap: () {
                  context.read<AnalyticsService>().logEvent(
                    eventType: 'CLICK',
                    source: 'HOME',
                    productId: saleProduct.product.id,
                    metadata: {
                      'section_type': 'FLASH_SALE',
                      'position': index,
                      'sale_id': widget.sale.id,
                    },
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                        product: saleProduct.product,
                      ),
                    ),
                  );
                },
                onAddToCart: () {
                  context.read<CartProvider>().addToCart(saleProduct.product);
                  context.read<AnalyticsService>().logEvent(
                    eventType: 'ADD_TO_CART',
                    source: 'HOME',
                    productId: saleProduct.product.id,
                    metadata: {
                      'section_type': 'FLASH_SALE',
                      'position': index,
                      'sale_id': widget.sale.id,
                    },
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${saleProduct.product.name} added to cart'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FlashSaleCard extends StatelessWidget {
  final FlashSaleProductModel saleProduct;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _FlashSaleCard({
    required this.saleProduct,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        children: [
          ProductCard(
            product: saleProduct.product,
            salePrice: saleProduct.effectiveSalePrice,
            onTap: onTap,
            onAddToCart: onAddToCart,
          ),
          // Discount Badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                saleProduct.discountType == 'PERCENT'
                    ? '-${saleProduct.discountValue.toInt()}%'
                    : 'SAVE \$${(saleProduct.product.price - saleProduct.effectiveSalePrice).toInt()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
