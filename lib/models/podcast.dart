class Podcast {
  final String id;
  final String profileImg;
  final String videoTitle;
  final String description;
  final String thumbnail;
  final String youtubeLink;
  final DateTime createdAt;
  final String founderName;

  Podcast({
    required this.id,
    required this.profileImg,
    required this.videoTitle,
    required this.description,
    required this.thumbnail,
    required this.youtubeLink,
    required this.createdAt,
    required this.founderName,
  });

  factory Podcast.fromJson(Map<String, dynamic> json) {
    final user = json['userId'] ?? {};

    return Podcast(
      id: json['_id'] ?? '',
      profileImg: json['profileImg'] ?? '',
      videoTitle: json['videoTitle'] ?? '',
      description: json['description'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      youtubeLink: json['youtubeLink'] ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      founderName: user['username'] ?? 'Unknown',
    );
  }
}
