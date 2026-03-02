# Lira — UI Screen Map

## Auth Screen (`/login`)
**File:** `lib/features/auth/presentation/auth_screen.dart`

- Login form (username + password) with "Sign In" / "Register" toggle
- "Continue as Guest" button — sets `isGuest` flag, local-only mode
- Redirects to `/` on success
- **TODO:** API integration for login/register

---

## Main Shell (`/`)
**File:** `lib/features/navigation/presentation/main_shell.dart`

Bottom `NavigationBar` with 3 tabs:

### Tab 1: Library
**File:** `lib/features/books/presentation/library_screen.dart`

- Grid of book cards with covers, titles, authors, format badges
- FAB "+" to import books (EPUB, PDF)
- Long press to delete a book
- Tap to open reader
- Cover extraction: EPUB covers parsed on import, saved to `covers/` dir

### Tab 2: Search
**File:** `lib/features/search/presentation/search_screen.dart`

- Placeholder screen
- **TODO:** Search bar + z-library / custom API integration

### Tab 3: Settings
**File:** `lib/features/settings/presentation/settings_screen.dart`

- **Profile section:** shows username (logged in) or "Guest" label
- **Account:** Sign In / Register buttons (if guest), Logout (if authenticated)
- **Appearance:** Theme toggle (dark/light), Language selector
- **About:** App version
- **TODO:** Theme toggle with Riverpod provider, language selector, API auth

---

## Reader Screen (`/reader`)
**File:** `lib/features/reader/presentation/reader_screen.dart`

- Full-screen immersive reader (black background)
- Tap anywhere to toggle top/bottom bars (AnimatedPositioned)
- **Top bar:** Back button + book title
- **Bottom bar:** Progress bar (percentage) + TOC button + Settings button
- Supports PDF (pdfrx) and EPUB (flutter_widget_from_html)

### EPUB Reader
**File:** `packages/epub_engine/lib/src/epub_reader_view.dart`

- Continuous vertical scroll (all chapters in one ListView)
- Scroll offset saved/restored for reading position
- Internal links, embedded images, chapter dividers
- Progress = scroll position / total height

### PDF Reader
**File:** `packages/pdf_engine/lib/src/pdf_viewer_widget.dart`

- pdfrx native viewer with text selection
- Page-based progress tracking

---

## Auth Provider
**File:** `lib/features/auth/domain/providers/auth_provider.dart`

- `SharedPreferences`-based: `isGuest`, `isLoggedIn`, `username`
- Methods: `continueAsGuest()`, `login()`, `register()`, `logout()`
- **TODO:** Replace login/register stubs with real API calls

## Router
**File:** `lib/core/router/app_router.dart`

- Auth redirect: unauthenticated → `/login`, authenticated → `/`
- Routes: `/login`, `/`, `/reader`
