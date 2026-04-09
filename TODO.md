# Lira - Library Reader App: Project TODO

## Phase 1: Project Setup & Core
- [x] Initialize project with base dependencies.
- [x] Create base feature-first directory structure (`lib/core`, `lib/features`).
- [x] Setup dependency injection (`injectable` + `get_it`).
- [x] Setup root `ProviderScope` for Riverpod in `main.dart`.
- [x] Setup basic app routing (`go_router`).
- [x] Setup base theme (Dark mode by default, `#121212`, `#BB86FC`).
- [x] Set up localization (l10n).
- [x] Update README.md for this module.

## Phase 2: Core Data & API Contract
- [x] Define API client using `Dio` and `Retrofit`.
- [x] Create domain entities (`Book`, `ReadingProgress`, `Highlight`) with `freezed`.
- [x] Ensure all API DTOs use `snake_case` for JSON serialization.
- [x] Setup local database (`Drift`) with tables for Books, Progress, Highlights.
- [x] Update README.md for this module.

## Phase 3: Book Reader Engines
- [x] Fix error in main.dart with app localizations.
- [x] Define `BookReaderEngine` interface.
- [x] Create `packages/epub_engine` (based on `epub_view`).
- [x] Create `packages/pdf_engine` (based on `native_pdf_view`/`pdfx`).
- [x] Update README.md for this module.

## Phase 4: Books Library Feature
- [x] Implement file importer (EPUB/PDF) from device file system.
- [x] Save imported book metadata and cover to local Drift database.
- [x] Build Grid/List View for the library with Hero animations.
- [x] Update README.md for this module.

## Phase 5: Book Reader Feature
- [x] Fix error in books_provider.dart and library_screen.dart
- [x] Build reader screen encapsulating specific engine (EPUB/PDF).
- [x] Implement minimalist UI (hide panels on tap).
- [x] Save last read location and percentage to Drift on exit.
- [x] Add text highlighting and notes saving to local DB.
- [x] Update README.md for this module.

## Phase 5.1: Fix errors
- [x] Remove 3 buttons to add book - import book in the right up corner, add book in the right bottom corner, add bot at the center. Remain only import book in the right up corner.
- [x] No Such Interface if try to add book in Linux - Can't add book in Linux, file chooser doesn't work.
- [x] Cant build for java 17 - Could not determine java version from '17.0.18'.

## Phase 5.2: Fix errors
- [x] Cannot open book in Linux - No such interface. Make sure xdg-desktop-portal and xdg-desktop-portal-gtk are installed.
- [x] PDF doesn't open in Android - writing Openning "file.pdf" and nothing else. With EPUB the same issue.

Logs when tap on the book card:
```
I/MIUIInput(10314): [MotionEvent] ViewRootImpl windowName 'dev.u0xfaced.lira/dev.u0xfaced.lira.MainActivity', { action=ACTION_DOWN, id[0]=0, pointerCount=1, eventTime=1248321717, downTime=1248321717, phoneEventTime=16:00:08.509 } moveCount:0
D/VRI[MainActivity](10314): getMiuiFreeformStackInfo mTmpFrames.miuiFreeFormStackInfo: null
I/MIUIInput(10314): [MotionEvent] ViewRootImpl windowName 'dev.u0xfaced.lira/dev.u0xfaced.lira.MainActivity', { action=ACTION_UP, id[0]=0, pointerCount=1, eventTime=1248321774, downTime=1248321717, phoneEventTime=16:00:08.566 } moveCount:0
```

- [x] Author and cover are not displayed in the library.

## Phase 5.3: Fix errors
- [x] EPUB on Android has less than 2-3 fps - so many lags. PDF is fine, but swipe animation is strange - when turning the page halfway, the page immediately turns over abruptly.
- [x] Executed sudo pacman -S xdg-desktop-portal xdg-desktop-portal-gtk but the same error with file picker. We can just change file picker library maybe?
- [x] Bottom buttons in reader don't work.

## Phase 5.4: Fix errors
- [x] Not all EPUB opens in Linux:

