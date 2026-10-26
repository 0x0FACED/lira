import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../data/repositories/bookmarks_local_repository.dart';
import '../models/bookmark_dto.dart';

final bookmarksControllerProvider =
    AsyncNotifierProvider.family<
      BookmarksController,
      List<BookmarkDto>,
      String
    >(() {
      return BookmarksController();
    });

class BookmarksController
    extends FamilyAsyncNotifier<List<BookmarkDto>, String> {
  late final BookmarksLocalRepository _repository;

  @override
  FutureOr<List<BookmarkDto>> build(String arg) async {
    _repository = getIt<BookmarksLocalRepository>();
    return _repository.getBookmarksForBook(arg);
  }

  Future<void> addBookmark({
    required String location,
    required double percentage,
  }) async {
    final bookmark = BookmarkDto(
      id: const Uuid().v4(),
      bookId: arg,
      location: location,
      percentage: percentage,
      createdAt: DateTime.now(),
    );

    await _repository.saveBookmark(bookmark);
    state = AsyncValue.data(await _repository.getBookmarksForBook(arg));
  }

  Future<void> removeBookmark(String id) async {
    await _repository.deleteBookmark(id);
    state = AsyncValue.data(await _repository.getBookmarksForBook(arg));
  }
}
