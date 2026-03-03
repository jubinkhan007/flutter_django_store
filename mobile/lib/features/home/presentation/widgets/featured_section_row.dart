import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/home/data/models/home_feed_model.dart';
import 'package:mobile/features/cart/presentation/providers/cart_provider.dart';
import 'package:mobile/core/services/analytics_service.dart';
import 'package:provider/provider.dart';
import 'package:mobile/features/products/presentation/widgets/product_card.dart';
import 'package:mobile/features/products/presentation/screens/product_detail_screen.dart';

class FeaturedSectionRow extends StatelessWidget {
  final FeaturedRowSection section;

  const FeaturedSectionRow({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 8),
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('See All')),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: section.products.length,
            itemBuilder: (context, index) {
              final product = section.products[index];
              return Container(
                width: 150,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: ProductCard(
                  product: product,
                  onTap: () {
                    context.read<AnalyticsService>().logEvent(
                      eventType: 'CLICK',
                      source: 'HOME',
                      productId: product.id,
                      metadata: {
                        'section_type': section.sectionType,
                        'position': index,
                      },
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
                    );
                  },
                  onAddToCart: () {
                    context.read<CartProvider>().addToCart(product);
                    context.read<AnalyticsService>().logEvent(
                      eventType: 'ADD_TO_CART',
                      source: 'HOME',
                      productId: product.id,
                      metadata: {
                        'section_type': section.sectionType,
                        'position': index,
                      },
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.name} added to cart'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (section.sectionType) {
      case 'TRENDING':
        icon = Icons.local_fire_department;
        color = Colors.orange;
        break;
      case 'NEW_ARRIVALS':
        icon = Icons.auto_awesome;
        color = Colors.blue;
        break;
      case 'TOP_RATED':
        icon = Icons.star;
        color = Colors.amber;
        break;
      default:
        icon = Icons.collections;
        color = AppColors.lightPrimary;
    }

    return Icon(icon, color: color, size: 24);
  }
}