```
[ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception: RangeError (length): Invalid value: Valid value range is empty: 0
#0      List.removeAt (dart:core-patch/growable_array.dart)
#1      NavigationReader.readNavigation (package:epubx/src/readers/navigation_reader.dart:138)
#2      SchemaReader.readSchema (package:epubx/src/readers/schema_reader.dart:22)
<asynchronous suspension>
#3      EpubReader.openBook (package:epubx/src/epub_reader.dart:64)
<asynchronous suspension>
#4      EpubReader.readBook (package:epubx/src/epub_reader.dart:85)
<asynchronous suspension>
```

- [x] EPUB Reader LAGS A LOT. Its unreal to read. Maybe use another library? Are there any alternatives?
- [x] Cant add PDF from linux - only EPUB can choose.
- [x] The progress doesn't save. When I close the book and open it again, it starts from the beginning.

## Phase 5.5: Fix errors
- [x] Cant open PDF on Linux:

```
[ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception: MissingPluginException(No implementation found for method open.document.data on channel io.scer.pdf_renderer)
#0      MethodChannel._invokeMethod (package:flutter/src/services/platform_channel.dart:365)
<asynchronous suspension>
#1      PdfxPlatformMethodChannel.openData (package:pdfx/src/renderer/io/platform_method_channel.dart:58)
<asynchronous suspension>
```

- [x] Maybe switch to flureadium? Or lets write universal reader. It will parse PDF and EPUB, extract text and all kinds of official information. We will render everything ourselves in our reader, simply embedding text, pictures, tables, and so on. Then you will get a unified interface in theory. It should then work on all platforms. If we choose this option, first make a plan in a file. READER.md.

## Phase 5.6: Fix errors

- [x] "Failed to parse this EPUB file: RangeError (length): Invalid value: Valid value range is empty: 0" in linux in EPUB files.
- [x] In pdf android reader cant hide top and bottom bars by clicking on the screen. Cant hide bars in epub too and in Linux.
- [x] In epub on Adnroid i can see text1.html, "nav" and another metadata.
- [x] In addition, the reader's content is stretched over the entire available screen on Android.
- [x] Some links in epub android doesn't work. Logs:

```
I/flutter ( 8240): [IMPORTANT:flutter/shell/platform/android/android_context_vk_impeller.cc(62)] Using the Impeller rendering backend (Vulkan).
I/flutter ( 8240): PdfDocument initial load: book.pdf (98 ms)
I/flutter ( 8240): PdfViewer: Loaded page 24 of 31 in 270 ms
I/flutter ( 8240): PdfViewer: Loaded page 31 of 31 in 370 ms
I/flutter ( 8240): Could not launch "copyright-page.xhtml": unsupported
I/flutter ( 8240): Could not launch "copyright-page.xhtml": unsupported
I/flutter ( 8240): Could not launch "copyright-page.xhtml": unsupported
I/flutter ( 8240): Could not launch "copyright-page.xhtml": unsupported
I/flutter ( 8240): Could not launch "copyright-page.xhtml": unsupported
I/flutter ( 8240): Could not launch "copyright-page.xhtml": unsupported
I/flutter ( 8240): Could not launch "content-toc.xhtml": unsupported
I/flutter ( 8240): Could not launch "content-toc.xhtml": unsupported
I/flutter ( 8240): Could not launch "ch03.html#ch_datamodels": unsupported
I/flutter ( 8240): Could not launch "ch03.html#ch_datamodels": unsupported
I/flutter ( 8240): Could not launch "ch03.html#ch_datamodels": unsupported
```
- [x] The EPUB rendering is weird. Swipe down and up on the content of the chapter, and left and right on the chapters themselves. That is, as I understand it, the entire chapter is being rendered at once, we can scroll it up and down. To open other chapters, swipe left or right.
- [x] Need to add a progress bar in the pages.

## Phase 6: Search Feature

У нас есть экран поиск, но сейчас он не работает. Есть библиотека: https://pub.dev/packages/annas_archive_api. Мы будем вокруг нее строить наш поиск. Будем использовать последнюю версию: 1.1.0.

