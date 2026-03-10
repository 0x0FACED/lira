class ZLibraryBook {
  final String id;
  final String isbn;
  final String title;
  final String author;
  final String coverUrl;
  final String publisher;
  final String year;
  final String language;
  final String extension;
  final String size;
  final String rating;
  final String url;
  final String? downloadUrl;

  /// Alias for id to match some other APIs interfaces like annas_archive_api
  String get md5 => id;

  /// Alias for coverUrl to match some other APIs interfaces
  String get imgUrl => coverUrl;

  const ZLibraryBook({
    required this.id,
    required this.isbn,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.publisher,
    required this.year,
    required this.language,
    required this.extension,
    required this.size,
    required this.rating,
    required this.url,
    this.downloadUrl,
  });

  ZLibraryBook copyWith({
    String? id,
    String? isbn,
    String? title,
    String? author,
    String? coverUrl,
    String? publisher,
    String? year,
    String? language,
    String? extension,
    String? size,
    String? rating,
    String? url,
    String? downloadUrl,
  }) {
    return ZLibraryBook(
      id: id ?? this.id,
      isbn: isbn ?? this.isbn,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      publisher: publisher ?? this.publisher,
      year: year ?? this.year,
      language: language ?? this.language,
      extension: extension ?? this.extension,
      size: size ?? this.size,
      rating: rating ?? this.rating,
      url: url ?? this.url,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  @override
  String toString() {
    return 'ZLibraryBook(id: \$id, title: \$title, author: \$author, extension: \$extension)';
  }
}