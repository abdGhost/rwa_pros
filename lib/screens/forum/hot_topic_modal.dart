class HotTopic {
  final String id;
  final String title;
  final String? text;
  final int commentsCount;
  final String? userName;
  final String? userId;
  final String? categoryId;
  final String? categoryName;

  HotTopic({
    required this.id,
    required this.title,
    this.text,
    required this.commentsCount,
    this.userName,
    this.userId,
    this.categoryId,
    this.categoryName,
  });

  factory HotTopic.fromJson(Map<String, dynamic> json) {
    final categoryData = json['categoryId'];
    final userData = json['userId'];

    return HotTopic(
      id: json['_id'],
      title: json['title'],
      text: json['text'],
      commentsCount: json['commentsCount'] ?? 0,
      userId: userData?['_id'],
      userName: userData?['userName'],
      categoryId: categoryData?['_id'],
      categoryName: categoryData?['name'],
    );
  }
}
