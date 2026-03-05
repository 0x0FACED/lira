# Здесь содержится описание API библиотеки Anna's Archive

Пример использования из официального pub.dev:

```dart
import 'package:annas_archive_api/annas_archive_api.dart';

Future<void> main() async {
  // Finds books from Anna's Archive.
  await AnnaApi()
      .find(
        const SearchRequest(
          query: 'harry potter',
          author: 'rowling',
          categories: [Category.fiction],
          sources: [AnnaSource.zLibrary, AnnaSource.internetArchive],
          formats: [Format.epub, Format.pdf],

          language: Language.french,
          sort: SortOption.smallest,
        ),
      )
      .then((response) async {
        for (final Book book in response.books) {
          print(book.title);
        }

        // Get download links for a book.
        await AnnaApi().getDownloadLinks(response.books.first.md5).then((
          downloadLinks,
        ) {
          for (final String link in downloadLinks) {
            print(link);
          }
        });
      });

  // Finds journals from Anna's Archive.
  await AnnaApi()
      .findJournal(
        const SearchJournalRequest(
          query: '',
          language: Language.french,
          sources: [AnnaSource.libgenLi],
          sort: SortOption.newest,
        ),
      )
      .then((response) {
        for (final Book book in response.books) {
          print(book.title);
        }
      });
}
```

Доступные форматы книг, языки, сортировки, категории и источники:

