import '../../../products/data/models/product_model.dart';
import '../../../../core/config/api_config.dart';

class HomeFeed {
  final DateTime serverNow;
  final List<HomeSection> sections;

  HomeFeed({required this.serverNow, required this.sections});

  factory HomeFeed.fromJson(Map<String, dynamic> json) {
    return HomeFeed(
      serverNow: DateTime.parse(json['server_now']),
      sections: (json['sections'] as List)
          .map((s) => HomeSection.fromJson(s))
          .toList(),
    );
  }
}

enum HomeSectionType { banners, flashSale, featuredRow, unknown }

abstract class HomeSection {
  final HomeSectionType type;

  HomeSection({required this.type});

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    switch (typeStr) {
      case 'BANNERS':
        return BannersSection.fromJson(json['data']);
      case 'FLASH_SALE':
        return FlashSaleSection.fromJson(json['data']);
      case 'FEATURED_ROW':
        return FeaturedRowSection.fromJson(json);
      default:
        return UnknownSection();
    }
  }
}

class BannersSection extends HomeSection {
  final List<BannerModel> banners;

  BannersSection({required this.banners})
    : super(type: HomeSectionType.banners);

  factory BannersSection.fromJson(dynamic json) {
    return BannersSection(
      banners: (json as List).map((b) => BannerModel.fromJson(b)).toList(),
    );
  }
}

class FlashSaleSection extends HomeSection {
  final int id;
  final String title;
  final String description;
  final DateTime endsAt;
  final List<FlashSaleProductModel> products;

  FlashSaleSection({
    required this.id,
    required this.title,
    required this.description,
    required this.endsAt,
    required this.products,
  }) : super(type: HomeSectionType.flashSale);

  factory FlashSaleSection.fromJson(Map<String, dynamic> json) {
    return FlashSaleSection(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      endsAt: DateTime.parse(json['ends_at']),
      products: (json['products'] as List)
          .map((p) => FlashSaleProductModel.fromJson(p))
          .toList(),
    );
  }
}

class FeaturedRowSection extends HomeSection {
  final int id;
  final String title;
  final String sectionType;
  final List<ProductModel> products;

  FeaturedRowSection({
    required this.id,
    required this.title,
    required this.sectionType,
    required this.products,
  }) : super(type: HomeSectionType.featuredRow);

  factory FeaturedRowSection.fromJson(Map<String, dynamic> json) {
    // Note: FeaturedRow data is directly in the section object except 'products' in 'data'
    // Wait, let's check backend HomeFeedView response structure again.
    /*
    sections.append({
        'type': 'FEATURED_ROW',
        'data': section_data,
    })
    */
    final data = json['data'] as Map<String, dynamic>;
    return FeaturedRowSection(
      id: data['id'],
      title: data['title'],
      sectionType: data['section_type'],
      products: (data['products'] as List)
          .map((p) => ProductModel.fromJson(p))
          .toList(),
    );
  }
}

class UnknownSection extends HomeSection {
  UnknownSection() : super(type: HomeSectionType.unknown);
}

class BannerModel {
  final int id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String linkType;
  final String linkValue;

  BannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.linkType,
    required this.linkValue,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'],
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      imageUrl: ApiConfig.resolveUrl(json['image_url'] ?? ''),
      linkType: json['link_type'] ?? 'NONE',
      linkValue: json['link_value'] ?? '',
    );
  }
}

class FlashSaleProductModel {
  final int id;
  final ProductModel product;
  final String discountType;
  final double discountValue;
  final double effectiveSalePrice;
  final int? purchaseLimitTotal;
  final int? maxPerUser;
  final int sortOrder;

  FlashSaleProductModel({
    required this.id,
    required this.product,
    required this.discountType,
    required this.discountValue,
    required this.effectiveSalePrice,
    this.purchaseLimitTotal,
    this.maxPerUser,
    required this.sortOrder,
  });

  factory FlashSaleProductModel.fromJson(Map<String, dynamic> json) {
    return FlashSaleProductModel(
      id: json['id'],
      product: ProductModel.fromJson(json['product']),
      discountType: json['discount_type'],
      discountValue: double.tryParse(json['discount_value'].toString()) ?? 0.0,
      effectiveSalePrice:
          double.tryParse(json['effective_sale_price'].toString()) ?? 0.0,
      purchaseLimitTotal: json['purchase_limit_total'],
      maxPerUser: json['max_per_user'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