- [x] Сначала нам надо добавить саму кнопку поиска на экран поиск. При нажатии на нее раскрывается строка для ввода текста по аналогии с поиском среди книг на главной странице (Библиотеке). Поиск должен быть по названию, автору или ISBN. Поиск по нажатию на кнопку ввода (Enter на десктопе). Пока выполняется запрос, добавим индикатор загрузки.
- [x] Ожидаемый ответ: список книг, полученных в ответе. Нам нужен новый тип карточек. Это должна быть горизонтальная карточка с обложкой слева, названием, автором и другой информацией, а еще кнопкой загрузки справа (именно кнопка в виде иконки, БЕЗ НАДПИСИ). Стиль карточки такой же, как и на основном экране, разве что обложка будет квадратная (область под обложку хочу квадратную, а не прямоугольную). 
- [x] При скачивании появляется уведомление, что книга скачивается. Книга сразу добавляется в библиотеку со всей нужной информацией о ней. Если книга уже есть в библиотеке, то не добавлять, а говорить пользователю о том, что такая книга уже существует (проверять, существует ли книга, будет пока что по ТОЧНОМУ совпадению названия и автора).
- [x] Для отслеживания загрузки книги нужно добавить индикатор загрузки в карточку книги (в карточку, которая на странице поиска именно). Пускай это будет круговой индикатор загрузки, который будет отображаться поверх обложки книги. Обложка должна затеняться, индикатор будет поверх находиться, аналогично тому, как это в App Store сделано.

Небольшое описание библиотеки есть в файле `./ANNAS_ARCHIVE_API.md`. 

## Phase 7: EPUB Reader

- [x] Сейчас EPUB reader работает плохо. Например, прогресс трекается не сразу, а через 200 или 500мс с момента, как мы пролистнули дальше. Хочу исправить, чтобы прогресс трекался сразу по мере пролистывания.
- [x] В EPUB ридере нельзя выделять текст и как-либо с ним взаимодействовать. В будущем планируется добавлять highlights, заметки, выполнять поиск в epub. Надо сделать так, чтобы текст можно было выделять при, например, долгом удерживании на слове, как это везде работает.
- [x] EPUB парсится неправильно. Например, я запарсил книгу из 10+ глав, однако у меня после первой главы идет опять первая глава. И так все главы заменены на первую. То есть первая глава только парится как будто, а остальные нет.
- [x] В нижней панели в epub reader у нас есть TOC и настройки. Хочется с ними поработать. При нажатии на TOC слева выезжает оглавление кликабельное - можно переместиться куда захотим по нажатию. В настройках можно будет менять шрифт, размер шрифта, цвет фона, отступы и т.д. Все это необходимо сохранять будет в локальное хранилище юзера, чтобы при повторном открытии любогй epub книги настройки применялись.

---

# New Tasks (added 2026-04-09)

## Phase 8: macOS — критические проблемы

- [x] **[CRITICAL]** Добавить entitlement `com.apple.security.files.user-selected.read-write` в `macos/Runner/DebugProfile.entitlements` и `Release.entitlements`. Без него file picker не работает в sandbox — кнопка импорта книг не реагирует.
- [x] **[CRITICAL]** Добавить entitlement `com.apple.security.network.client` в оба entitlements файла. Без него исходящие HTTP-запросы блокируются sandbox — поиск книг не работает. (Сейчас в DebugProfile есть только `network.server`, в Release — ничего.)

## Phase 9: Reader — темы и цвета

Сейчас при смене фона в настройках ридера меняется только `backgroundColor`. Контент никак не адаптируется:

