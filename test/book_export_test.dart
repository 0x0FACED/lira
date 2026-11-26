import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/books/domain/models/book_dto.dart';
import 'package:lira/features/books/presentation/book_export.dart';
import 'package:lira/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

class _SaveLocation extends FileSelectorPlatform {
  String? path;
  String? suggestedName;
  List<XTypeGroup>? types;
  int calls = 0;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    calls++;
    suggestedName = options.suggestedName;
    types = acceptedTypeGroups;
    return path == null ? null : FileSaveLocation(path!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const desktopPlatform = TargetPlatformVariant({TargetPlatform.windows});
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const clipboardChannel = MethodChannel('dev.0xfaced.lira/file_clipboard');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const bytes = [80, 75, 3, 4, 0, 255, 128, 10];
  late Directory directory;
  late File source;
  late BookDto book;
  late _SaveLocation selector;
  late FileSelectorPlatform previousSelector;
  Map<String, dynamic>? shared;
  List<int>? sharedBytes;
  String? sharePath;
  bool failSharing = false;
  bool failClipboard = false;
  String? copiedFile;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lira-export-test-');
    source = await File(
      p.join(directory.path, 'library-id.epub'),
    ).writeAsBytes(bytes);
    book = BookDto(
      id: 'book',
      title: 'A book: its story',
      format: 'epub',
      fileUrl: source.path,
      createdAt: DateTime(2026),
    );
    previousSelector = FileSelectorPlatform.instance;
    selector = _SaveLocation();
    FileSelectorPlatform.instance = selector;
    shared = null;
    sharedBytes = null;
    sharePath = null;
    failSharing = false;
    failClipboard = false;
    copiedFile = null;
    messenger.setMockMethodCallHandler(clipboardChannel, (call) async {
      expect(call.method, 'copyFile');
      if (failClipboard) throw PlatformException(code: 'clipboard_failed');
      copiedFile = call.arguments as String;
      return null;
    });
    messenger.setMockMethodCallHandler(pathChannel, (call) async {
      if (call.method == 'getTemporaryDirectory') return directory.path;
      throw StateError('Unexpected path-provider call: ${call.method}');
    });
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      expect(call.method, 'share');
      if (failSharing) throw PlatformException(code: 'share_failed');
      shared = Map<String, dynamic>.from(call.arguments as Map);
      sharePath = (shared!['paths'] as List).single as String;
      sharedBytes = await File(sharePath!).readAsBytes();
      return ''; // Dismissal is not a completed export.
    });
  });

  tearDown(() async {
    FileSelectorPlatform.instance = previousSelector;
    messenger.setMockMethodCallHandler(shareChannel, null);
    messenger.setMockMethodCallHandler(pathChannel, null);
    messenger.setMockMethodCallHandler(clipboardChannel, null);
    await directory.delete(recursive: true);
  });

  Future<void> exportFromButton(
    WidgetTester tester, {
    BookDto? selectedBook,
    Rect? origin,
    bool clipboard = false,
  }) async {
    Future<void>? exporting;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                final selected = selectedBook ?? book;
                exporting = clipboard
                    ? copyBookToClipboard(context, selected)
                    : exportBook(context, selected, shareOrigin: origin);
              },
              child: Text(
                clipboard
                    ? AppLocalizations.of(context)!.bookCopyFile
                    : bookExportActionLabel(context),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byType(TextButton));
      await exporting;
    });
    await tester.pump();
  }

  testWidgets(
    'desktop saves the original bytes with a readable filename',
    (tester) async {
      selector.path = p.join(directory.path, 'saved.epub');
      await exportFromButton(tester);
      expect(find.widgetWithText(TextButton, 'Save a copy'), findsOneWidget);
      expect(selector.suggestedName, 'A book_ its story.epub');
      expect(selector.types!.single.extensions, ['epub']);
      expect(selector.types!.single.mimeTypes, ['application/epub+zip']);
      await tester.runAsync(() async {
        expect(await File(selector.path!).readAsBytes(), bytes);
        expect(await source.readAsBytes(), bytes);
      });
      expect(find.byType(SnackBar), findsOneWidget);
      expect(shared, isNull);
    },
    variant: desktopPlatform,
  );

  testWidgets(
    'copy to clipboard offers the existing file without changing it',
    (tester) async {
      await exportFromButton(tester, clipboard: true);
      expect(copiedFile, source.absolute.path);
      expect(selector.calls, 0);
      await tester.runAsync(() async {
        expect(await source.readAsBytes(), bytes);
        expect(await directory.list().map((entry) => entry.path).toList(), [
          source.path,
        ]);
      });
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TextButton)),
      )!;
      expect(find.text(l10n.bookFileCopied), findsOneWidget);
    },
    variant: desktopPlatform,
  );

  testWidgets(
    'failed file clipboard write does not report success',
    (tester) async {
      failClipboard = true;
      await exportFromButton(tester, clipboard: true);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TextButton)),
      )!;
      expect(find.text(l10n.bookCopyFileError), findsOneWidget);
      expect(find.text(l10n.bookFileCopied), findsNothing);
    },
    variant: desktopPlatform,
  );

  testWidgets(
    'canceling Save As is silent and leaves the source alone',
    (tester) async {
      await exportFromButton(tester);
      expect(selector.calls, 1);
      expect(find.byType(SnackBar), findsNothing);
      await tester.runAsync(() async {
        expect(await source.readAsBytes(), bytes);
        expect(await directory.list().length, 1);
      });
    },
    variant: desktopPlatform,
  );

  testWidgets(
    'saving over the original is rejected without modifying it',
    (tester) async {
      selector.path = source.path;
      await exportFromButton(tester);
      final context = tester.element(find.byType(TextButton));
      expect(
        find.text(AppLocalizations.of(context)!.bookExportSameFile),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        expect(await source.readAsBytes(), bytes);
      });
    },
    variant: desktopPlatform,
  );

  testWidgets(
    'saving through an alias of the original is also rejected',
    (tester) async {
      final alias = Link(p.join(directory.path, 'alias.epub'));
      await tester.runAsync(() => alias.create(source.path));
      selector.path = alias.path;
      await exportFromButton(tester);
      final context = tester.element(find.byType(TextButton));
      expect(
        find.text(AppLocalizations.of(context)!.bookExportSameFile),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        expect(await source.readAsBytes(), bytes);
      });
    },
    skip: Platform.isWindows,
    variant: desktopPlatform,
  );

  testWidgets(
    'a linked source cannot be exported over its target',
    (tester) async {
      final alias = Link(p.join(directory.path, 'source-alias.epub'));
      await tester.runAsync(() => alias.create(source.path));
      selector.path = source.path;
      await exportFromButton(
        tester,
        selectedBook: book.copyWith(fileUrl: alias.path),
      );
      final context = tester.element(find.byType(TextButton));
      expect(
        find.text(AppLocalizations.of(context)!.bookExportSameFile),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        expect(await source.readAsBytes(), bytes);
      });
    },
    skip: Platform.isWindows,
    variant: desktopPlatform,
  );

  testWidgets(
    'missing source reports a useful error before opening a picker',
    (tester) async {
      await exportFromButton(
        tester,
        selectedBook: book.copyWith(fileUrl: '${source.path}.missing'),
      );
      expect(selector.calls, 0);
      final context = tester.element(find.byType(TextButton));
      expect(
        find.text(AppLocalizations.of(context)!.bookExportFileMissing),
        findsOneWidget,
      );
    },
    variant: desktopPlatform,
  );

  testWidgets('copy failure is an error, never a success', (tester) async {
    selector.path = p.join(directory.path, 'missing', 'saved.epub');
    await exportFromButton(tester);
    final context = tester.element(find.byType(TextButton));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.bookExportError), findsOneWidget);
    expect(find.text(l10n.bookExportSaved(selector.path!)), findsNothing);
    await tester.runAsync(() async {
      expect(await source.readAsBytes(), bytes);
    });
  }, variant: desktopPlatform);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform shares a real EPUB and dismissal is silent',
      (tester) async {
        const origin = Rect.fromLTWH(20, 30, 40, 50);
        await exportFromButton(tester, origin: origin);
        expect(find.widgetWithText(TextButton, 'Share'), findsOneWidget);
        expect(selector.calls, 0);
        expect(p.basename(sharePath!), 'A book_ its story.epub');
        expect(sharedBytes, bytes);
        expect(shared!['mimeTypes'], ['application/epub+zip']);
        expect(shared!['originX'], origin.left);
        expect(shared!['originY'], origin.top);
        expect(shared!['originWidth'], origin.width);
        expect(shared!['originHeight'], origin.height);
        expect(find.byType(SnackBar), findsNothing);
        await tester.runAsync(() async {
          expect(await source.readAsBytes(), bytes);
          expect(await File(sharePath!).exists(), isFalse);
        });
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets(
    'iPad PDF sharing supplies a nonzero fallback anchor',
    (tester) async {
      await exportFromButton(
        tester,
        selectedBook: book.copyWith(title: 'A PDF.pdf', format: 'PDF'),
      );
      expect(p.basename(sharePath!), 'A PDF.pdf');
      expect(sharedBytes, bytes);
      expect(shared!['mimeTypes'], ['application/pdf']);
      expect(shared!['originWidth'], greaterThan(0));
      expect(shared!['originHeight'], greaterThan(0));
      expect(shared!['originX'], inInclusiveRange(0, 800));
      expect(shared!['originY'], inInclusiveRange(0, 600));
      expect(find.byType(SnackBar), findsNothing);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'native share failure reports an error and cleans its copy',
    (tester) async {
      failSharing = true;
      await exportFromButton(tester);
      final context = tester.element(find.byType(TextButton));
      expect(
        find.text(AppLocalizations.of(context)!.bookExportError),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        expect(await source.readAsBytes(), bytes);
        expect(await directory.list().length, 1);
      });
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
