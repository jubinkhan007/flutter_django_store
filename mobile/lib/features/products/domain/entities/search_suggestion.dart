class SearchSuggestion {
  final String type;
  final int id;
  final String label;
  final String subtitle;

  SearchSuggestion({
    required this.type,
    required this.id,
    required this.label,
    required this.subtitle,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      type: json['type'] ?? 'PRODUCT',
      id: json['id'] ?? 0,
      label: json['label'] ?? '',
      subtitle: json['subtitle'] ?? '',
    );
  }
}
