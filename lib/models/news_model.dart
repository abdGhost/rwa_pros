class News {
  final String id;
  final String title;
  final String subTitle;
  final String author;
  final String content;
  final String thumbnail;
  final String slug;
  final DateTime publishDate;

  News({
    required this.id,
    required this.title,
    required this.subTitle,
    required this.author,
    required this.content,
    required this.thumbnail,
    required this.slug,
    required this.publishDate,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['_id'],
      title: json['title'],
      subTitle: json['subTitle'],
      author: json['author'],
      content: json['content'],
      thumbnail: json['thumbnail'],
      slug: json['slug'],
      publishDate: DateTime.parse(json['createdAt']),
    );
  }
}
