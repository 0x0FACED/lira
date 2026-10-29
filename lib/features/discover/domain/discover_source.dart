enum DiscoverCategory { books, blogs, documents }

enum DiscoverSourceKind { anna, zlibrary, rss, rfc }

enum DiscoverTopic {
  technology,
  economics,
  nature,
  history,
  culture,
  psychology,
  science,
}

enum DiscoverSourceLanguage { russian, english, multilingual }

abstract final class DiscoverSourceIds {
  static const anna = 'anna';
  static const zlibrary = 'zlibrary';
  static const cloudflare = 'cloudflare';
  static const github = 'github-engineering';
  static const rfc = 'rfc';
  static const batrachospermum = 'batrachospermum';
  static const elementy = 'elementy';
  static const ourWorldInData = 'our-world-in-data';
  static const jstorDaily = 'jstor-daily';
  static const aeon = 'aeon';
  static const mongabay = 'mongabay';
}

class DiscoverSource {
  const DiscoverSource({
    required this.id,
    required this.name,
    required this.kind,
    required this.category,
    required this.topics,
    required this.language,
    required this.descriptionEn,
    required this.descriptionRu,
    required this.homeUrl,
    this.feedUrl,
  });

  final String id;
  final String name;
  final DiscoverSourceKind kind;
  final DiscoverCategory category;
  final Set<DiscoverTopic> topics;
  final DiscoverSourceLanguage language;
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
    topics: {DiscoverTopic.technology},
    language: DiscoverSourceLanguage.english,
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
    topics: {DiscoverTopic.technology},
    language: DiscoverSourceLanguage.english,
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
    topics: {DiscoverTopic.technology},
    language: DiscoverSourceLanguage.english,
    descriptionEn: 'Internet specifications from the official RFC catalog',
    descriptionRu: 'Спецификации интернета из официального каталога RFC',
    homeUrl: 'https://www.rfc-editor.org/',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.anna,
    name: "Anna’s Archive",
    kind: DiscoverSourceKind.anna,
    category: DiscoverCategory.books,
    topics: {
      DiscoverTopic.technology,
      DiscoverTopic.economics,
      DiscoverTopic.nature,
      DiscoverTopic.history,
      DiscoverTopic.culture,
      DiscoverTopic.psychology,
      DiscoverTopic.science,
    },
    language: DiscoverSourceLanguage.multilingual,
    descriptionEn: 'Search for EPUB and PDF books',
    descriptionRu: 'Поиск книг в EPUB и PDF',
    homeUrl: 'https://annas-archive.org/',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.zlibrary,
    name: 'Z-Library',
    kind: DiscoverSourceKind.zlibrary,
    category: DiscoverCategory.books,
    topics: {
      DiscoverTopic.technology,
      DiscoverTopic.economics,
      DiscoverTopic.nature,
      DiscoverTopic.history,
      DiscoverTopic.culture,
      DiscoverTopic.psychology,
      DiscoverTopic.science,
    },
    language: DiscoverSourceLanguage.multilingual,
    descriptionEn: 'Search for EPUB and PDF books; sign-in may be required',
    descriptionRu: 'Поиск книг в EPUB и PDF; может потребоваться вход',
    homeUrl: 'https://z-library.sk/',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.batrachospermum,
    name: 'Батрахоспермум',
    kind: DiscoverSourceKind.rss,
    category: DiscoverCategory.blogs,
    topics: {DiscoverTopic.nature, DiscoverTopic.science},
    language: DiscoverSourceLanguage.russian,
    descriptionEn:
        'Biology, the natural world and unusual scientific discoveries',
    descriptionRu: 'Биология, живая природа и необычные научные открытия',
    homeUrl: 'https://batrachospermum.ru/',
    feedUrl: 'https://batrachospermum.ru/feed/',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.elementy,
    name: 'Элементы',
    kind: DiscoverSourceKind.rss,
    category: DiscoverCategory.blogs,
    topics: {DiscoverTopic.nature, DiscoverTopic.science},
    language: DiscoverSourceLanguage.russian,
    descriptionEn:
        'Science news: biology, physics, astronomy and Earth sciences',
    descriptionRu:
        'Новости науки: биология, физика, астрономия и науки о Земле',
    homeUrl: 'https://elementy.ru/',
    feedUrl: 'https://elementy.ru/rss/news',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.ourWorldInData,
    name: 'Our World in Data',
    kind: DiscoverSourceKind.rss,
    category: DiscoverCategory.blogs,
    topics: {
      DiscoverTopic.economics,
      DiscoverTopic.nature,
      DiscoverTopic.science,
    },
    language: DiscoverSourceLanguage.english,
    descriptionEn:
        'Data and research on health, poverty, population and the environment',
    descriptionRu:
        'Данные и исследования о здоровье, бедности, населении и окружающей среде',
    homeUrl: 'https://ourworldindata.org/',
    feedUrl: 'https://ourworldindata.org/atom.xml',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.jstorDaily,
    name: 'JSTOR Daily',
    kind: DiscoverSourceKind.rss,
    category: DiscoverCategory.blogs,
    topics: {
      DiscoverTopic.history,
      DiscoverTopic.culture,
      DiscoverTopic.psychology,
      DiscoverTopic.science,
    },
    language: DiscoverSourceLanguage.english,
    descriptionEn: 'History, culture and science through academic research',
    descriptionRu: 'История, культура и наука через академические исследования',
    homeUrl: 'https://daily.jstor.org/',
    feedUrl: 'https://daily.jstor.org/feed/',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.aeon,
    name: 'Aeon',
    kind: DiscoverSourceKind.rss,
    category: DiscoverCategory.blogs,
    topics: {
      DiscoverTopic.history,
      DiscoverTopic.culture,
      DiscoverTopic.psychology,
      DiscoverTopic.science,
    },
    language: DiscoverSourceLanguage.english,
    descriptionEn: 'Essays on philosophy, psychology, science and culture',
    descriptionRu: 'Эссе о философии, психологии, науке и культуре',
    homeUrl: 'https://aeon.co/',
    feedUrl: 'https://aeon.co/essays.rss',
  ),
  DiscoverSource(
    id: DiscoverSourceIds.mongabay,
    name: 'Mongabay',
    kind: DiscoverSourceKind.rss,
    category: DiscoverCategory.blogs,
    topics: {DiscoverTopic.nature, DiscoverTopic.science},
    language: DiscoverSourceLanguage.english,
    descriptionEn:
        'Reporting on wildlife, forests, biodiversity and conservation',
    descriptionRu:
        'Живая природа, леса, биоразнообразие и охрана окружающей среды',
    homeUrl: 'https://news.mongabay.com/',
    feedUrl: 'https://news.mongabay.com/feed/',
  ),
];
