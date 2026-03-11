import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/features/cms/presentation/screens/cms_page_screen.dart';
import 'package:mobile/features/home/data/models/home_feed_model.dart';
import 'package:mobile/features/products/presentation/providers/product_provider.dart';
import 'package:mobile/features/products/presentation/screens/product_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HeroBannerCarousel extends StatefulWidget {
  final List<BannerModel> banners;

  const HeroBannerCarousel({super.key, required this.banners});

  @override
  State<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<HeroBannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.banners.isNotEmpty) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < widget.banners.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    // Reset timer on manual swipe
    _timer?.cancel();
    _startTimer();
  }

  Future<void> _handleBannerTap(BannerModel banner) async {
    final productProvider = context.read<ProductProvider>();
    final targetValue = banner.linkValue.trim();

    switch (banner.linkType.toUpperCase()) {
      case 'PRODUCT':
        final productId = int.tryParse(targetValue);
        if (productId == null) {
          _showMessage('This product link is invalid.');
          return;
        }
        try {
          final product = await productProvider.getProductDetail(productId);
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        } catch (_) {
          if (!mounted) return;
          _showMessage('Could not load this product.');
        }
        return;
      case 'CATEGORY':
        if (targetValue.isEmpty) {
          _showMessage('This category link is invalid.');
          return;
        }
        final categories = productProvider.categories;
        final targetCategory = categories.where((category) {
          final idMatches = category.id.toString() == targetValue;
          final slugMatches = category.slug.toLowerCase() ==
              targetValue.toLowerCase();
          return idMatches || slugMatches;
        }).toList();
        if (targetCategory.length != 1) {
          _showMessage('This category is not available right now.');
          return;
        }
        productProvider.applyCategoryShortcut(targetCategory.first.id);
        _showMessage('Showing ${targetCategory.first.name}.');
        return;
      case 'SEARCH':
        if (targetValue.isEmpty) {
          _showMessage('This search banner is empty.');
          return;
        }
        productProvider.applySearchShortcut(targetValue);
        _showMessage('Showing results for "$targetValue".');
        return;
      case 'PAGE':
        if (targetValue.isEmpty) {
          _showMessage('This page is unavailable.');
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CmsPageScreen(
              slug: targetValue,
              titleOverride: banner.title.isNotEmpty ? banner.title : null,
            ),
          ),
        );
        return;
      case 'URL':
      case 'EXTERNAL_URL':
        final uri = Uri.tryParse(targetValue);
        if (uri == null) {
          _showMessage('This link is invalid.');
          return;
        }
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && mounted) {
          _showMessage('Could not open this link.');
        }
        return;
      default:
        return;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return _BannerItem(
                banner: banner,
                onTap: () => _handleBannerTap(banner),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildIndicators(),
      ],
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.banners.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppColors.lightPrimary
                : AppColors.lightPrimary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final BannerModel banner;
  final VoidCallback onTap;

  const _BannerItem({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: banner.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              ),
            ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Text Overlay
            Positioned(
              left: 20,
              bottom: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    banner.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (banner.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      banner.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
