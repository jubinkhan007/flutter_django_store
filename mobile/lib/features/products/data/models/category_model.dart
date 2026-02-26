import '../../domain/entities/category.dart';
import '../../../../core/config/api_config.dart';

class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.name,
    required super.slug,
    super.description,
    super.image,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawImage = json['image']?.toString();
    final resolvedImage = (rawImage == null || rawImage.trim().isEmpty)
        ? null
        : ApiConfig.resolveUrl(rawImage);

    return CategoryModel(
      id: json['id'],
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      image: resolvedImage,
    );
  }
}
