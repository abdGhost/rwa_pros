class SubCategory {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final DateTime createdAt;

  SubCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.createdAt,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['_id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['subCategoryImage'],
      createdAt:
          json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
              : DateTime.now(), // fallback to now if missing or invalid
    );
  }
}

class Category {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final List<SubCategory> subCategories;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.subCategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final subList =
        (json['subCategories'] as List)
            .map((e) => SubCategory.fromJson(e))
            .toList();

    return Category(
      id: json['_id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['categoryImage'],
      subCategories: subList,
    );
  }
}
