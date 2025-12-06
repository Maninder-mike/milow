class NewsArticle {
  final String title;
  final String source;
  final String? url;
  final String? urlToImage;
  final DateTime? publishedAt;
  final String? description;

  NewsArticle({
    required this.title,
    required this.source,
    this.url,
    this.urlToImage,
    this.publishedAt,
    this.description,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] ?? 'No Title',
      source: json['source']?['name'] ?? 'Unknown Source',
      url: json['url'],
      urlToImage: json['urlToImage'],
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'])
          : null,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'source': {'name': source},
      'url': url,
      'urlToImage': urlToImage,
      'publishedAt': publishedAt?.toIso8601String(),
      'description': description,
    };
  }
}
