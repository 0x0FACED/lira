# Project Context: Lira

Lira — кроссплатформенный (Android, iOS, Windows, Linux, macOS) e-reader на Flutter. Офлайн-чтение EPUB/PDF, поиск и скачивание книг через Anna's Archive и Z-Library.

## Technical Stack

| Category | Technology | Version |
|----------|-----------|---------|
| Framework | Flutter | 3.9.4+ |
| State Management | Riverpod | 2.6.1 |
| Local DB | Drift (SQLite) | 2.20.0 |
| Routing | GoRouter | 17.1.0 |
| DI | GetIt + Injectable | 9.2.1 / 2.7.1 |
| HTTP | Dio + Retrofit | 5.9.2 / 4.9.2 |
| Models | Freezed + json_serializable | 3.2.5 / 6.9.0 |
| EPUB | epubx + flutter_widget_from_html | 4.0.0 |
| PDF | pdfrx | 1.0.0 |
| Search | annas_archive_api | 1.1.0 |
| Z-Library | Custom (packages/zlibrary_api) | Local |
| i18n | intl (ARB) | 0.20.2 |

## Architecture

Feature-first clean architecture:

```
lib/
├── core/                          # Инфраструктура
│   ├── database/                  # Drift: таблицы Books, ReadingProgresses, Highlights
│   ├── di/                        # GetIt + Injectable (injection.dart → injection.config.dart)
│   ├── network/                   # Dio + Retrofit API клиент (localhost:8080, под будущий Go бэкенд)
│   ├── providers/                 # Глобальный стейт: тема, локаль, источник поиска, Z-Lib креды
│   ├── router/                    # GoRouter + auth guard
│   └── theme/                     # Material3 dark/light темы
│
├── features/
│   ├── auth/                      # Авторизация (login, register, guest) — API заглушки
│   ├── books/                     # Библиотека: импорт, отображение, удаление книг
│   │   ├── data/repositories/     # BooksLocalRepository (CRUD)
│   │   ├── domain/models/         # BookDto (freezed)
│   │   ├── domain/providers/      # BooksController (465 строк — перегружен)
│   │   └── presentation/          # LibraryScreen, BookDetailScreen, BookCard
│   ├── highlights/                # Выделения текста + заметки
│   ├── navigation/                # MainShell (3 вкладки: Library, Search, Settings)
│   ├── progress/                  # Прогресс чтения (debounce 1с)
│   ├── reader/                    # Ридер: BookReaderEngine interface + EPUB/PDF реализации
│   │   └── domain/engine/         # EpubBookReaderEngine, PdfBookReaderEngine
│   ├── search/                    # Поиск по Anna's Archive + Z-Library
│   └── settings/                  # Настройки (тема, язык, ридер)
│
├── l10n/                          # Локализация: app_en.arb, app_ru.arb
└── main.dart                      # Entry point, HttpOverrides, ProviderScope

packages/
├── epub_engine/                   # WebView-based EPUB ридер (HTML injection, JS bridge)
├── pdf_engine/                    # Обёртка над pdfrx
└── zlibrary_api/                  # Неофициальный Z-Library API клиент
```

## Database Schema (Drift, v2)

| Table | PK | Key Columns |
|-------|-----|------------|
| Books | id | title, author, format, coverUrl, fileUrl, pageCount, fileSizeBytes, contentHash |
| ReadingProgresses | bookId (FK→Books) | percentage, location, updatedAt |
| Highlights | id | bookId (FK→Books), textContent, color, location, note, createdAt |

## Routes

| Path | Screen | Notes |
|------|--------|-------|
| `/login` | AuthScreen | Login, register, guest |
| `/` | MainShell | Bottom nav: Library, Search, Settings |
| `/book-detail` | BookDetailScreen | BookDto extra |
| `/reader` | ReaderScreen | BookDto extra |

## Code Style & Rules

- Feature-first architecture (domain, data, presentation).
- No logic in UI widgets — use ViewModels/Providers.
- All strings must be localized (l10n) to English and Russian.
- API models: snake_case JSON, готовы к Go REST бэкенду.
- Freezed для immutable data classes.
- json_serializable для JSON.
- Injectable для DI.
- В каждом пакете — README.md.

## Code Generation

```bash
# Все генераторы (freezed, json_serializable, drift_dev, injectable, retrofit):
flutter pub run build_runner build -d

# Локализация:
flutter gen-l10n

# Иконки:
flutter pub run flutter_launcher_icons:main
```

## Design Vibe

- Minimalist.
- Smooth transitions (Hero animations).
- Dark mode by default.
- Colors: white, black, gray, purple (#BB86FC primary, #03DAC6 secondary, #121212 surface).

## Key Documentation

| File | Contents |
|------|----------|
| ARCH.md | Подробная архитектура, where-to-change таблица, data flow |
| READER.md | Архитектура ридера (WebView, progress, TOC) |
| ANNAS_ARCHIVE_API.md | Справка по Anna's Archive API |
| PLAN.md | 4-недельный roadmap |
| FIXES.md | Приоритетный список багов |
| TODO.md | Бэклог задач |

## Known Issues Summary

See TODO.md Phases 8-14 for detailed tasks. Key areas:

- **macOS (Phase 8, CRITICAL)**: Отсутствуют entitlements — `files.user-selected.read-write` (импорт не работает) и `network.client` (поиск не работает). App Sandbox блокирует оба действия.
- **Reader Themes (Phase 9)**: При смене фона ридера текст не адаптируется — цвет берётся из глобальной темы (`theme.colorScheme.onSurface`), а не вычисляется от фона. Белый текст на белом фоне при светлой теме ридера + тёмной теме приложения.
- **Security (Phase 10)**: SSL bypass в продакшне, креды в SharedPreferences без шифрования.
- **i18n (Phase 11)**: ~40% строк не локализованы (hardcoded English).
- **Architecture (Phase 12)**: Бизнес-логика в UI виджетах; BooksController перегружен (465 строк).
- **Desktop WebView (Phase X)**: Потенциальные проблемы с WebView на Windows/Linux.
