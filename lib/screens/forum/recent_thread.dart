class RecentThread {
  final String id;
  final String title;
  final String? text;
  final int commentsCount;
  final String? userName;
  final String? categoryId; // "_id" from categoryId map
  final String? categoryName; // "name" from categoryId map

  RecentThread({
    required this.id,
    required this.title,
    this.text,
    required this.commentsCount,
    this.userName,
    this.categoryId,
    this.categoryName,
  });

  factory RecentThread.fromJson(Map<String, dynamic> json) {
    final categoryData = json['categoryId'] as Map<String, dynamic>?;

    return RecentThread(
      id: json['_id'],
      title: json['title'],
      text: json['text'],
      commentsCount: json['commentsCount'] ?? 0,
      userName: json['userId']?['userName'],
      categoryId: categoryData?['_id'],
      categoryName: categoryData?['name'],
    );
  }
}
