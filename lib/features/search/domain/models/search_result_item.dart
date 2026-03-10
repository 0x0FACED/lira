import 'package:annas_archive_api/annas_archive_api.dart' as anna;
import 'package:zlibrary_api/zlibrary_api.dart';

enum SearchResultSource {
  anna,
  zlibrary,
}

class SearchResultItem {
  final String id;
  final String title;
  final String author;
  final String format;
  final String size;
  final String imgUrl;
  final SearchResultSource source;
  final dynamic originalObject;

  const SearchResultItem({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.size,
    required this.imgUrl,
    required this.source,
    required this.originalObject,
  });

  factory SearchResultItem.fromAnnaBook(anna.Book book) {
    return SearchResultItem(
      id: book.md5,
      title: book.title,
      author: book.author,
      format: book.format.extension,
      size: book.size,
      imgUrl: book.imgUrl,
      source: SearchResultSource.anna,
      originalObject: book,
    );
  }

  factory SearchResultItem.fromZLibraryBook(ZLibraryBook book) {
    return SearchResultItem(
      id: book.id,
      title: book.title,
      author: book.author,
      format: book.extension.toLowerCase(),
      size: book.size,
      imgUrl: book.imgUrl,
      source: SearchResultSource.zlibrary,
      originalObject: book,
    );
  }
}
