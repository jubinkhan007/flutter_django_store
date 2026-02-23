/// Domain entity for a product Category.
class Category {
  final int id;
  final String name;
  final String slug;
  final String description;
  final String? image;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.image,
  });
}
