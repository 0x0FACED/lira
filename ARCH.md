# Lira — Architecture Documentation

> **Purpose:** New developers should read this file and immediately understand where to make changes for any given task.
> 
> **Last Updated:** March 9, 2026

---

## Quick Reference: Where to Make Changes

| Task Type | Files to Modify | Files to Avoid |
|-----------|-----------------|----------------|
| **Add new UI screen** | `lib/features/{feature}/presentation/` | `lib/core/router/` (only add route) |
| **Change app theme/colors** | `lib/core/theme/app_theme.dart` | Any widget files |
| **Add localization string** | `lib/l10n/app_en.arb`, `app_ru.arb` | Generated `l10n/*.dart` files |
| **Add database field** | `lib/core/database/tables.dart` → run `build_runner` | `*.g.dart` files |
| **Add new API endpoint** | `lib/core/network/api_client.dart` | `lib/core/network/dio_module.dart` (only change base URL) |
| **Fix EPUB rendering** | `packages/epub_engine/lib/src/epub_reader_view.dart` | `lib/features/reader/` (only integration) |
| **Fix PDF rendering** | `packages/pdf_engine/lib/src/pdf_viewer_widget.dart` | `lib/features/reader/` (only integration) |
| **Change reader settings** | `lib/features/settings/data/settings_provider.dart` | `packages/` (settings are consumed, not defined) |
| **Add new book metadata** | `lib/features/books/domain/models/book_dto.dart` → run `build_runner` | Repository files (auto-update) |
| **Change navigation tabs** | `lib/features/navigation/presentation/main_shell.dart` | `lib/core/router/app_router.dart` (only if adding routes) |
| **Fix search functionality** | `lib/features/search/domain/providers/search_provider.dart` | `lib/features/search/presentation/` (UI only) |
| **Add download logic** | `lib/features/books/domain/providers/books_provider.dart` | `lib/features/search/` (search doesn't handle downloads) |

---

## Project Overview

**Lira** is a cross-platform (Android, iOS, Windows, Linux, macOS) e-book reader for EPUB and PDF files. Built with Flutter, it features offline reading, cloud sync (planned), and integration with Anna's Archive for book discovery.

### Key Features
- **Import books** — Pick `.epub` or `.pdf` from file system
- **Library grid** — Browse books with metadata (title, author, format, pages)
- **Unified reader** — Engine abstraction for EPUB/PDF rendering
- **Reading progress** — Auto-saved to SQLite on page change
- **Highlights** — Text selection with notes persistence
- **Search** — Anna's Archive integration for book discovery
- **Downloads** — Direct download from search results
- **Dark theme** — `#121212` background, `#BB86FC` accent
- **Localization** — English + Russian

---

## Technology Stack

| Category | Technology | Purpose |
|----------|-----------|---------|
| **Framework** | Flutter | Cross-platform UI |
| **State Management** | Riverpod | Reactive state with code generation |
| **Local Database** | Drift (SQLite) | Books, progress, highlights persistence |
| **Routing** | GoRouter | Declarative navigation with auth guards |
| **Dependency Injection** | GetIt + Injectable | Service locator with code generation |
| **HTTP Client** | Dio + Retrofit | REST API communication |
| **Data Classes** | Freezed | Immutable models with copy-with |
| **JSON Serialization** | json_serializable | DTO serialization |
| **EPUB Rendering** | `packages/epub_engine` (WebView-based) | Custom EPUB parser + renderer |
| **PDF Rendering** | `packages/pdf_engine` (pdfrx) | Native PDF rendering |
| **File Picker** | file_selector | Cross-platform file import |
| **External API** | annas_archive_api | Book search and download |

---

## Directory Structure

```
lira/
├── lib/
│   ├── main.dart                          # ⚡ App entry point
│   ├── l10n/                              # 🌍 Localization (ARB files)
│   │   ├── app_en.arb                     # English translations
│   │   ├── app_ru.arb                     # Russian translations
│   │   └── *.dart                         # Generated (DO NOT EDIT)
│   │
│   ├── core/                              # 🏗️ Core infrastructure
│   │   ├── README.md                      # Core module docs
│   │   ├── database/                      # 💾 SQLite (Drift)
│   │   │   ├── app_database.dart          # Database config + migrations
│   │   │   └── tables.dart                # Table schemas (Books, Progress, Highlights)
│   │   │
│   │   ├── di/                            # 📦 Dependency Injection
│   │   │   ├── injection.dart             # GetIt setup
│   │   │   └── injection.config.dart      # Generated (DO NOT EDIT)
│   │   │
│   │   ├── network/                       # 🌐 API Client
│   │   │   ├── api_client.dart            # Retrofit REST API
│   │   │   └── dio_module.dart            # Dio configuration
│   │   │
│   │   ├── providers/                     # 🔮 Global Providers
│   │   │   └── preferences_provider.dart  # Theme, locale settings
│   │   │
│   │   ├── router/                        # 🧭 Navigation
│   │   │   └── app_router.dart            # GoRouter config + auth guards
│   │   │
│   │   └── theme/                         # 🎨 Theming
│   │       └── app_theme.dart             # Light/dark themes
│   │
│   └── features/                          # 📱 Feature modules (Clean Architecture)
│       ├── auth/                          # 🔐 Authentication
│       │   └── presentation/
│       │       ├── auth_screen.dart       # Login/register/guest UI
│       │       └── providers/
│       │           └── auth_provider.dart # Auth state management
│       │
│       ├── books/                         # 📚 Library management
│       │   ├── presentation/
│       │   │   ├── library_screen.dart    # Main library grid + search
│       │   │   ├── book_detail_screen.dart # Book info + edit
│       │   │   └── widgets/
│       │   │       ├── book_card.dart     # Grid item widget
│       │   │       └── responsive_grid_delegate.dart # Adaptive layout
│       │   │
│       │   ├── data/
│       │   │   └── repositories/
│       │   │       └── books_local_repository.dart # DB operations
│       │   │
│       │   └── domain/
│       │       ├── models/
│       │       │   └── book_dto.dart      # Book data class
│       │       └── providers/
│       │           └── books_provider.dart # Import/download logic
│       │
│       ├── highlights/                    # 🖍️ Text highlights
│       │   ├── data/repositories/
│       │   │   └── highlights_local_repository.dart
│       │   └── domain/
│       │       ├── models/highlight_dto.dart
│       │       └── providers/highlights_provider.dart
│       │
│       ├── navigation/                    # 🧭 Main shell
│       │   └── presentation/
│       │       └── main_shell.dart        # Bottom navigation (Library/Search/Settings)
│       │
│       ├── progress/                      # 📖 Reading progress
│       │   ├── data/repositories/
│       │   │   └── reading_progress_local_repository.dart
│       │   └── domain/
│       │       ├── models/reading_progress_dto.dart
│       │       └── providers/reading_progress_provider.dart
│       │
│       ├── reader/                        # 📖 Book reader
│       │   ├── presentation/
│       │   │   └── reader_screen.dart     # Main reader UI + engine integration
│       │   └── domain/
│       │       ├── engine/
│       │       │   ├── book_reader_engine.dart # Abstract interface
│       │       │   ├── epub_book_reader_engine.dart # EPUB implementation
│       │       │   └── pdf_book_reader_engine.dart # PDF implementation
│       │       └── models/
│       │           └── book_location.dart # Unified location abstraction
│       │
│       ├── search/                        # 🔍 Book search
│       │   ├── presentation/
│       │   │   ├── search_screen.dart     # Search UI
│       │   │   └── widgets/
│       │   │       └── search_book_card.dart # Search result item
│       │   └── domain/
│       │       ├── providers/
│       │       │   ├── search_provider.dart # Anna's Archive search
│       │       │   ├── search_state.dart  # Search state union
│       │       │   └── download_provider.dart # Download progress tracking
│       │       └── models/
│       │           └── anna_book_wrapper.dart # Anna's API book wrapper
│       │
│       └── settings/                      # ⚙️ App settings
│           ├── presentation/
│           │   ├── settings_screen.dart   # Main settings UI
│           │   └── settings_panel.dart    # Reader settings modal
│           └── data/
│               └── settings_provider.dart # Reader settings persistence
│
├── packages/                              # 📦 Local packages
│   ├── epub_engine/                       # EPUB rendering engine
│   │   ├── lib/
│   │   │   ├── epub_engine.dart           # Library exports
│   │   │   └── src/
│   │   │       ├── epub_reader_view.dart  # WebView-based reader ⚡
│   │   │       ├── epub_parser.dart       # EPUB metadata extraction
│   │   │       └── models/
│   │   │           ├── reader_settings.dart
│   │   │           ├── epub_location.dart
│   │   │           └── epub_cfi.dart
│   │   └── pubspec.yaml
│   │
│   └── pdf_engine/                        # PDF rendering engine
│       ├── lib/
│       │   ├── pdf_engine.dart            # Library exports
│       │   └── src/
│       │       └── pdf_viewer_widget.dart # pdfrx wrapper
│       └── pubspec.yaml
│
├── test/                                  # 🧪 Unit tests
├── pubspec.yaml                           # Dependencies
└── build.yaml                             # Build configuration
```

---

## Core Module Deep Dive

### `/lib/core/database/` — SQLite Persistence

**Files:**
- `tables.dart` — **EDIT THIS** to add/modify database tables
- `app_database.dart` — Database configuration, migrations

**Tables:**

```dart
Books {
  id: String (PK)
  title: String
  author: String
  format: String (epub/pdf)
  coverUrl: String?
  fileUrl: String?
  createdAt: DateTime
  pageCount: int           // ← Add new fields here
  fileSizeBytes: int       // ← Add new fields here
  contentHash: String?
}

ReadingProgresses {
  bookId: String (PK, FK → Books.id)
  percentage: double (0-100)
  location: String         // Opaque: CFI for EPUB, page# for PDF
  updatedAt: DateTime
}

Highlights {
  id: String (PK)
  bookId: String (FK → Books.id)
  textContent: String
  color: String (#BB86FC)
  location: String
  note: String?
  createdAt: DateTime
}
```

**How to add a field:**
1. Add field to table in `tables.dart`
2. Increment `schemaVersion` in `app_database.dart`
3. Add migration: `migrations.add(Migration(...))`
4. Run `flutter pub run build_runner build -d`
5. Update `BookDto` in `features/books/domain/models/`

---

### `/lib/core/network/` — REST API Client

**Files:**
- `api_client.dart` — **EDIT THIS** to add API endpoints
- `dio_module.dart` — Base URL configuration

**API Contract (Future Go Server):**

```dart
// Auth
POST /auth/login
POST /auth/register

// Books
GET  /books
POST /books
GET  /books/{id}
DELETE /books/{id}

// Progress
GET /progress
PUT /progress/{book_id}

// Highlights
GET /highlights
POST /highlights
PUT /highlights/{id}
DELETE /highlights/{id}
```

**DTOs:** All API models use `snake_case` JSON serialization (configured in `build.yaml`)

---

### `/lib/core/router/` — Navigation

**File:** `app_router.dart` — **EDIT THIS** to add routes

**Current Routes:**
```dart
/login              → AuthScreen
/                   → MainShell (Library/Search/Settings tabs)
/book-detail        → BookDetailScreen (requires BookDto extra)
/reader             → ReaderScreen (requires BookDto extra)
```

**Auth Guards:**
- Unauthenticated users → redirected to `/login`
- Authenticated users on `/login` → redirected to `/`

**How to add a route:**
1. Add `GoRoute(path: '/your-route', ...)` to `routes` list
2. Import the screen widget
3. If route requires auth, no change needed (handled by redirect)
4. Navigate using `context.go('/your-route')` or `context.push('/your-route')`

---

### `/lib/core/providers/` — Global State

**File:** `preferences_provider.dart` — **EDIT THIS** for app-wide settings

**Providers:**
- `themeModeProvider` — Dark/light theme toggle
- `localeProvider` — Language selector (en/ru)

**Storage:** SharedPreferences with keys:
- `pref_theme_mode` — 'light' or 'dark'
- `pref_locale` — language code ('en', 'ru')

---

## Features Module Deep Dive

### `/lib/features/books/` — Library Management

#### **Import Flow** (Adding a Book)

```
User taps FAB
    ↓
LibraryScreen._importBook()
    ↓
file_selector.pickFiles()
    ↓
BooksController.importBook()
    ↓
├─ Copy file to app documents
├─ Extract metadata:
│  ├─ EPUB: EpubParser.parse()
│  └─ PDF: PdfDocument.openFile()
├─ Extract cover image
└─ Save to DB: BooksLocalRepository.saveBook()
    ↓
UI rebuilds via booksControllerProvider
```

#### **Key Files:**

| File | Purpose | When to Edit |
|------|---------|--------------|
| `library_screen.dart` | Grid UI, search, FAB | Change UI layout, search behavior |
| `book_detail_screen.dart` | Book info, edit, delete | Add metadata fields, edit UI |
| `book_card.dart` | Grid item widget | Change card design, shadows |
| `books_provider.dart` | Import/download logic | Add import sources, change download flow |
| `books_local_repository.dart` | DB CRUD | Change query logic |
| `book_dto.dart` | Book model | Add new fields |

---

### `/lib/features/reader/` — Book Reader

#### **Architecture:**

```
ReaderScreen (UI)
    ↓
BookReaderEngine (Abstract Interface)
    ├─ EpubBookReaderEngine → packages/epub_engine
    └─ PdfBookReaderEngine → packages/pdf_engine
    ↓
Progress Tracking (debounced)
    ↓
ReadingProgressLocalRepository
```

#### **Key Files:**

| File | Purpose | When to Edit |
|------|---------|--------------|
| `reader_screen.dart` | Main reader UI, top/bottom bars, TOC drawer | Add UI controls, change gestures |
| `book_reader_engine.dart` | Abstract interface | Add new format support |
| `epub_book_reader_engine.dart` | EPUB integration | Change EPUB engine wiring |
| `pdf_book_reader_engine.dart` | PDF integration | Change PDF engine wiring |
| `book_location.dart` | Location abstraction | Change location format |

#### **Progress Saving:**

```dart
// In reader_screen.dart
onProgressChanged: (location, percentage) {
  ref.read(readingProgressControllerProvider(book.id).notifier)
    .saveProgress(location, percentage);  // Debounced 1s
}
```

---

### `/lib/features/search/` — Book Search

#### **Search Flow:**

```
User types query
    ↓
SearchScreen._search()
    ↓
SearchNotifier.search(query)
    ↓
AnnaApi.find(SearchRequest(...))
    ↓
SearchState.loaded(List<Book>)
    ↓
ListView of SearchBookCard
```

#### **Download Flow:**

```
User taps download button
    ↓
SearchBookCard._download()
    ↓
BooksController.downloadAndImportBook(annaBook, ref)
    ↓
├─ Check duplicate (title + author)
├─ AnnaApi.getDownloadLinks(md5)
├─ Dio.download(...) with progress
├─ Update downloadNotifierProvider
├─ Import to library (same as local import)
└─ Remove from search results
```

#### **Key Files:**

| File | Purpose | When to Edit |
|------|---------|--------------|
| `search_screen.dart` | Search UI, filters | Add filter UI, change layout |
| `search_book_card.dart` | Search result item | Change card design, download UI |
| `search_provider.dart` | Anna's Archive search | Change search params, filters |
| `search_state.dart` | State union | Add new states |
| `download_provider.dart` | Download progress tracking | Change progress logic |

---

### `/lib/features/settings/` — App Settings

#### **Key Files:**

| File | Purpose | When to Edit |
|------|---------|--------------|
| `settings_screen.dart` | Main settings UI | Add new settings sections |
| `settings_panel.dart` | Reader settings modal | Add reader settings |
| `settings_provider.dart` | Reader settings persistence | Add new settings fields |

#### **Reader Settings:**

```dart
ReaderSettings {
  fontFamily: String (sans-serif/serif/monospace)
  fontSize: double (12-32)
  backgroundColor: int (0xAARRGGBB)
  lineHeight: double (1.0-2.5)
  horizontalPadding: double (8-64)
  readingMode: ReadingMode (vertical/horizontal)
}
```

**Storage:** SharedPreferences with key `reader_settings` (JSON)

---

## Packages Deep Dive

### `packages/epub_engine/` — EPUB Rendering

#### **Architecture:**

```
EPUB File (ZIP)
    ↓
EpubParser.parse()
    ├─ Extract metadata (title, author)
    ├─ Extract cover image
    ├─ Parse chapters (skip nav, toc, ncx)
    └─ Build TOC hierarchy
    ↓
EpubReaderView (WebView)
    ├─ Convert chapters to single HTML
    ├─ Embed images as base64
    ├─ Apply CSS (font, size, colors, columns)
    └─ JavaScript ↔ Dart communication
```

#### **Key Files:**

| File | Purpose | When to Edit |
|------|---------|--------------|
| `epub_reader_view.dart` | WebView-based reader ⚡ | Fix rendering, pagination, progress |
| `epub_parser.dart` | EPUB parsing | Fix metadata extraction, TOC parsing |
| `reader_settings.dart` | Settings model | Add new settings |
| `epub_location.dart` | Location (CFI-based) | Change navigation format |
| `epub_cfi.dart` | Canonical Fragment Identifier | Change location precision |

#### **Horizontal Mode (Pagination):**

Uses CSS multi-column layout:
```css
body {
  column-width: ${viewportWidth}px;
  column-gap: 0;
  overflow: hidden;
}
```

Navigation: Swipe left/right → scroll by `columnWidth`

#### **Progress Calculation:**

```dart
progress = (currentChapterIndex + scrollFraction) / totalChapters
```

Where `scrollFraction` = vertical scroll position / max scroll (from JS)

---

### `packages/pdf_engine/` — PDF Rendering

#### **Key Files:**

| File | Purpose | When to Edit |
|------|---------|--------------|
| `pdf_viewer_widget.dart` | pdfrx wrapper | Change viewer params |

#### **Features:**
- Native rendering via `pdfrx` (works on Linux!)
- Text selection enabled
- Page-based navigation
- No TOC support (PDFs don't have standard TOC)

---

## Data Flow Diagrams

### Book Import (Local File)

```
┌─────────────┐
│   User      │
└──────┬──────┘
       │ Tap FAB
       ↓
┌─────────────────────────┐
│   LibraryScreen         │
│   _importBook()         │
└──────┬──────────────────┘
       │ file_selector.pickFiles()
       ↓
┌─────────────────────────┐
│  BooksController        │
│  importBook()           │
└──────┬──────────────────┘
       │
       ├──────────────┬──────────────┐
       ↓              ↓              ↓
┌────────────┐ ┌────────────┐ ┌────────────┐
│ Copy file  │ │ Extract    │ │ Extract    │
│ to docs/   │ │ cover      │ │ metadata   │
└──────┬─────┘ └──────┬─────┘ └──────┬─────┘
       │              │              │
       │              │              ├─ EPUB: EpubParser
       │              │              └─ PDF: PdfDocument
       │              │
       └──────────────┴──────────────┘
                      ↓
           ┌───────────────────────┐
           │  BookDto              │
           │  {title, author, ...} │
           └──────────┬────────────┘
                      │
                      ↓
           ┌───────────────────────┐
           │  BooksLocalRepository │
           │  saveBook()           │
           └──────────┬────────────┘
                      │ INSERT/REPLACE
                      ↓
           ┌───────────────────────┐
           │  SQLite (Drift)       │
           │  Books table          │
           └──────────┬────────────┘
                      │
                      ↓
           ┌───────────────────────┐
           │  booksController      │
           │  rebuilds UI          │
           └───────────────────────┘
```

### Reading Progress Flow

```
┌───────────────────────┐
│   ReaderScreen        │
│   onProgressChanged   │
└──────┬────────────────┘
       │ (location, percentage)
       ↓
┌───────────────────────────────┐
│  ReadingProgressController    │
│  saveProgress()               │
│  (debounced 1 second)         │
└──────┬────────────────────────┘
       │
       ↓
┌───────────────────────────────┐
│  ReadingProgressLocalRepo     │
│  saveProgress()               │
│  (INSERT OR REPLACE)          │
└──────┬────────────────────────┘
       │
       ↓
┌───────────────────────────────┐
│  SQLite                       │
│  ReadingProgresses table      │
└───────────────────────────────┘
```

### Search & Download Flow

```
┌─────────────┐
│   User      │
└──────┬──────┘
       │ Type query
       ↓
┌───────────────────────┐
│  SearchScreen         │
│  _search()            │
└──────┬────────────────┘
       │
       ↓
┌───────────────────────┐
│  SearchNotifier       │
│  search(query)        │
└──────┬────────────────┘
       │ AnnaApi.find()
       ↓
┌───────────────────────┐
│  Anna's Archive API   │
└──────┬────────────────┘
       │ List<Book>
       ↓
┌───────────────────────┐
│  SearchState.loaded   │
└──────┬────────────────┘
       │
       ↓
┌───────────────────────┐
│  ListView<            │
│  SearchBookCard>      │
└──────┬────────────────┘
       │ Tap download
       ↓
┌───────────────────────┐
│  BooksController      │
│  downloadAndImport    │
└──────┬────────────────┘
       │
       ├─ Check duplicate (title + author)
       ├─ AnnaApi.getDownloadLinks(md5)
       ├─ Dio.download() with progress
       └─ Import to library
```

---

## State Management Patterns

### Provider Types

| Type | Use Case | Example |
|------|----------|---------|
| `NotifierProvider` | Complex state with methods | `authProvider`, `booksControllerProvider` |
| `StateNotifierProvider` | Simple state (freezed union) | `searchProvider`, `downloadNotifierProvider` |
| `Provider` | Read-only dependencies | `appRouterProvider` |
| `FutureProvider` | Async data fetching | (not used currently) |
| `Family` | Parameterized providers | `readingProgressControllerProvider(bookId)` |

### Provider Naming Convention

```dart
// State holder
final authProvider = NotifierProvider<AuthNotifier, AuthState>();

// Controller (AsyncNotifier)
final booksControllerProvider = AsyncNotifierProvider<BooksController, List<BookDto>>();

// Family (parameterized)
final readingProgressControllerProvider = AsyncNotifierProvider.family<
  ReadingProgressController,
  ReadingProgressDto?,
  String  // Parameter type (bookId)
>(...);
```

---

## Build System

### Code Generation

**Tools:**
- `freezed` — Immutable data classes
- `json_serializable` — JSON (de)serialization
- `drift` — SQL → Dart
- `injectable_generator` — DI setup
- `riverpod_generator` — Riverpod code gen

**Run Generation:**
```bash
flutter pub run build_runner build -d
```

**Generated Files (DO NOT EDIT):**
- `*.g.dart` — JSON, Drift
- `*.freezed.dart` — Freezed unions
- `*.config.dart` — Injectable
- `l10n/*.dart` — Localization

---

## Testing Strategy

### Test Files Location

```
test/
├── features/
│   ├── books/
│   │   └── books_provider_test.dart
│   └── search/
│       └── search_provider_test.dart
└── core/
    └── database/
        └── app_database_test.dart
```

### Mocking

- Use `mockito` for mocking repositories
- Use `riverpod_test` for testing providers
- Use `flutter_test` for widget tests

---

## Platform-Specific Code

### Android

**Manifest:** `android/app/src/main/AndroidManifest.xml`

**Permissions to add:**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

### iOS/macOS

**Info.plist:** `ios/Runner/Info.plist`, `macos/Runner/Info.plist`

**Permissions:**
```xml
<key>NSFileProviderDomainUsageDescription</key>
<string>Access files to import books</string>
```

### Linux

**Dependencies:**
```bash
sudo pacman -S xdg-desktop-portal xdg-desktop-portal-gtk
```

---

## Common Tasks: Where to Edit

### Add a New Book Metadata Field (e.g., `genre`)

1. **Database:** `lib/core/database/tables.dart`
   ```dart
   String? get genre => read().readColumn('genre');
   ```

2. **Migration:** `lib/core/database/app_database.dart`
   ```dart
   migration.add(migrations: [
     Migration(2, 3, (db) => db.execute('ALTER TABLE books ADD COLUMN genre TEXT'))
   ]);
   ```

3. **DTO:** `lib/features/books/domain/models/book_dto.dart`
   ```dart
   @JsonSerializable()
   class BookDto {
     final String? genre;
   }
   ```

4. **Parser:** `packages/epub_engine/lib/src/epub_parser.dart`
   ```dart
   final genre = epubBook.genre;
   ```

5. **UI:** `lib/features/books/presentation/book_detail_screen.dart`
   ```dart
   Text(book.genre ?? 'Unknown Genre')
   ```

6. **Run:** `flutter pub run build_runner build -d`

---

### Add a New Reader Setting (e.g., `textColor`)

1. **Model:** `packages/epub_engine/lib/src/models/reader_settings.dart`
   ```dart
   class ReaderSettings {
     final int textColor;  // 0xAARRGGBB
   }
   ```

2. **Provider:** `lib/features/settings/data/settings_provider.dart`
   ```dart
   class ReaderSettingsNotifier {
     void updateSettings(ReaderSettings newSettings) { ... }
   }
   ```

3. **UI:** `lib/features/settings/presentation/settings_panel.dart`
   ```dart
   ColorPicker(
     onColorChanged: (color) => notifier.updateSettings(...),
   )
   ```

4. **Renderer:** `packages/epub_engine/lib/src/epub_reader_view.dart`
   ```dart
   body { color: #${textColor.toRadixString(16)}; }
   ```

---

### Add a New API Endpoint

1. **Client:** `lib/core/network/api_client.dart`
   ```dart
   @GET('/books/{id}/reviews')
   Future<List<ReviewDto>> getReviews(@Path('id') String bookId);
   ```

2. **DTO:** `lib/features/reviews/domain/models/review_dto.dart`
   ```dart
   @freezed
   class ReviewDto with _$ReviewDto { ... }
   ```

3. **Repository:** Create new repo in `lib/features/reviews/data/repositories/`

4. **Provider:** `lib/features/reviews/domain/providers/reviews_provider.dart`

5. **Run:** `flutter pub run build_runner build -d`

---

### Change App Theme Colors

**File:** `lib/core/theme/app_theme.dart`

```dart
static ThemeData get darkTheme {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFBB86FC),  // ← Change primary color here
      brightness: Brightness.dark,
    ),
  );
}
```

---

### Add Localization String

1. **English:** `lib/l10n/app_en.arb`
   ```json
   {
     "newFeature": "New Feature",
     "@newFeature": {
       "description": "Label for new feature button"
     }
   }
   ```

2. **Russian:** `lib/l10n/app_ru.arb`
   ```json
   {
     "newFeature": "Новая функция"
   }
   ```

3. **Run:** `flutter gen-l10n`

4. **Use:** `context.l10n.newFeature`

---

## Debugging Tips

### Enable Verbose Logging

**File:** `lib/core/network/dio_module.dart`

```dart
dio.interceptors.add(LogInterceptor(
  requestBody: true,
  responseBody: true,
));
```

### Check Database Contents

```bash
# Android
adb shell "run-as dev.u0xfaced.lira cat databases/app_db.db" | sqlite3

# Desktop
sqlite3 ~/Library/Application\ Support/dev.u0xfaced.lira/app_db.db
```

### Hot Reload Issues

If hot reload breaks after code generation:
```bash
flutter clean
flutter pub get
flutter pub run build_runner build -d
flutter run
```

---

## Performance Considerations

### EPUB Rendering

- **WebView overhead:** EPUB uses `webview_flutter` → heavier than native
- **Large books:** All chapters loaded at once → memory intensive
- **Solution:** Implement lazy loading for chapters (future)

### PDF Rendering

- **Native:** `pdfrx` uses native rendering → fast
- **Page caching:** Only visible pages in memory
- **Issue:** Linux requires `pdfrx` with proper native libs

### Database Queries

- **Indexed fields:** `Books.id`, `ReadingProgresses.bookId`, `Highlights.bookId`
- **Avoid:** `SELECT *` — use specific columns
- **Batch operations:** Use transactions for bulk inserts

---

## Security Notes

### API Authentication

- Currently: Mock login/register (no real API)
- Future: JWT tokens stored in secure storage
- Guest mode: Local-only, no sync

### File Storage

- Books stored in app documents directory
- No encryption (local files only)
- Future: Encrypted storage for DRM content

---

## Contributing Guidelines

### Code Style

- **Format:** `dart format .`
- **Analyze:** `flutter analyze`
- **Imports:** Use `prefer_relative_imports` (configured in `injection.dart`)

### Commit Messages

```
feat: add genre filter to library
fix: EPUB progress tracking in landscape mode
docs: update ARCH.md with new provider patterns
refactor: extract book card shadow logic
```

### Pull Requests

1. Create feature branch: `git checkout -b feature/your-feature`
2. Make changes
3. Run tests: `flutter test`
4. Run linter: `flutter analyze`
5. Commit with conventional message
6. Open PR

---

## Contact & Resources

- **Project Root:** `/home/faced/coding/flutter/lira`
- **Main Entry:** `lib/main.dart`
- **Core Docs:** `lib/core/README.md`
- **Reader Docs:** `lib/features/reader/README.md`
- **API Docs:** `ANNAS_ARCHIVE_API.md`
- **Tasks:** `FIXES.md`, `TODO.md`, `PLAN.md`

---

*This document is auto-generated from the codebase. If something is unclear or outdated, update it!*