- [ ] **[HIGH]** EPUB: цвет текста берётся из `theme.colorScheme.onSurface` (глобальная тема приложения), а не вычисляется от фона ридера. При светлом фоне (#F5F5F5) + тёмной теме приложения → белый текст на белом фоне. Нужно вычислять цвет текста по luminance фона: `bgColor.computeLuminance() > 0.5 ? black : white`.
- [ ] **[HIGH]** EPUB: ссылки используют тот же цвет, что и текст (`color: $textColorStr`). Нужно выделять ссылки отдельным цветом (accent) с учётом контраста.
- [ ] **[MEDIUM]** PDF: `PdfViewerWidget` только оборачивает контент в `Container(color: backgroundColor)`, но содержимое PDF не адаптируется. Исследовать возможности `pdfrx` для color overlay / blend mode.
- [ ] **[MEDIUM]** EPUB: картинки не фильтруются при тёмном фоне (яркие изображения бьют по глазам). Добавить CSS `filter: brightness(0.8)` или инвертацию для тёмных тем.
- [ ] **[LOW]** Top/bottom bars ридера захардкожены в `Colors.black87` — не адаптируются к фону.

## Phase 10: Security (was 8)

- [ ] **[CRITICAL]** Убрать глобальный SSL bypass (`MyHttpOverrides` в `main.dart`). `badCertificateCallback` принимает все сертификаты — уязвимость для MITM атак. Оставить только для dev-режима или убрать полностью.
- [ ] Перенести Z-Library креды (email, cookies) из `SharedPreferences` в `flutter_secure_storage`. Сейчас хранятся в plaintext.
- [ ] Добавить input sanitization в диалог редактирования книги (`book_detail_screen.dart`).

## Phase 11: Localization (i18n)

~40% строк в UI захардкожены на английском. Нужно перенести в ARB файлы:

- [ ] `book_card.dart` — 'Delete Book', 'Are you sure...', 'Cancel', 'Delete'.
- [ ] `reader_screen.dart` — 'Table of Contents', 'Settings', 'Contents', 'Table of Contents is not available.'
- [ ] `settings_panel.dart` — 'Reader Settings', 'Reset to default', 'Reading Mode', 'Vertical', 'Horizontal', 'Font Family', названия шрифтов.
- [ ] `search_screen.dart` — 'No results found', описания источников, help text.
- [ ] `search_book_card.dart` — '... downloaded and added to library.', 'Cancel download'.
- [ ] `book_detail_screen.dart` — диалоговые строки.
- [ ] `library_screen.dart` — сообщения об ошибках (сейчас показывается raw `$e`).

## Phase 12: Architecture & Code Quality

- [ ] Разбить `BooksController` (`books_provider.dart`, 465 строк) на отдельные use-case провайдеры: `ImportBookUseCase`, `DownloadBookUseCase`, `DeleteBookUseCase`.
- [ ] Вынести бизнес-логику из UI виджетов:
  - `book_detail_screen.dart` — `_showEditDialog()` содержит логику обновления.
  - `settings_screen.dart` — `_showZLibraryLoginDialog()` напрямую вызывает `ZLibraryApi()`.
  - `library_screen.dart` — логика фильтрации в UI.
- [ ] Заменить все `print()` на нормальный логгер (например, `logger` или `logging`). Сейчас в `books_provider.dart` ~15 вызовов `print()` с `// ignore: avoid_print`.
- [ ] Унифицировать обработку ошибок: часть экранов использует `try/catch`, часть — provider error states. Выбрать один подход.
- [ ] Добавить проверку `context.mounted` перед UI-обновлениями после async операций в `reader_screen.dart`.
- [ ] Оптимизировать `SearchBookCard` — использовать `ref.watch(provider.select(...))` вместо подписки на весь `downloadNotifierProvider`.

## Phase 13: UX Improvements

- [ ] Добавить retry/resume для прерванных загрузок.
- [ ] Добавить пагинацию результатов поиска (сейчас все результаты в одном списке).
- [ ] Добавить debounce на поиск в библиотеке (`library_screen.dart`).
- [ ] Показывать user-friendly ошибки вместо raw exception (`$e`) в SnackBar.
- [ ] Добавить экспорт highlights (в текст/markdown).

## Phase 14: API & Backend Prep

- [ ] Перенести `baseUrl` из `dio_module.dart` в конфиг/env файл (сейчас захардкожен `localhost:8080`).
- [ ] Реализовать реальные API вызовы в `auth_provider.dart` (login/register — сейчас заглушки с `// TODO: Call auth API`).

## Phase X (not soon): Desktop WebView

EPUB ридер использует `webview_flutter` + `webview_flutter_wkwebview`. На десктопах WebView может работать нестабильно:

- [ ] Протестировать и пофиксить WebView на Windows (возможны проблемы с WebView2 runtime).
- [ ] Протестировать WebView на Linux (требуется webkit2gtk).
- [ ] Рассмотреть fallback рендеринг EPUB без WebView для десктопов (например, через `flutter_widget_from_html` напрямую).

## Phase X (not soon): Sync Feature (Go Server Backend)
- [ ] Setup authorization flow (login/register to API).
- [ ] Implement books metadata sync (Pull/Push).
- [ ] Implement reading progress and notes sync (Conflict resolution by `updated_at`).
- [ ] Update README.md for this module.
