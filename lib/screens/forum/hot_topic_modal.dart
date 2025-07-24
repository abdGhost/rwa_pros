class HotTopic {
  final String id;
  final String title;
  final String? text; // ✅ Add this line
  final int commentsCount;
  final String? userName;
  final String? categoryId;

  HotTopic({
    required this.id,
    required this.title,
    this.text, // ✅ Include in constructor
    required this.commentsCount,
    this.userName,
    this.categoryId,
  });

  factory HotTopic.fromJson(Map<String, dynamic> json) {
    return HotTopic(
      id: json['_id'],
      title: json['title'],
      text: json['text'], // ✅ Parse it from JSON
      commentsCount: json['commentsCount'] ?? 0,
      userName: json['userId']?['userName'],
      categoryId: json['categoryId']?['_id'],
    );
  }
}
