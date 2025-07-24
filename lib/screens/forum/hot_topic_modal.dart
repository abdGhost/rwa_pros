class HotTopic {
  final String id;
  final String title;
  final int commentsCount;
  final Map<String, int> reactions;
  final String? categoryId;
  final String? categoryName;
  final String? userId;
  final String? userName;

  HotTopic({
    required this.id,
    required this.title,
    required this.commentsCount,
    required this.reactions,
    this.categoryId,
    this.categoryName,
    this.userId,
    this.userName,
  });

  factory HotTopic.fromJson(Map<String, dynamic> json) {
    final category = json['categoryId'];
    final user = json['userId'];

    return HotTopic(
      id: json['_id'],
      title: json['title'] ?? '',
      commentsCount: json['commentsCount'] ?? 0,
      reactions: Map<String, int>.from(json['reactions'] ?? {}),
      categoryId: category is Map ? category['_id'] : null,
      categoryName: category is Map ? category['name'] : null,
      userId: user is Map ? user['_id'] : null,
      userName: user is Map ? user['userName'] : null,
    );
  }
}
