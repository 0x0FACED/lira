# Lira — Library Reader App

Cross-platform (Android / iOS / Windows / Linux / macOS) offline book reader for EPUB and PDF files, built with Flutter.

## Features

- **Import books** — pick `.epub` or `.pdf` from the file system, metadata saved to local DB
- **Library grid** — browse imported books with title, author, format
- **Reader** — native Flutter EPUB rendering and PDF viewing via `pdfrx`, behind a shared engine interface
- **Reading progress** — debounced Drift (SQLite) persistence, flushed on close/suspend and restored on re-open
- **Highlights** — EPUB text ranges and PDF page geometry saved locally, with notes and navigation back to the selection
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
├── epub_engine/     # EPUB parser + native Flutter renderer
└── pdf_engine/      # pdfrx viewer + persistent PDF selections
```

**Stack:** Flutter, Riverpod, Drift, GoRouter, Dio + Retrofit, Freezed, Injectable/GetIt

Reader architecture, stored location formats and regression commands: [`READER.md`](READER.md).

Release automation for all five native platforms is described in [`RELEASE.md`](RELEASE.md). Pushing a `v*` tag builds APK/AAB, an unsigned iOS IPA, Windows/Linux ZIPs and a macOS DMG, then publishes one GitHub Release only after every build succeeds. The iOS IPA requires signing before installation; the macOS DMG is not notarized.

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
