import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/core/di/injection.dart';
import 'package:lira/features/progress/data/repositories/reading_progress_local_repository.dart';
import 'package:lira/features/progress/domain/models/reading_progress_dto.dart';
import 'package:lira/features/progress/domain/providers/reading_progress_provider.dart';

class _ProgressStore implements ReadingProgressLocalRepository {
  ReadingProgressDto? persisted;
  final pending = <(ReadingProgressDto, Completer<void>)>[];

  @override
  Future<ReadingProgressDto?> getProgress(String bookId) async => persisted;

  @override
  Future<void> saveProgress(ReadingProgressDto progress) {
    final completion = Completer<void>();
    pending.add((progress, completion));
    return completion.future;
  }

  void completeWrite() {
    if (pending.isEmpty) return;
    final (progress, completion) = pending.removeAt(0);
    persisted = progress;
    completion.complete();
  }

  void failWrite() {
    final (_, completion) = pending.removeAt(0);
    completion.completeError(StateError('Storage unavailable'));
  }
}

void main() {
  late _ProgressStore store;
  late ProviderContainer container;
  late ReadingProgressController controller;
  var containerDisposed = false;

  setUp(() async {
    store = _ProgressStore();
    containerDisposed = false;
    getIt.registerSingleton<ReadingProgressLocalRepository>(store);
    container = ProviderContainer();
    await container.read(readingProgressControllerProvider('book').future);
    controller = container.read(
      readingProgressControllerProvider('book').notifier,
    );
  });

  tearDown(() async {
    if (!containerDisposed) container.dispose();
    while (store.pending.isNotEmpty) {
      store.completeWrite();
      await Future<void>.value();
    }
    await getIt.reset();
  });

  testWidgets(
    'a new position is not lost while the preceding write completes',
    (tester) async {
      await controller.saveProgress(location: 'chapter-one', percentage: 10);
      await tester.pump(const Duration(seconds: 1));
      await controller.saveProgress(location: 'chapter-two', percentage: 20);
      store.completeWrite();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      store.completeWrite();
      await tester.pump();
      expect(store.persisted?.location, 'chapter-two');
      expect(store.persisted?.percentage, 20);
    },
  );

  testWidgets('flush persists the position without waiting for debounce', (
    tester,
  ) async {
    await controller.saveProgress(location: 'last-paragraph', percentage: 73);
    final flushed = controller.flush();
    store.completeWrite();
    await tester.pump();
    await flushed;
    expect(store.persisted?.location, 'last-paragraph');
    expect(store.persisted?.percentage, 73);
  });

  testWidgets(
    'overlapping flushes wait for the latest position to be durable',
    (tester) async {
      await controller.saveProgress(location: 'older', percentage: 15);
      var finished = false;
      final first = controller.flush().then((_) => finished = true);
      await controller.saveProgress(location: 'newest', percentage: 40);
      final second = controller.flush();
      store.completeWrite();
      await tester.pump();
      expect(finished, isFalse);
      store.completeWrite();
      await tester.pump();
      await Future.wait([first, second]);
      expect(store.persisted?.location, 'newest');
      expect(store.persisted?.percentage, 40);
    },
  );

  testWidgets('a failed write retains the newest position for retry', (
    tester,
  ) async {
    await controller.saveProgress(location: 'older', percentage: 15);
    final failed = expectLater(controller.flush(), throwsStateError);
    await controller.saveProgress(location: 'newest', percentage: 40);
    store.failWrite();
    await tester.pump();
    await failed;
    final retried = controller.flush();
    store.completeWrite();
    await tester.pump();
    await retried;
    expect(store.persisted?.location, 'newest');
    expect(store.persisted?.percentage, 40);
  });

  testWidgets('disposing before debounce preserves the pending position', (
    tester,
  ) async {
    await controller.saveProgress(location: 'before-exit', percentage: 55);
    container.dispose();
    containerDisposed = true;
    store.completeWrite();
    await tester.pump();
    expect(store.persisted?.location, 'before-exit');
    expect(store.persisted?.percentage, 55);
  });
}
