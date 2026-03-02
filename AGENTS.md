# Project Context: Lira
Lira is a high-end Flutter e-reader. 

## Technical Stack
- Framework: Flutter
- State Management: Riverpod.
- Local DB: Drift (SQLite).
- Formats: PDF (native_pdf_view), EPUB (epub_view).

## Code Style & Rules
- Use feature-first architecture (layers: domain, data, presentation).
- No logic in UI widgets. Use ViewModels/Providers.
- All strings must be localized (l10n) to English and Russian.
- For API: Prepare models for future JSON-REST Go backend.
- Use freezed for immutable data classes.
- Use json_serializable for JSON serialization.
- Use injectable for dependency injection.
- In every created package create README.md file with description of the package and how to use it.

## Design Vibe
- Minimalist.
- Smooth transitions (Hero animations).
- Dark mode by default.
- Main colors - white, black, gray, purple.
