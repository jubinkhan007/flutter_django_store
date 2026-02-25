import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../reviews/data/models/review_model.dart';
import '../../../reviews/presentation/providers/review_provider.dart';
import '../../../reviews/presentation/widgets/review_card.dart';
import '../../../reviews/presentation/widgets/star_rating.dart';
import '../../../vendor/presentation/providers/vendor_provider.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/variant.dart';
import 'package:mobile/features/wishlist/presentation/providers/wishlist_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final Map<int, int> _selectedOptions = {};
  ProductVariant? _currentVariant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReviewProvider>().loadReviews(widget.product.id);
    });
    
    // Auto-select first available option values if options exist
    if (widget.product.options.isNotEmpty) {
      for (var option in widget.product.options) {
        if (option.values.isNotEmpty) {
          _selectedOptions[option.id] = option.values.first.id;
        }
      }
      _updateCurrentVariant();
    }
  }
  
  void _updateCurrentVariant() {
    if (widget.product.variants.isEmpty) return;
    
    // Find the variant that matches all selected option values
    final selectedValueIds = _selectedOptions.values.toSet();
    
    try {
      _currentVariant = widget.product.variants.firstWhere((variant) {
        final variantValueIds = variant.optionValueIds.toSet();
        return selectedValueIds.length == variantValueIds.length && 
               selectedValueIds.containsAll(variantValueIds);
      });
    } catch (e) {
      _currentVariant = null; // No matching variant found
    }
    setState(() {});
  }

  bool _isVendorOfProduct(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (auth.user?.isVendor != true) return false;
    final vendorDashboard = context.read<VendorProvider>().dashboard;
    if (vendorDashboard == null) return false;
    return vendorDashboard['id'] == widget.product.vendorId;
  }

  void _showWriteReviewSheet(BuildContext context) {
    int selectedRating = 0;
    final commentController = TextEditingController();
    final provider = context.read<ReviewProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Write a Review',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: StarPicker(
                  value: selectedRating,
                  onChanged: (v) => setModalState(() => selectedRating = v),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Share your experience...',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedRating == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a rating')),
                      );
                      return;
                    }
                    if (commentController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please write a comment')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final ok = await provider.submitReview(
                      widget.product.id,
                      selectedRating,
                      commentController.text.trim(),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Review submitted!'
                                : (provider.error ?? 'Failed'),
                          ),
                          backgroundColor: ok
                              ? AppTheme.success
                              : AppTheme.error,
                        ),
                      );
                    }
                  },
                  child: const Text('Submit Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReplySheet(
    BuildContext context,
    ReviewModel review,
    bool isEditing,
  ) {
    final controller = TextEditingController(
      text: isEditing ? review.reply?.reply : '',
    );
    final provider = context.read<ReviewProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Edit Your Reply' : 'Reply to Review',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Write your response...',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  final ok = isEditing
                      ? await provider.editReply(
                          review.id,
                          controller.text.trim(),
                        )
                      : await provider.replyToReview(
                          review.id,
                          controller.text.trim(),
                        );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok ? 'Reply saved!' : (provider.error ?? 'Failed'),
                        ),
                        backgroundColor: ok ? AppTheme.success : AppTheme.error,
                      ),
                    );
                  }
                },
                child: Text(isEditing ? 'Save Changes' : 'Post Reply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;
    final isVendor = _isVendorOfProduct(context);
    
    final displayPrice = _currentVariant?.effectivePrice ?? widget.product.price;
    final inStock = widget.product.options.isEmpty ? widget.product.inStock : (_currentVariant != null && _currentVariant!.stockAvailable > 0);
    final stockQty = widget.product.options.isEmpty ? widget.product.stockQuantity : (_currentVariant?.stockAvailable ?? 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Hero Image AppBar
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppTheme.surface,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.background.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
            ),
            actions: [
              Consumer<WishlistProvider>(
                builder: (context, wishlist, child) {
                  final isWishlisted = wishlist.isWishlisted(widget.product.id);
                  return IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.background.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isWishlisted ? Icons.favorite : Icons.favorite_border,
                        color: isWishlisted ? Colors.red : AppTheme.textPrimary,
                        size: 20,
                      ),
                    ),
                    onPressed: () {
                      if (!isLoggedIn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please login to add to wishlist'),
                          ),
                        );
                        return;
                      }
                      wishlist.toggleWishlist(
                        widget.product.id,
                        productDetails: {
                          'name': widget.product.name,
                          'price': widget.product.price,
                          'image': widget.product.image,
                          'inStock': widget.product.inStock,
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: AppTheme.spacingSm),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppTheme.surfaceLight,
                child: widget.product.image != null
                    ? Image.network(
                        widget.product.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: AppTheme.textSecondary,
                            size: 80,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: AppTheme.textSecondary,
                          size: 80,
                        ),
                      ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                        child: Text(
                          '\$${displayPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMd),

                  // Stock status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: inStock
                              ? AppTheme.success.withOpacity(0.15)
                              : AppTheme.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                        child: Text(
                          inStock ? 'In Stock' : 'Out of Stock',
                          style: TextStyle(
                            color: inStock
                                ? AppTheme.success
                                : AppTheme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$stockQty available',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),

                  // Options Selector
                  if (widget.product.options.isNotEmpty) ...[
                    ...widget.product.options.map((option) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: option.values.map((val) {
                                final isSelected = _selectedOptions[option.id] == val.id;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedOptions[option.id] = val.id;
                                      _updateCurrentVariant();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primary : AppTheme.surface,
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      val.value,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                    if (_currentVariant == null && widget.product.options.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'Selected variant is unavailable',
                          style: TextStyle(color: AppTheme.error, fontSize: 12),
                        ),
                      ),
                    const Divider(color: AppTheme.surfaceLight),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    widget.product.description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXl),

                  // ── Reviews ──────────────────────────────────────
                  Consumer<ReviewProvider>(
                    builder: (context, reviewProvider, _) {
                      final reviews = reviewProvider.reviews;
                      final avg = reviewProvider.averageRating;
                      final dist = reviewProvider.ratingDistribution;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Reviews',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              if (isLoggedIn && !isVendor)
                                TextButton.icon(
                                  onPressed: () =>
                                      _showWriteReviewSheet(context),
                                  icon: const Icon(
                                    Icons.rate_review_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Write a Review'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Rating summary card
                          if (reviews.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        avg.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      StarRating(rating: avg, size: 18),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${reviews.length} review${reviews.length != 1 ? 's' : ''}',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      children: [5, 4, 3, 2, 1].map((star) {
                                        final count = dist[star] ?? 0;
                                        final frac = reviews.isEmpty
                                            ? 0.0
                                            : count / reviews.length;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                '$star',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.star,
                                                size: 10,
                                                color: AppTheme.warning,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child:
                                                      LinearProgressIndicator(
                                                        value: frac,
                                                        backgroundColor:
                                                            AppTheme
                                                                .surfaceLight,
                                                        color: AppTheme.warning,
                                                        minHeight: 6,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '$count',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // List / empty / loading
                          if (reviewProvider.isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(
                                  color: AppTheme.primary,
                                ),
                              ),
                            )
                          else if (reviews.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.rate_review_outlined,
                                    color: AppTheme.textSecondary,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No reviews yet',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  if (isLoggedIn && !isVendor) ...[
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () =>
                                          _showWriteReviewSheet(context),
                                      child: const Text(
                                        'Be the first to review',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else
                            ...reviews.map(
                              (r) => ReviewCard(
                                review: r,
                                isVendorOfProduct: isVendor,
                                onReply: (review, isEditing) =>
                                    _showReplySheet(context, review, isEditing),
                              ),
                            ),

                          const SizedBox(height: AppTheme.spacingXl),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(
            top: BorderSide(color: AppTheme.surfaceLight, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: CustomButton(
            text: inStock ? 'Add to Cart' : 'Out of Stock',
            onPressed: (inStock && (widget.product.options.isEmpty || _currentVariant != null))
                ? () {
                    context.read<CartProvider>().addToCart(widget.product, variant: _currentVariant);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${widget.product.name} added to cart'),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  }
                : null,
          ),
        ),
      ),
    );
  }
}
