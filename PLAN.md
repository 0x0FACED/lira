# Lira Project — Comprehensive Action Plan

> Generated from @FIXES.md — Decomposed and organized by priority

---

## Part 1: Quick Reader Fixes

- [x] **Fix EPUB sliding window bug (landscape mode)** — When jumping from chapter 1 to 5, the sliding window gets stuck between pages. Must ensure clean page alignment when switching chapters
- [x] **Add PDF reader features** — Progress bar, settings (background color), TOC, in-document search
- [x] **Fix EPUB page count calculation** — Render book in horizontal mode, count pages properly, save to DB (never recalculate)
- [x] **Fix image decoding fallback** — When image fails to decode, show fallback icon (PDF/EPUB badge) instead of exception text
- [x] **Fix download indicator animation** — Show loading indicator immediately with smooth animation (no 3+ second delay)
- [x] **Add cancel download functionality** — Allow users to cancel ongoing downloads
- [x] **Hide downloaded book cards from search** — Once download starts, remove card from search results screen
- [x] **Fix EPUB WebView OOM crash** — Replaced `loadHtmlString()` with a local `HttpServer` to avoid inflating large books into 120MB+ Base64 strings across platform channels.

---

## Part 2: Search & Downloads Enhancement

- [ ] **Fix images not loading in search** — Debug and fix cover image loading issue
- [ ] **Add search filters** — Language selector + file format selector (EPUB/PDF)
- [x] **Show source badge on book cards** — Display "Anna's Archive" or "Z-Library" badge on each search result card
- [ ] **Deduplicate search results** — Remove duplicate cards with identical download links
- [ ] **Add download retry handling** — Handle failed downloads gracefully

---

## Part 3: Z-Library API Integration

- [x] **Rewrite Z-Library API from Python to Dart** — Native integration for Flutter client
- [x] **Add dual-source support in Settings** — Allow users to enable/disable:
  - Anna's Archive
  - Z-Library
  - Both sources simultaneously
- [x] **Merge search results from both sources** — Unified search results with proper deduplication

---

## Part 4: Reader Settings & UX

- [ ] **Update reader settings UI** — Reduce padding, make dialog more compact (currently takes too much space)
- [ ] **Add color palette selector** — Replace simple background color with theme palettes (light bg → dark text, dark bg → light text)
- [ ] **Add brightness control** — Brightness slider in reader settings
- [ ] **Make progress bar interactive** — 
  - Drag to seek through book
  - Horizontal mode: snap to pages (no mid-page stops)
  - Auto-align animation to nearest page on release
- [ ] **Save reader settings to DB** — Persist color palette, brightness, font settings

---

## Part 5: Library & Book Details

- [ ] **Add author filter dropdown** — Filter by author (dropdown populated from existing library authors)
- [ ] **Add genre filter** — Filter by genre (dropdown from existing genres)
- [ ] **Add format filter** — Filter by EPUB/PDF
- [ ] **Add genre field to database** — Save genres when downloading books
- [ ] **Add Open Library / Google Books API integration** — Fetch missing metadata by ISBN (extracted from EPUB/PDF)
- [ ] **Humanize file size display** — Show "6 MB" instead of "6000 KB" on book details screen
- [ ] **Add share book functionality** — 
  - Mobile: Native share dialog (send file)
  - Desktop (Linux/macOS/Windows): Copy file to clipboard (Ctrl+V paste)

---

## Part 6: Authentication & Persistence

- [ ] **Fix guest persistence** — Store "logged in as guest" flag in DB, don't show login screen on every app launch
- [ ] **Add theme/language selector on login screen** — 
  - Sun/Moon icon for theme toggle
  - Language dropdown from localizations

---

## Part 7: UI/UX Polishing

- [ ] **Add blur effect to Top Bar** — Library/Search/Settings header should blur content behind (like App Store)
- [ ] **Add blur effect to Bottom Nav Bar** — Same blur effect for bottom navigation
- [ ] **Add blur effect to Book Details screen** — Replace black background behind cover with beautiful blur effect
- [ ] **Redesign Top Bar & Bottom Nav Bar** — More beautiful typography, update fonts throughout the app
- [ ] **Add platform-specific permissions** — 
  - Android: Update manifest permissions
  - iOS/macOS: Update Info.plist permissions

---

## Implementation Phases

### Phase 1: Critical — Reader & Search (Week 1)

**Priority:** Highest — Fixes blocking issues and core functionality

