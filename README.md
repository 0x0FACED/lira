# Lira — Library Reader App

Cross-platform (Android / iOS / Windows / Linux / macOS) offline book reader for EPUB and PDF files, built with Flutter.

## Features

- **Import books** — pick `.epub` or `.pdf` from the file system, metadata saved to local DB
- **Library grid** — browse imported books with title, author, format
- **Reader** — unified reader screen with engine abstraction (EPUB via `epub_view`, PDF via `pdfx`)
- **Reading progress** — auto-saved to Drift (SQLite) on page change, restored on re-open
- **Highlights** — select text in the reader to save highlights to local DB
- **Dark theme** — `#121212` background, `#BB86FC` accent
- **Localization** — English + Russian (l10n)

## Architecture

```
lib/
├── core/            # DI, database, routing, network, theme
├── features/
│   ├── books/       # Library: import, list, delete books
│   ├── reader/      # Reader screen + engine abstraction
│   ├── progress/    # Reading progress persistence
│   └── highlights/  # Text highlights persistence
├── l10n/            # Localization ARB files
└── main.dart
packages/
├── epub_engine/     # EpubBookReaderEngine
└── pdf_engine/      # PdfBookReaderEngine
```

**Stack:** Flutter, Riverpod, Drift, GoRouter, Dio + Retrofit, Freezed, Injectable/GetIt

## Getting Started

```bash
# Install dependencies
flutter pub get

# Generate code (freezed, drift, json_serializable, injectable, retrofit)
flutter pub run build_runner build -d

# Run on connected device
flutter run
```

## API Contract (future Go server)

Defined in `lib/core/network/api_client.dart` — endpoints for books, reading progress, and highlights sync. Server will be implemented in Go with HTTP/JSON API using `snake_case` field names.
