class FacetBrand {
  final String name;
  final int count;

  const FacetBrand({required this.name, required this.count});

  factory FacetBrand.fromJson(Map<String, dynamic> json) {
    return FacetBrand(
      name: json['name']?.toString() ?? '',
      count: json['count'] is int ? json['count'] : int.tryParse(json['count']?.toString() ?? '0') ?? 0,
    );
  }
}

class FacetCategory {
  final int id;
  final String name;
  final int count;

  const FacetCategory({required this.id, required this.name, required this.count});

  factory FacetCategory.fromJson(Map<String, dynamic> json) {
    return FacetCategory(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      count: json['count'] is int ? json['count'] : int.tryParse(json['count']?.toString() ?? '0') ?? 0,
    );
  }
}

class PriceRangeFacet {
  final double min;
  final double max;

  const PriceRangeFacet({required this.min, required this.max});

  factory PriceRangeFacet.fromJson(Map<String, dynamic> json) {
    return PriceRangeFacet(
      min: (json['min'] != null) ? double.tryParse(json['min'].toString()) ?? 0.0 : 0.0,
      max: (json['max'] != null) ? double.tryParse(json['max'].toString()) ?? 10000.0 : 10000.0,
    );
  }
}

class RatingCountsFacet {
  final int fourPlus;
  final int threePlus;
  final int twoPlus;

  const RatingCountsFacet({
    required this.fourPlus,
    required this.threePlus,
    required this.twoPlus,
  });

  factory RatingCountsFacet.fromJson(Map<String, dynamic> json) {
    return RatingCountsFacet(
      fourPlus: json['4_plus'] is int ? json['4_plus'] : int.tryParse(json['4_plus']?.toString() ?? '0') ?? 0,
      threePlus: json['3_plus'] is int ? json['3_plus'] : int.tryParse(json['3_plus']?.toString() ?? '0') ?? 0,
      twoPlus: json['2_plus'] is int ? json['2_plus'] : int.tryParse(json['2_plus']?.toString() ?? '0') ?? 0,
    );
  }
}

class DiscountCountsFacet {
  final int fiftyPlus;
  final int twentyFivePlus;
  final int tenPlus;

  const DiscountCountsFacet({
    required this.fiftyPlus,
    required this.twentyFivePlus,
    required this.tenPlus,
  });

  factory DiscountCountsFacet.fromJson(Map<String, dynamic> json) {
    return DiscountCountsFacet(
      fiftyPlus: json['50_plus'] is int ? json['50_plus'] : int.tryParse(json['50_plus']?.toString() ?? '0') ?? 0,
      twentyFivePlus: json['25_plus'] is int ? json['25_plus'] : int.tryParse(json['25_plus']?.toString() ?? '0') ?? 0,
      tenPlus: json['10_plus'] is int ? json['10_plus'] : int.tryParse(json['10_plus']?.toString() ?? '0') ?? 0,
    );
  }
}

class ProductFacets {
  final int totalCount;
  final int inStockCount;
  final PriceRangeFacet priceRange;
  final List<FacetBrand> brands;
  final List<FacetCategory> categories;
  final RatingCountsFacet ratingCounts;
  final DiscountCountsFacet discountCounts;

  const ProductFacets({
    required this.totalCount,
    required this.inStockCount,
    required this.priceRange,
    required this.brands,
    required this.categories,
    required this.ratingCounts,
    required this.discountCounts,
  });

  factory ProductFacets.fromJson(Map<String, dynamic> json) {
    final brandsRaw = (json['brands'] as List?) ?? [];
    final categoriesRaw = (json['categories'] as List?) ?? [];

    return ProductFacets(
      totalCount: json['total_count'] is int ? json['total_count'] : int.tryParse(json['total_count']?.toString() ?? '0') ?? 0,
      inStockCount: json['in_stock_count'] is int ? json['in_stock_count'] : int.tryParse(json['in_stock_count']?.toString() ?? '0') ?? 0,
      priceRange: PriceRangeFacet.fromJson((json['price_range'] as Map<String, dynamic>?) ?? {}),
      brands: brandsRaw.map((b) => FacetBrand.fromJson(b as Map<String, dynamic>)).toList(),
      categories: categoriesRaw.map((c) => FacetCategory.fromJson(c as Map<String, dynamic>)).toList(),
      ratingCounts: RatingCountsFacet.fromJson((json['rating_counts'] as Map<String, dynamic>?) ?? {}),
      discountCounts: DiscountCountsFacet.fromJson((json['discount_counts'] as Map<String, dynamic>?) ?? {}),
    );
  }
}
