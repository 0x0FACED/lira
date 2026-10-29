<div align="center">

<img src="docs/images/lira-icon.png" alt="Lira app icon" width="112" height="112" />

# Lira

### Your books. Your pace. Your space.

A free EPUB and PDF reader for the books you love and the ones you have yet to discover.<br />
Read offline, keep the lines that matter, and make every page feel like yours.

**Android · iOS · Windows · macOS · Linux**

<a href="https://github.com/0x0FACED/lira/releases/latest"><img src="https://img.shields.io/badge/Download-Lira-AD5036?style=for-the-badge" alt="Download Lira" /></a>

[Why Lira](#why-lira) · [Choose your download](#get-lira) · [Getting started](#your-first-chapter) · [Release notes](CHANGELOG.md)

</div>

<p align="center">
  <img src="docs/images/preview.png" alt="Lira's light library with book covers alongside its dark, distraction-free reader" width="100%" />
</p>

<p align="center"><sub>Real app previews, cropped and arranged for this image. Shown in Russian; English is available too.</sub></p>

## Why Lira

A good reader should make it easier to stay with a book. Lira keeps your library, your reading tools, and your next discoveries close—without making the interface the main event.

- **Bring the books you already have.** Import EPUB and PDF files from your device and give them a home on your own shelf.
- **Leave the connection behind.** Once a book is on your device, you can read it offline. Your progress, highlights, notes, and bookmarks are saved locally.
- **Keep more than your place.** Bookmark a reading position, highlight a passage, add a thought, and jump back when you need it. Highlights and bookmarks have separate tabs. Close the book and return to where you left off.
- **Make the page yours.** For EPUBs, adjust the font, text size, line spacing, margins, and reading background. Scroll vertically, turn pages horizontally, or use a two-page spread when there is room.
- **Read both formats their own way.** EPUB text adapts to your page; PDFs keep their original layout. Both share the same library and reading tools.
- **Find your next read.** Discover recent articles from Cloudflare and GitHub Engineering, browse new RFCs, or search Anna's Archive and Z-Library for books. Choose which sources appear and participate in search. Source availability and access requirements vary.

Warm light and dark themes, layouts for phones and desktops, and English and Russian interfaces make Lira feel at home wherever you like to read.

<details>
<summary><strong>A closer look at the EPUB reading controls</strong></summary>
<br />
<p align="center">
  <img src="docs/images/reading-settings.png" alt="EPUB controls for reading mode, font, text size, line spacing, margins, brightness, and page background" width="320" />
</p>
</details>

## Get Lira

**[Download the latest release](https://github.com/0x0FACED/lira/releases/latest)** and choose the file for your device:

| Your device | Download | Before you open it |
| --- | --- | --- |
| **Android** | [APK](https://github.com/0x0FACED/lira/releases/latest/download/app-release.apk) | Install the APK directly on your device. You may need to allow installation from your browser or file manager. |
| **Windows** | [Windows ZIP](https://github.com/0x0FACED/lira/releases/latest/download/lira-windows.zip) | Extract the archive and launch the app. |
| **macOS** | [macOS DMG](https://github.com/0x0FACED/lira/releases/latest/download/Lira.dmg) | Requires macOS 11 or later. The app is not Developer ID-signed or notarized; Gatekeeper may require you to allow it in Privacy & Security. |
| **Linux** | [Linux ZIP](https://github.com/0x0FACED/lira/releases/latest/download/lira-linux.zip) | Extract the archive and run `lira` on a GTK 3 desktop. |
| **iOS** | [Unsigned IPA](https://github.com/0x0FACED/lira/releases/latest/download/lira-ios-unsigned.ipa) | Sign the IPA with AltStore, Sideloadly, or another signing tool before installation. It is not a TestFlight or App Store download. |

[Browse all releases](https://github.com/0x0FACED/lira/releases) for older builds and the Android App Bundle.

## Your first chapter

1. **Open Lira and continue as a guest.** You do not need a Lira account to read your own files.
2. **Add a book.** Import an EPUB or PDF, or open **Discover** to search for a title through a supported source.
3. **Settle in.** Open the book, adjust your EPUB reading settings, and start reading. Your place is saved as you go.

### Discover books, articles and RFCs

Open **Discover → Sources** to enable sources and arrange their order. The same selection controls the overview and global search. Sources are searchable by name or description and can be filtered by **topic**, **content language** and **selected only**. These filters combine without changing your saved selection or order. New sources are opt-in: updating preserves existing choices, including an intentionally empty selection. Turning a source off never removes saved materials.

Alongside Cloudflare, GitHub Engineering and the official RFC catalog, Discover includes:

| Source | Content language | Topics |
| --- | --- | --- |
| [Батрахоспермум](https://batrachospermum.ru/) | Russian | Biology, wildlife and unusual discoveries |
| [Элементы](https://elementy.ru/) | Russian | Science, evolution, nature and space |
| [Our World in Data](https://ourworldindata.org/) | English | Economics, health, population and the environment |
| [JSTOR Daily](https://daily.jstor.org/) | English | History, culture and research |
| [Aeon](https://aeon.co/) | English | Philosophy, psychology, science and culture |
| [Mongabay](https://news.mongabay.com/) | English | Wildlife, biodiversity and conservation |

Enabled publication sources appear as horizontal shelves. Tap anywhere on a source heading to open its publications and search only that source. Desktop shelves also support arrow buttons and keyboard navigation. Book catalogs remain search-only rather than displaying invented recommendations.

Global search separates **Books**, **Articles** and **RFC**. Article search covers the recent publications returned by each feed, not the complete website archive. RFC search uses the official full index, including document numbers, titles, abstracts and authors. Previously loaded publication lists remain available when a refresh fails.

Open a publication to **Read in Lira**, **Save to library** or **Open original**. Articles and RFCs are converted from their full publisher documents to local EPUBs with images, captions, section navigation and source links; feed summaries are not substituted for the full text. Our World in Data charts use the publisher's static images, retaining chart selections and links to the interactive originals. Other interactive, audio and video embeds link to their originals rather than running inside the reader. Reading alone does not add an item to your library; explicitly saving keeps the same local copy, progress and annotations. Saved text is not silently replaced when the publisher updates a page.

### Book-source access and mirrors

**Z-Library:** open **Settings → Z-Library → Z-Library mirrors**, or the mirror action on its source page. Edit one HTTPS origin per line, in priority order, then Save. Search, sign-in and downloads use that same approved list. Mirrors are alternate addresses of one catalog: Lira fails over to another address rather than merging duplicate searches from every mirror.

**Find mirrors** reads [Z-Library's official access-information file](https://z-library.biz/access-info). Review the suggestions, add the addresses you trust, and Save before they become active. Remote suggestions never silently expand the domains allowed to receive your session. Availability and browser verification can differ between mirrors and networks.

Z-Library downloads use the file-download action, not **Read Online**, and keep the same User-Agent as the catalog's browser-verified session. Lira opens the downloaded EPUB/PDF before adding it to the library; HTML pages and unreadable files are rejected, and another available download link is tried. EPUB covers come from the book's embedded image at its original resolution, while PDF covers are rendered from the first page. The catalog thumbnail is only a fallback when no local cover is available. Previously saved invalid downloads must be removed and downloaded again after updating.

**Anna’s Archive:** the native client reads the current EPUB/PDF catalog and distinguishes a genuine empty result from a failed or challenged request. If the website requires verification, open **Settings → Anna’s Archive → Anna’s Archive access** or the access action on its source/error page. Complete the site's normal verification in a browser, then copy the Cookie and User-Agent values from a successful `/search` request into the local session editor.

Browser clearance can be bound to the domain, exit IP and User-Agent. Use the same connection or proxy in the browser and Lira; a direct browser session does not clear a blocked SOCKS exit. Sessions stay scoped to their selected official origin and are not sent to other mirrors or download hosts. Lira never silently disables your proxy to make a session work. A source refusing the connection even in a browser still requires legitimate access from that connection.

SOCKS5 settings in Lira are the explicit application-level routing policy; inherited `HTTP_PROXY`/`HTTPS_PROXY` variables are not layered inside that connection. Normal TLS certificate verification remains enabled.

### Updating Lira

Open **Settings → App updates** to check the latest stable GitHub release. Lira checks when you first open Settings; **Check for updates** checks again.

- **Android:** download the APK in the app, then tap **Install update**. The download continues when you switch tabs. Lira verifies its size and SHA-256, and checks the APK's package, version, and signing key before opening Android's installer. If Android requests permission to install unknown apps, allow it for Lira and tap **Install update** again. Updating keeps your library and settings; an APK signed with a different key cannot update your installation.
- **iOS, macOS, Windows, Linux:** **Open release on GitHub** opens the release page in your browser. Download and install the appropriate file there; the platform-specific signing requirements above still apply.

## A few things worth knowing

<details>
<summary><strong>Does Lira work offline?</strong></summary>

Yes. Imported and downloaded books can be read without an internet connection. Book search and downloading require a connection and access to the selected source.

</details>

<details>
<summary><strong>Will my library sync between devices?</strong></summary>

Not currently. Your books, reading progress, highlights, notes, and bookmarks are stored on the device you are using. Lira is available on multiple platforms, but cloud sync is not implemented.

</details>

<details>
<summary><strong>How does built-in book search work?</strong></summary>

Lira connects to Anna's Archive and Z-Library for books, supported blog feeds for recent articles, and the official RFC index for specifications. Availability depends on the source, your network, and any required credentials. Choose discovery/search sources in **Discover → Sources**; Z-Library credentials and proxy settings remain in Settings.

Use only books and services you have the right to access and download.

</details>

<details>
<summary><strong>Can I use Lira in a browser?</strong></summary>

Lira is a native application for Android, iOS, Windows, macOS, and Linux. A web version is not currently supported.

</details>

## For the curious and the builders

Lira is built with Flutter, with native Flutter EPUB rendering and PDF viewing through `pdfrx`. Riverpod manages application state, and Drift stores the local library and reading data.

<details>
<summary><strong>Build from source</strong></summary>

Use **Flutter 3.41.6**, the version used by CI, and the native development tools for your target platform.

```bash
git clone https://github.com/0x0FACED/lira.git
cd lira
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Explore the implementation:

- [Reader module architecture](lib/features/reader/README.md)
- [UI theme](lib/core/theme/) and [shared components](lib/core/widgets/app_components.dart)
- [Release and signing guide](RELEASE.md)
- [Changelog](CHANGELOG.md)

</details>

Found a book that does not render correctly, or have an idea that would make reading better? **[Open an issue](https://github.com/0x0FACED/lira/issues/new)** with your platform, app version, and a description of what happened. Only attach a book or document if you have permission to share it.

---

<p align="center">
  <strong>Your next chapter is waiting.</strong><br />
  <a href="https://github.com/0x0FACED/lira/releases/latest">Get Lira</a>
</p>
