import 'dart:async';
import 'package:flutter/foundation.dart';
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
  Future<void>? _writeFuture;
  bool _disposed = false;

  @override
  FutureOr<ReadingProgressDto?> build(String arg) async {
    _repository = getIt<ReadingProgressLocalRepository>();
    ref.onDispose(() {
      _disposed = true;
      _debounceTimer?.cancel();
      unawaited(
        flush().catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'Lira progress',
              context: ErrorDescription(
                'while flushing a disposed progress controller',
              ),
            ),
          );
        }),
      );
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

    _debounceTimer = Timer(const Duration(seconds: 1), () {
      unawaited(
        flush().catchError((Object error, StackTrace stack) {
          if (!_disposed) {
            state = AsyncValue<ReadingProgressDto?>.error(error, stack)
                .copyWithPrevious(
                  AsyncValue.data(_pendingProgress ?? state.valueOrNull),
                );
          }
        }),
      );
    });
  }

  /// Persists the latest position before leaving or suspending the reader.
  /// Writes are serialized so a slow older write cannot overwrite a newer one.
  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    while (true) {
      final inFlight = _writeFuture;
      if (inFlight != null) {
        await inFlight;
        continue;
      }
      if (_pendingProgress == null) return;

      final write = _persistPending();
      _writeFuture = write;
      try {
        await write;
      } finally {
        _writeFuture = null;
      }
    }
  }

  Future<void> _persistPending() async {
    while (_pendingProgress != null) {
      final progress = _pendingProgress!;
      _pendingProgress = null;
      try {
        await _repository.saveProgress(progress);
      } catch (_) {
        _pendingProgress ??= progress;
        rethrow;
      }
      if (!_disposed) state = AsyncValue.data(progress);
    }
  }
}
