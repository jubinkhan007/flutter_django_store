import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/home/data/models/home_feed_model.dart';
import 'package:mobile/features/products/presentation/widgets/product_card.dart';

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
                    // Navigate to product detail
                  },
                  onAddToCart: () {
                    // Add to cart logic
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