```dart
/// Represents the file-extension of the book
enum Format {
  // TODO(Alvyn): Add more formats
  unknown(''),
  mobi('mobi'),
  azw3('azw3'),
  pdf('pdf'),
  epub('epub');

  const Format(this.extension);

  final String extension;

  static Format fromString(String value) {
    if (value == Format.pdf.extension) {
      return Format.pdf;
    }
    if (value == Format.epub.extension) {
      return Format.epub;
    }

    if (value == Format.mobi.extension) {
      return Format.mobi;
    }

    if (value == Format.azw3.extension) {
      return Format.azw3;
    }

    return Format.unknown;
  }
}

/// Represents the language of the book
enum Language {
  english('en'),
  german('de'),
  chinese('zh'),
  spanish('es'),
  korean('ko'),
  french('fr'),
  russian('ru'),
  italian('it'),
  arabic('ar'),
  portuguese('pt'),
  japanese('ja'),
  latin('la'),
  indonesian('id'),
  polish('pl'),
  dutch('nl'),
  hebrew('he'),
  hungarian('hu'),
  bangla('bn'),
  hindi('hi'),
  afrikaans('af'),
  thai('th'),
  tamil('ta'),
  czech('cs'),
  turkish('tr'),
  romanian('ro'),
  greek('el'),
  lithuanian('lt'),
  swedish('sv'),
  persian('fa'),
  vietnamese('vi'),
  fininish('fi'),
  gujarati('gu'),
  kinyarwanda('rw'),
  azerbaijani('az'),
  bulgarian('bg'),
  ukrainian('uk'),
  catalan('ca'),
  irish('ga'),
  latvian('lv'),
  kannada('kn'),
  serbian('sr'),
  tiebetan('bo'),
  danish('da'),
  croatian('hr'),
  slovak('sk'),
  javanese('jv'),
  urdu('ur'),
  norwegian('no'),
  belarusian('be'),
  kazakh('kk'),
  mongolian('mn'),
  georgian('ka'),
  slovenian('sl'),
  esperanto('eo'),
  galician('gl'),
  marathi('mr'),
  filipino('tl'),
  malayalam('ml'),
  kyrgyz('ky'),
  quechua('qu'),
  swahili('sw'),
  bashkir('ba'),
  punjabi('pa'),
  malay('ms'),
  teleugu('te'),
  albanian('sq'),
  uyghur('ug'),
  armenian('hy'),
  shan('shn');

  const Language(this.code);

  final String code;

  static Language fromString(String value) {
    if (value == Language.french.code) {
      return Language.french;
    }
    if (value == Language.german.code) {
      return Language.german;
    }
    if (value == Language.italian.code) {
      return Language.italian;
    }
    if (value == Language.spanish.code) {
      return Language.spanish;
    }

    return Language.english;
  }
}

/// Represents the sorting option for the search results
enum SortOption {
  newest('newest'),
  oldest('oldest'),
  largest('largest'),
  smallest('smallest'),
  mostRelevant('');

  const SortOption(this.value);

  final String value;

  static SortOption fromString(String value) {
    if (value == SortOption.newest.value) {
      return SortOption.newest;
    }
    if (value == SortOption.oldest.value) {
      return SortOption.oldest;
    }
    if (value == SortOption.largest.value) {
      return SortOption.largest;
    }
    if (value == SortOption.smallest.value) {
      return SortOption.smallest;
    }

    return SortOption.mostRelevant;
  }
}

/// Represents the category of the book
enum Category {
  invalid(apiName: '', domainName: 'invalid'),
  fiction(apiName: 'book_fiction', domainName: 'fiction'),
  nonfiction(apiName: 'book_nonfiction', domainName: 'nonfiction'),
  comic(apiName: 'book_comic', domainName: 'comic'),
  unknown(apiName: 'book_unknown', domainName: 'unknown'),
  magazine(apiName: 'magazine', domainName: 'magazine'),
  other(apiName: 'other', domainName: 'other'),
  musicalScore(apiName: 'musical_score', domainName: 'musicalScore');

  const Category({required this.apiName, required this.domainName});

  final String apiName;
  final String domainName;

  String get _apiNameLowerCase => apiName.toLowerCase();
  String get _domainNameLowerCase => domainName.toLowerCase();

  static Category fromDomainString(String value) {
    final lowerCaseValue = value.toLowerCase();

    if (lowerCaseValue == Category.comic._domainNameLowerCase) {
      return Category.comic;
    }
    if (lowerCaseValue == Category.fiction._domainNameLowerCase) {
      return Category.fiction;
    }
    if (lowerCaseValue == Category.magazine._domainNameLowerCase) {
      return Category.magazine;
    }
    if (lowerCaseValue == Category.nonfiction._domainNameLowerCase) {
      return Category.nonfiction;
    }
    if (lowerCaseValue == Category.musicalScore._domainNameLowerCase) {
      return Category.musicalScore;
    }
    if (lowerCaseValue == Category.other._domainNameLowerCase) {
      return Category.other;
    }
    if (lowerCaseValue == Category.unknown._domainNameLowerCase) {
      return Category.unknown;
    }

    return Category.invalid;
  }

  static Category fromApiString(String value) {
    final lowerCaseValue = value.toLowerCase();

    if (lowerCaseValue == Category.comic._apiNameLowerCase) {
      return Category.comic;
    }
    if (lowerCaseValue == Category.fiction._apiNameLowerCase) {
      return Category.fiction;
    }
    if (lowerCaseValue == Category.magazine._apiNameLowerCase) {
      return Category.magazine;
    }
    if (lowerCaseValue == Category.nonfiction._apiNameLowerCase) {
      return Category.nonfiction;
    }
    if (lowerCaseValue == Category.musicalScore._apiNameLowerCase) {
      return Category.musicalScore;
    }
    if (lowerCaseValue == Category.other._apiNameLowerCase) {
      return Category.other;
    }
    if (lowerCaseValue == Category.unknown._apiNameLowerCase) {
      return Category.unknown;
    }

    return Category.invalid;
  }
}

/// Represents the source of the book
enum AnnaSource {
  invalid(apiName: '', domainName: 'invalid'),
  libgenLi(apiName: 'lgli', domainName: 'libgenLi'),
  libgenRs(apiName: 'lgrs', domainName: 'libgenRs'),
  zLibrary(apiName: 'zlib', domainName: 'zLibrary'),
  internetArchive(apiName: 'ia', domainName: 'internetArchive'),
  uploads(apiName: 'upload', domainName: 'uploads'),
  nexusStc(apiName: 'nexusstc', domainName: 'nexusStc'),
  duxiu(apiName: 'duxiu', domainName: 'duxiu'),
  zLibraryChinese(apiName: 'zlibzh', domainName: 'zLibraryChinese'),
  magzDb(apiName: 'magzdb', domainName: 'magzDb'),
  sciHub(apiName: 'scihub', domainName: 'sciHub');

  const AnnaSource({required this.apiName, required this.domainName});

  final String apiName;
  final String domainName;

  String get _apiNameLowerCase => apiName.toLowerCase();
  String get _domainNameLowerCase => domainName.toLowerCase();

  static AnnaSource fromDomainString(String value) {
    final lowerCaseValue = value.toLowerCase();

    if (lowerCaseValue == AnnaSource.libgenLi._domainNameLowerCase) {
      return AnnaSource.libgenLi;
    }

    if (lowerCaseValue == AnnaSource.libgenRs._domainNameLowerCase) {
      return AnnaSource.libgenRs;
    }

    if (lowerCaseValue == AnnaSource.zLibrary._domainNameLowerCase) {
      return AnnaSource.zLibrary;
    }

    if (lowerCaseValue == AnnaSource.internetArchive._domainNameLowerCase) {
      return AnnaSource.internetArchive;
    }

    if (lowerCaseValue == AnnaSource.uploads._domainNameLowerCase) {
      return AnnaSource.uploads;
    }

    if (lowerCaseValue == AnnaSource.nexusStc._domainNameLowerCase) {
      return AnnaSource.nexusStc;
    }

    if (lowerCaseValue == AnnaSource.duxiu._domainNameLowerCase) {
      return AnnaSource.duxiu;
    }

    if (lowerCaseValue == AnnaSource.zLibraryChinese._domainNameLowerCase) {
      return AnnaSource.zLibraryChinese;
    }

    if (lowerCaseValue == AnnaSource.magzDb._domainNameLowerCase) {
      return AnnaSource.magzDb;
    }

    if (lowerCaseValue == AnnaSource.sciHub._domainNameLowerCase) {
      return AnnaSource.sciHub;
    }

    return AnnaSource.invalid;
  }

  static AnnaSource fromApiString(String value) {
    final lowerCaseValue = value.toLowerCase();

    if (lowerCaseValue == AnnaSource.libgenLi._apiNameLowerCase) {
      return AnnaSource.libgenLi;
    }

    if (lowerCaseValue == AnnaSource.libgenRs._apiNameLowerCase) {
      return AnnaSource.libgenRs;
    }

    if (lowerCaseValue == AnnaSource.zLibrary._apiNameLowerCase) {
      return AnnaSource.zLibrary;
    }

    if (lowerCaseValue == AnnaSource.internetArchive._apiNameLowerCase) {
      return AnnaSource.internetArchive;
    }

    if (lowerCaseValue == AnnaSource.uploads._apiNameLowerCase) {
      return AnnaSource.uploads;
    }

    if (lowerCaseValue == AnnaSource.nexusStc._apiNameLowerCase) {
      return AnnaSource.nexusStc;
    }

    if (lowerCaseValue == AnnaSource.duxiu._apiNameLowerCase) {
      return AnnaSource.duxiu;
    }

    if (lowerCaseValue == AnnaSource.zLibraryChinese._apiNameLowerCase) {
      return AnnaSource.zLibraryChinese;
    }

    if (lowerCaseValue == AnnaSource.magzDb._apiNameLowerCase) {
      return AnnaSource.magzDb;
    }

    return AnnaSource.invalid;
  }
}
```

Класс книги:

```dart
import 'package:annas_archive_api/src/enums.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book.freezed.dart';
part 'book.g.dart';

@freezed
abstract class Book with _$Book {
  const factory Book({
    required String title,
    required String author,
    required String md5,
    required String imgUrl,
    required String size,
    required String genre,
    required Format format,
    String? year,
    String? imgFallbackColor,
    @Default([]) List<String> sources,
  }) = _Book;

  factory Book.fromJson(Map<String, Object?> json) => _$BookFromJson(json);
}
```