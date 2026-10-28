enum DiscoverCategory { books, blogs, documents }

enum DiscoverSourceKind { anna, zlibrary, rss, rfc }

abstract final class DiscoverSourceIds {
  static const anna = 'anna';
  static const zlibrary = 'zlibrary';
  static const cloudflare = 'cloudflare';
  static const github = 'github-engineering';
  static const rfc = 'rfc';
}

class DiscoverSource {
  const DiscoverSource({
    required this.id,
    required this.name,
    required this.kind,
    required this.category,
    required this.descriptionEn,
    required this.descriptionRu,
    required this.homeUrl,
    this.feedUrl,
  });

  final String id;
  final String name;
  final DiscoverSourceKind kind;
  final DiscoverCategory category;
  final String descriptionEn;
  final String descriptionRu;
  final String homeUrl;
  final String? feedUrl;

  bool get hasFeed =>
      kind == DiscoverSourceKind.rss || kind == DiscoverSourceKind.rfc;
  bool get isBookSource => category == DiscoverCategory.books;
  bool get searchesRecentOnly => kind == DiscoverSourceKind.rss;
  String description(String languageCode) =>
      languageCode == 'ru' ? descriptionRu : descriptionEn;
}

const discoverSourceCatalog = <DiscoverSource>[
  DiscoverSource(
    id: DiscoverSourceIds.cloudflare,
    name: 'Cloudflare',
    kind: DiscoverSourceKind.rss,
    category: DiscoverCategory.blogs,
    descriptionEn: 'Internet infrastructure, security and engineering',
    descriptionRu: 'Инфраструктура интернета, безопасность и разработка',
    homeUrl: 'https://blog.cloudflare.com/',
    feedUrl: 'https://blog.cloudflare.com/rss/',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.github,
    name: 'GitHub Engineering',
    kind: DiscoverSourceKind.rss,
    category: DiscoverCategory.blogs,
    descriptionEn: 'Architecture, performance and developer tools',
    descriptionRu: 'Архитектура, производительность и инструменты разработки',
    homeUrl: 'https://github.blog/engineering/',
    feedUrl: 'https://github.blog/engineering/feed/',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.rfc,
    name: 'RFC',
    kind: DiscoverSourceKind.rfc,
    category: DiscoverCategory.documents,
    descriptionEn: 'Internet specifications from the official RFC catalog',
    descriptionRu: 'Спецификации интернета из официального каталога RFC',
    homeUrl: 'https://www.rfc-editor.org/',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.anna,
    name: "Anna’s Archive",
    kind: DiscoverSourceKind.anna,
    category: DiscoverCategory.books,
    descriptionEn: 'Search for EPUB and PDF books',
    descriptionRu: 'Поиск книг в EPUB и PDF',
    homeUrl: 'https://annas-archive.org/',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.zlibrary,
    name: 'Z-Library',
    kind: DiscoverSourceKind.zlibrary,
    category: DiscoverCategory.books,
    descriptionEn: 'Search for EPUB and PDF books; sign-in may be required',
    descriptionRu: 'Поиск книг в EPUB и PDF; может потребоваться вход',
    homeUrl: 'https://z-library.sk/',
  ),
];
