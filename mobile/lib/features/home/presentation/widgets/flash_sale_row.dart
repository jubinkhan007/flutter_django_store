import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';

import 'package:mobile/features/home/data/models/home_feed_model.dart';
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

  @override
  void initState() {
    super.initState();
    _endTime = widget.sale.endsAt;

    // Calculate initial remaining time adjusted by serverNow offset
    final localNow = DateTime.now();
    final offset = widget.serverNow.difference(localNow);
    final adjustedNow = localNow.add(offset);

    _remaining = _endTime.difference(adjustedNow);
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
        _remaining = _endTime.difference(
          DateTime.now().add(widget.serverNow.difference(DateTime.now())),
        );
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
                  // Navigate to product detail
                },
                onAddToCart: () {
                  // Add to cart logic
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
            onTap: onTap,
            onAddToCart: onAddToCart,
          ),
          // Price Overlay for Flash Sale
          Positioned(
            left: 8,
            right: 8,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${saleProduct.effectiveSalePrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '\$${saleProduct.product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      decoration: TextDecoration.lineThrough,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
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
              ),
              child: Text(
                saleProduct.discountType == 'PERCENT'
                    ? '-${saleProduct.discountValue.toInt()}%'
                    : 'SAVE \$${(saleProduct.product.price - saleProduct.effectiveSalePrice).toInt()}',
                style: const TextStyle(
                  color: Colors.white,
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
