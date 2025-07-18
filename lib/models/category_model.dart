class Category {
  final String id;
  final String name;
  final double avg24hPercent;
  final List<String> topTokenImages;

  Category({
    required this.id,
    required this.name,
    required this.avg24hPercent,
    required this.topTokenImages,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id'],
      name: json['categoryName'],
      avg24hPercent: (json['avg24hPercent'] as num?)?.toDouble() ?? 0.0,
      topTokenImages: List<String>.from(json['topTokenImages'] ?? []),
    );
  }
}
