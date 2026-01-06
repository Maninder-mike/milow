enum LearningResourceType { video, article, document }

enum LearningCategory { safety, compliance, maintenance, general }

class LearningResource {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final LearningResourceType type;
  final LearningCategory category;
  final Duration? duration; // For videos
  final DateTime publishedAt;
  final String? url; // Link to content

  const LearningResource({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.type,
    required this.category,
    required this.publishedAt,
    this.duration,
    this.url,
  });
}
