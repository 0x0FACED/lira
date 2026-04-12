import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../data/repositories/reading_progress_local_repository.dart';
import '../models/reading_progress_dto.dart';

final readingProgressControllerProvider =
    AsyncNotifierProvider.family<
      ReadingProgressController,
      ReadingProgressDto?,
      String
    >(() {
      return ReadingProgressController();
    });

class ReadingProgressController
    extends FamilyAsyncNotifier<ReadingProgressDto?, String> {
  late final ReadingProgressLocalRepository _repository;
  Timer? _debounceTimer;
  ReadingProgressDto? _pendingProgress;

  @override
  FutureOr<ReadingProgressDto?> build(String arg) async {
    _repository = getIt<ReadingProgressLocalRepository>();
    ref.onDispose(() {
      _debounceTimer?.cancel();
      final pendingProgress = _pendingProgress;
      if (pendingProgress != null) {
        unawaited(_repository.saveProgress(pendingProgress));
      }
    });
    return _repository.getProgress(arg);
  }

  Future<void> saveProgress({
    required String location,
    required double percentage,
  }) async {
    _debounceTimer?.cancel();
    final progress = ReadingProgressDto(
      bookId: arg, // arg is the bookId in FamilyAsyncNotifier
      percentage: percentage,
      location: location,
      updatedAt: DateTime.now(),
    );
    _pendingProgress = progress;

    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      final pendingProgress = _pendingProgress;
      if (pendingProgress == null) return;

      await _repository.saveProgress(pendingProgress);
      state = AsyncValue.data(pendingProgress);
      _pendingProgress = null;
    });
  }
}
