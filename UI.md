# Lira UI and design system

## Visual language

The light theme takes its warm paper, ink, stone and terracotta direction from the [Anthropic brand palette](https://github.com/anthropics/skills/blob/main/skills/brand-guidelines/SKILL.md). It is a Lira interface, not a copy of Claude's product UI.

| Role | Light | Dark |
|---|---|---|
| App canvas | `#FAF9F5` | `#191817` |
| Cards, dialogs, panels | `#FFFFFF` | `#252320` |
| Main text | `#141413` | `#F2F0E8` |
| Secondary text | `#6B695F` | `#B9B5A9` |
| Primary controls/text | `#AD5036` | `#E29A7E` |

The reference orange `#D97757` is darkened for small foreground text and white-on-primary controls in the light theme. Use semantic `ColorScheme` roles rather than copying hex values into screens. Olive and blue distinguish secondary/informational roles, including search sources. Errors use `error`/`onError` and their container variants.

Book covers, PDF content, saved annotation colors and explicitly chosen reading backgrounds are content, not chrome. Do not recolor them to match the app theme.

## Typography and tokens

- **Inter**: controls, forms, body copy, navigation, metadata.
- **Lora**: app/page headings and other editorial titles.
- Both variable fonts are bundled in `assets/fonts`, work offline and include Cyrillic glyphs. OFL license texts are bundled and registered with Flutter's license registry.
- Spacing: `AppSpacing` — 4, 8, 12, 16, 24, 32, 48, 64.
- Radii: `AppRadius` — 8, 12, 20, 28.
- Content width: `AppLayout.contentMaxWidth` (1120); forms/sheets use `formMaxWidth` (640).
- Interactive targets use `AppLayout.minTouchTarget` (48). Labels wrap rather than shrinking below the type scale.
- Density: page gutters and header padding are 12; surface bodies default to 12, book-card bodies to 8; grid gaps are 12 and section gaps 16. Reserve 24+ for deliberate separation, not default padding. Compact chrome does not change reader content margins or saved reading preferences.

Implementations live in `lib/core/theme/app_theme.dart` and `app_tokens.dart`. Themes are constructed once, not reallocated on every app rebuild.

## Shared components

`lib/core/widgets/app_components.dart` supplies:

- `AppSurface`: outlined Material surface with 12 px default inner padding and optional InkWell interaction; no backdrop blur or colored glow.
- `AppPageHeader`: shared editorial page heading with 12 px padding, optional subtitle, leading control and actions.
- `AppSection`: settings/form grouping with a shared heading and surface.
- `AppEmptyState`: empty, initial and error presentations with optional action.
- `AppBadge`: compact metadata/source labels; long labels ellipsize within the available width.
- `AppSearchField`: common input decoration, clear action and optional search submission action.
- `AppStateTransition`: keyed state changes; outgoing children cannot receive input or focus.
- `showAppDialog` / `showAppBottomSheet`: shared presentation, insets and motion. Bottom sheets provide their own drag handle; content must not draw a second one.

Use the standard Material buttons, chips, switches, sliders, inputs, menus, progress indicators and tooltips. Their appearance is defined centrally by `AppTheme`; screens should not establish competing button/form systems.

## Navigation and motion

`MainShell` uses a 192 px navigation rail at widths of 900 or more and a normal bottom `NavigationBar` below that breakpoint. The scaffold reserves navigation space: pages must not add legacy padding for an overlaid glass navigation bar.

Tabs retain their subtree, scroll position and query state in an `IndexedStack`; only the selected tab's tickers run. A short fade/translation introduces a newly selected tab without recreating all tabs. Resizing between rail and bottom navigation preserves the content subtree.

`AppMotion` defines 140 ms interaction, 220 ms standard and 320 ms sheet durations with `easeOutCubic`. Resolve custom durations through `AppMotion.duration(context)` so system reduced-motion preferences disable decorative movement. Dialogs, sheets, reader chrome, download state and tab transitions share this policy.

Desktop route transitions use a subtle fade/translation. Android predictive back and iOS interactive back transitions remain native. Gesture arbitration windows, network timeouts and database debounce intervals are not decorative animation durations.

Never wrap a live EPUB/PDF engine in a keyed `AnimatedSwitcher`: progress, selection and controller identity must survive chrome/theme rebuilds.

## Screens

- **Auth (`/login`)**: bounded form, local login/register state and guest entry. Backend authentication is still not implemented.
- **Library (`/`)**: responsive shelf, local search, import, long-press deletion, navigation to book details; shared empty/error presentations.
- **Book details (`/book-detail`)**: bounded adaptive cover/metadata layout, edit/delete actions and entry to the reader.
- **Search tab**: Anna's Archive/Z-Library source selection, format/sort controls, responsive result grid and partial/error/empty states, download progress and cancellation.
- **Settings tab**: profile/account, source credentials, appearance/language, proxy and application version, grouped on common surfaces.
- **Reader (`/reader`)**: themed chrome, TOC, selections/notes, an annotations sheet with separate Highlights/Bookmarks tabs, and settings. The top bar toggles a bookmark for the current reading position. Both bars animate in/out by their own height; note-editor keyboards do not resize the book behind the dialog. EPUB/PDF parsing, geometry and persistence remain the reader subsystem's responsibility; see [READER.md](READER.md).

The bookmark button remains active within a small EPUB text neighborhood (±400 UTF-16 characters in one spine document) or the same PDF page; toggling it removes the matched saved bookmark without changing its navigation target. On Android, status and navigation bars are hidden with reader chrome and shown with it, on load errors, and after leaving the reader.

Library and search cards have full-bleed artwork above an inset metadata/action body. Images use top-centered `BoxFit.cover`, preserve their aspect ratio and may crop to fill the cover area; the card surface clips the top corners. Book details use the same artwork treatment. Library and search grids increase tile height with text scaling; progress and cancellation remain inside the search-card body.

A fresh reader settings profile starts on warm paper. Saved reader settings, including old dark/white backgrounds, remain unchanged; app theme changes do not overwrite them. Resetting reader settings returns to warm paper. Reading controls and background swatches have localized semantic labels/tooltips.

Reader controls have visible localized names and numeric values. Page margins range from 8–64 logical pixels on phones and 8–240 on desktop/large tablets, with safe per-page clamping in the renderer. The font menu previews 11 bundled offline Latin/Cyrillic families: Inter, Lora, Literata, Source Serif 4, PT Serif, Noto Serif, Merriweather, Roboto Slab, PT Sans, Noto Sans and Roboto. Existing generic/system selections remain usable; UI theme fonts and default reader settings are unchanged.

## Verification checklist

Run the real application (`flutter run -d macos`, or a supported connected device), not a standalone gallery of copied components:

1. Check light/dark and English/Russian on auth, library, details, search, settings and reader chrome.
2. Resize through the 900 px breakpoint; check 360 px width and increased text size. Check full-bleed artwork, long titles/badges, missing covers and search-card progress/cancellation. Scroll settings and forms with the keyboard open.
3. Preserve library/search input and scroll state when switching tabs and resizing. Check filters, partial results, errors and download controls.
4. Open real EPUB/PDF, toggle chrome in both directions, use TOC/settings/highlights/bookmarks, then close and reopen without losing reading position. In both EPUB modes, open/save/cancel a note with the keyboard visible: the underlying book must not resize or jump.
5. Change app theme with an explicitly chosen reading background and saved highlights; content preferences must remain intact.
6. Enable reduced motion and check navigation, dialogs, sheets and reader controls. Check keyboard focus and disabled states.
7. On Android, verify immersive reading, showing/hiding chrome, background/resume, note-keyboard dismissal and exit back to the library. System bars must follow reader chrome and must not remain hidden outside the reader.

`dart analyze lib` checks the application sources. Reader regression commands and native PDFium prerequisites remain in [READER.md](READER.md).
