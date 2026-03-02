import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../data/repositories/highlights_local_repository.dart';
import '../models/highlight_dto.dart';

final highlightsControllerProvider =
    AsyncNotifierProvider.family<
      HighlightsController,
      List<HighlightDto>,
      String
    >(() {
      return HighlightsController();
    });

class HighlightsController
    extends FamilyAsyncNotifier<List<HighlightDto>, String> {
  late final HighlightsLocalRepository _repository;

  @override
  FutureOr<List<HighlightDto>> build(String arg) async {
    _repository = getIt<HighlightsLocalRepository>();
    return _repository.getHighlightsForBook(arg);
  }

  Future<void> addHighlight({
    required String text,
    required String location,
    String? note,
    String color = '#BB86FC',
  }) async {
    final highlight = HighlightDto(
      id: const Uuid().v4(),
      bookId: arg,
      text: text,
      color: color,
      location: location,
      note: note,
      createdAt: DateTime.now(),
    );

    await _repository.saveHighlight(highlight);
    state = await AsyncValue.guard(() => _repository.getHighlightsForBook(arg));
  }

  Future<void> updateNote(String highlightId, String? note) async {
    await _repository.updateHighlightNote(highlightId, note);
    state = await AsyncValue.guard(() => _repository.getHighlightsForBook(arg));
  }

  Future<void> removeHighlight(String highlightId) async {
    await _repository.deleteHighlight(highlightId);
    state = await AsyncValue.guard(() => _repository.getHighlightsForBook(arg));
  }
}