| # | Task | Part |
|---|------|------|
| 1 | Fix EPUB sliding window bug (landscape mode) | Part 1 |
| 2 | Fix images not loading in search | Part 2 |
| 3 | Fix download indicator animation | Part 1 |
| 4 | Add search filters (language + format) | Part 2 |
| 5 | Show source badge on book cards | Part 2 |
| 6 | Deduplicate search results | Part 2 |
| 7 | Fix image decoding fallback | Part 1 |

---

### Phase 2: High — Core Features (Week 2)

**Priority:** High — Major feature additions

| # | Task | Part |
|---|------|------|
| 1 | Rewrite Z-Library API from Python to Dart | Part 3 |
| 2 | Add dual-source support in Settings | Part 3 |
| 3 | Merge search results from both sources | Part 3 |
| 4 | Update reader settings UI (compact) | Part 4 |
| 5 | Add color palette selector | Part 4 |
| 6 | Add brightness control | Part 4 |
| 7 | Make progress bar interactive | Part 4 |
| 8 | Add PDF reader features (progress, TOC, search) | Part 1 |
| 9 | Fix EPUB page count calculation | Part 1 |

---

### Phase 3: Medium — UX Improvements (Week 3)

**Priority:** Medium — Quality of life improvements

| # | Task | Part |
|---|------|------|
| 1 | Add author/genre/format filters to library | Part 5 |
| 2 | Add genre field to database | Part 5 |
| 3 | Humanize file size display | Part 5 |
| 4 | Add share book functionality | Part 5 |
| 5 | Fix guest persistence | Part 6 |
| 6 | Add theme/language selector on login screen | Part 6 |
| 7 | Add blur effects (Top Bar, Bottom Nav, Book Details) | Part 7 |
| 8 | Redesign Top Bar & Bottom Nav Bar | Part 7 |

---

### Phase 4: Low — Nice to Have (Week 4)

**Priority:** Low — Polish and edge cases

| # | Task | Part |
|---|------|------|
| 1 | Add Open Library / Google Books API integration | Part 5 |
| 2 | Add platform-specific permissions | Part 7 |
| 3 | Add cancel download functionality | Part 1 |
| 4 | Hide downloaded book cards from search | Part 1 |
| 5 | Add download retry handling | Part 2 |
| 6 | Save reader settings to DB | Part 4 |

---

## Task Mapping (Original FIXES.md → PLAN.md)

| Original # | Part | Description |
|------------|------|-------------|
| 1 | Part 2 | Fix images not loading in search |
| 2 | Part 2 | Add search filters (language + format) |
| 3 | Part 3 | Rewrite Z-Library API + dual-source settings |
| 4 | Part 2 | Show source badge on book cards |
| 5 | Part 2 | Deduplicate search results |
| 6 | Part 1 | Fix EPUB sliding window bug |
| 7 | Part 7 | Add platform-specific permissions |
| 8 | Part 4 | Add color palette selector |
| 9 | Part 4 | Update reader settings UI (compact) |
| 10 | Part 4 | Add brightness control |
| 11 | Part 4 | Make progress bar interactive |
| 12 | Part 1 | Add PDF reader features |
| 13 | Part 1 | Fix download indicator animation |
| 14 | Part 1 | Add cancel download functionality |
| 15 | Part 1 | Hide downloaded book cards from search |
| 16 | Part 5 | Add author/genre/format filters |
| 17 | Part 1 | Fix image decoding fallback |
| 18 | Part 5 | Add genre field + Open Library/Google Books API |
| 19 | Part 1 | Fix EPUB page count calculation |
| 20 | Part 6 | Fix guest persistence |
| 21 | Part 7 | Add blur effect to Top Bar |
| 22 | Part 7 | Add blur effect to Book Details screen |
| 23 | Part 5 | Humanize file size display |
| 24 | Part 5 | Add share book functionality |
| 25 | Part 6 | Add theme/language selector on login screen |
| 26 | Part 7 | Redesign Top Bar & Bottom Nav Bar |

---

## Notes

- **Total Tasks:** 26 original items → 35 actionable tasks
- **Estimated Timeline:** 4 weeks (1 week per phase)
- **Dependencies:**
  - Phase 2 requires Phase 1 completion (stable reader)
  - Phase 3 requires Phase 2 completion (search working)
  - Phase 4 can be done in parallel with Phase 3

---

*Last updated: March 9, 2026*
