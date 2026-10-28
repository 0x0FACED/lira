class DiscoverItem {
  const DiscoverItem({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.url,
    this.author = '',
    this.summary = '',
    this.imageUrl,
    this.publishedAt,
    this.status,
    this.documentNumber,
  });

  final String id;
  final String sourceId;
  final String title;
  final Uri url;
  final String author;
  final String summary;
  final Uri? imageUrl;
  final DateTime? publishedAt;
  final String? status;
  final int? documentNumber;

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'title': title,
    'url': url.toString(),
    'author': author,
    'summary': summary,
    'imageUrl': imageUrl?.toString(),
    'publishedAt': publishedAt?.toIso8601String(),
    'status': status,
    'documentNumber': documentNumber,
  };

  factory DiscoverItem.fromJson(Map<String, dynamic> json) => DiscoverItem(
    id: json['id'] as String,
    sourceId: json['sourceId'] as String,
    title: json['title'] as String,
    url: Uri.parse(json['url'] as String),
    author: json['author'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    imageUrl: json['imageUrl'] == null
        ? null
        : Uri.parse(json['imageUrl'] as String),
    publishedAt: json['publishedAt'] == null
        ? null
        : DateTime.parse(json['publishedAt'] as String),
    status: json['status'] as String?,
    documentNumber: json['documentNumber'] as int?,
  );
}

class DiscoverFeed {
  const DiscoverFeed({
    required this.items,
    required this.updatedAt,
    this.isStale = false,
  });
  final List<DiscoverItem> items;
  final DateTime updatedAt;
  final bool isStale;
}

typedef DiscoverQuery = ({String sourceId, String query});
