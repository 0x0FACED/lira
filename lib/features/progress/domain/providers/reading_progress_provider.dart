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

  @override
  FutureOr<ReadingProgressDto?> build(String arg) async {
    _repository = getIt<ReadingProgressLocalRepository>();
    return _repository.getProgress(arg);
  }

  Future<void> saveProgress({
    required String location,
    required double percentage,
  }) async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      final progress = ReadingProgressDto(
        bookId: arg, // arg is the bookId in FamilyAsyncNotifier
        percentage: percentage,
        location: location,
        updatedAt: DateTime.now(),
      );

      await _repository.saveProgress(progress);
      state = AsyncValue.data(progress);
    });
  }
}
