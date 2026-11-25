# Lira user guide

[Back to the README](../README.md) · [Download Lira](https://github.com/0x0FACED/lira/releases/latest)

## Start reading

1. **Open Lira and choose Continue to library.** Reading and local QR sync do not need an account. Server accounts and password sign-in are not available.
2. **Add a book.** Import an EPUB or PDF, or open **Discover** to search for a title through a supported source.
3. **Settle in.** Open the book, adjust your EPUB reading settings, and start reading. Your place is saved as you go.

You can also open **Settings → Customize reader** to try the controls on the bundled Russian/English EPUB without importing a book.

## Customize EPUB reading

Open **Aa** in the reader to change the current page. The settings appear alongside the book on larger screens or in a bottom panel on phones. Adjust the typeface, weight, size, line and paragraph spacing, first-line indent, alignment, margins, and hyphenation. Switch between scrolling and pagination; a two-page spread is available in paginated mode on wider screens.

The **Colors** tab offers Day, Paper, Dark, and Warm evening palettes, custom text and background colors, text contrast, and separate page dimming. You can preview changes on the current book or the bundled sample.

## Edit a saved book

Open its details and select the pencil. Edit the title and author in place. Use **+** next to **Genres** or **Tags** to add a chip; the chip grows as you type. Tap an existing chip to rename it, or use its **×** to remove it. Press **Save** in the header to apply the changes, or **×** in the header to discard the draft. File details and reading progress are read-only.

## Fill in book details with Open Library

Open a saved book's details and choose **Find in Open Library**. Search by ISBN for a specific edition, or edit the title and author to look for candidates. Select a result to compare it with the local entry, then choose which fields and cover to apply. Lira adds recognized genres without replacing your genres or tags. The saved cover is available offline.

**Settings → Library metadata → Fill missing details from Open Library** is off by default. When enabled, Lira looks up new EPUB imports and downloads only if the file contains one valid ISBN and the catalog confirms one edition. The lookup runs after the book is saved. It fills missing details without replacing titles from the file or overwriting local edits. It only replaces a usable embedded cover automatically if the same edition has a substantially larger image and the original was small.

Automatic matching sends the ISBN, not the book file. Manual searches send the ISBN or the title and author you enter. Open Library is optional: importing and reading still work without it.

## Discover books, articles and RFCs

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

Enabled publication sources appear as horizontal shelves. Choose **View all** beside a source to open its publications and search only that source. Desktop shelves also support arrow buttons and keyboard navigation. Book catalogs remain search-only rather than displaying invented recommendations.

Global search separates **Books**, **Articles** and **RFC**. Article search covers the recent publications returned by each feed, not the complete website archive. RFC search uses the official full index, including document numbers, titles, abstracts and authors. Previously loaded publication lists remain available when a refresh fails.

Open a publication to **Read in Lira**, **Save to library** or **Open original**. Articles and RFCs are converted from their full publisher documents to local EPUBs with images, captions, section navigation and source links; feed summaries are not substituted for the full text. Our World in Data charts use the publisher's static images, retaining chart selections and links to the interactive originals. Other interactive, audio and video embeds link to their originals rather than running inside the reader. Reading alone does not add an item to your library; explicitly saving keeps the same local copy, progress and annotations. Saved text is not silently replaced when the publisher updates a page.

## Book-source access and mirrors

**Z-Library:** open **Settings → Z-Library → Z-Library mirrors**, or the mirror action on its source page. Edit one HTTPS origin per line, in priority order, then Save. Search, sign-in and downloads use that same approved list. Mirrors are alternate addresses of one catalog: Lira fails over to another address rather than merging duplicate searches from every mirror.

**Find mirrors** reads [Z-Library's official access-information file](https://z-library.biz/access-info). Review the suggestions, add the addresses you trust, and Save before they become active. Remote suggestions never silently expand the domains allowed to receive your session. Availability and browser verification can differ between mirrors and networks.

Z-Library downloads use the file-download action, not **Read Online**, and keep the same User-Agent as the catalog's browser-verified session. Lira opens the downloaded EPUB/PDF before adding it to the library; HTML pages and unreadable files are rejected, and another available download link is tried. EPUB covers come from the book's embedded image at its original resolution, while PDF covers are rendered from the first page. The catalog thumbnail is only a fallback when no local cover is available. Previously saved invalid downloads must be removed and downloaded again after updating.

**Anna’s Archive:** the native client reads the current EPUB/PDF catalog and distinguishes a genuine empty result from a failed or challenged request. If the website requires verification, open **Settings → Anna’s Archive → Anna’s Archive access** or the access action on its source/error page. Complete the site's normal verification in a browser, then copy the Cookie and User-Agent values from a successful `/search` request into the local session editor.

Browser clearance can be bound to the domain, exit IP and User-Agent. Use the same connection or proxy in the browser and Lira; a direct browser session does not clear a blocked SOCKS exit. Sessions stay scoped to their selected official origin and are not sent to other mirrors or download hosts. Lira never silently disables your proxy to make a session work. A source refusing the connection even in a browser still requires legitimate access from that connection.

SOCKS5 settings in Lira are the explicit application-level routing policy; inherited `HTTP_PROXY`/`HTTPS_PROXY` variables are not layered inside that connection. Normal TLS certificate verification remains enabled.

In **Settings → Network**, enter the SOCKS5 host (DNS name, IPv4 or IPv6) and port. **Check connection** tests those fields with a short HTTPS request to Open Library, even while the proxy is off. It does not save or enable the proxy, and success does not guarantee access to other sources. **Save** applies the address; the switch controls whether Lira uses it. Proxies that require authentication are not supported.

## Export quotes and notes

In the reader's annotations panel, use **Highlights** to search quote text and notes. Color and **With note** filters intersect; whitespace-only notes do not count as notes. Check individual quotes or **Select visible**, then **Export**. Choose all saved, current visible results or selected visible results, and Markdown or plain text. Book title, author, format and dates are included; EPUB reading-order chapters and PDF pages are added when the saved position is recognized. Unknown legacy locators are omitted, not displayed as invented chapters.

Desktop platforms open a save dialog. Android/iOS open the system share sheet with a real UTF-8 `.md` or `.txt` file, which can be saved or sent through installed applications. The copy action on a saved quote or an active book selection includes the original text, book title and author.

## Local QR synchronization

1. Connect both devices to the same Wi-Fi network or personal hotspot and open **Settings → Local sync** in Lira.
2. On one device choose **Show invitation QR code**. On the other choose **Scan QR code**, import an image of the code, or paste a copied invitation.
3. Approve the request on the device displaying the code. Approval exchanges the entire saved library, reading positions, highlights, notes and bookmarks in both directions.
4. Keep both applications open until **Sync complete**. Leaving the screen or putting the application in the background stops the session. Start a new invitation for the next exchange.

Invitations expire after five minutes; an approved exchange can continue longer. QR camera scanning is supported on Android, iOS and macOS. Image import and copied invitations also work on Windows and Linux. Camera/local-network permission and firewall access may be required; isolated guest Wi-Fi networks can prevent devices from reaching each other. The transport uses local IPv4 connections directly, bypassing Lira's source-access SOCKS/HTTP proxy, and does not use cloud relay or discovery services.

Files and annotation metadata are authenticated and encrypted with AES-256-GCM, using a fresh secret in each invitation. Treat the QR and copied invitation as a secret, share it only with your intended device, and approve only the request you initiated. File hashes are checked before import. Matching is by SHA-256 of the complete EPUB/PDF file, not title, so different editions do not share incompatible positions. A missing local file can be restored without creating another library entry.

Conflicts use the saved modification timestamp and a stable device-ID tie-break, not the highest reading percentage; keep device clocks correct. Deleted highlights and bookmarks remain deleted after merging. Deleting a book is local: it does not remove the other device's copy and suppresses automatic re-import until you explicitly import/save that book again. Genres, tags, library layout and sort order remain device-local, as do unsaved article previews, source credentials, account state and appearance settings. There is no automatic/background or cloud synchronization. Interrupted exchanges may have saved verified changes on one device; starting a new session safely merges them again.

Each protocol message is limited to 16 MiB of serialized metadata (at most 100,000 records per snapshot), and each book file to 2 GiB. A session exceeding these limits fails rather than silently omitting books or annotations.

## Updating Lira

Open **Settings → App updates** to check the latest stable GitHub release. Lira checks when you first open Settings; **Check for updates** checks again.

- **Android:** download the APK in the app, then tap **Install update**. The download continues when you switch tabs. Lira verifies its size and SHA-256, and checks the APK's package, version, and signing key before opening Android's installer. If Android requests permission to install unknown apps, allow it for Lira and tap **Install update** again. Updating keeps your library and settings; an APK signed with a different key cannot update your installation.
- **iOS, macOS, Windows, Linux:** **Open release on GitHub** opens the release page in your browser. Follow the [installation instructions for your platform](../README.md#get-lira).

## Frequently asked questions

<details>
<summary><strong>Does Lira work offline?</strong></summary>

Yes. Imported and downloaded books can be read without an internet connection. Book search and downloading require a connection and access to the selected source.

</details>

<details>
<summary><strong>Will my library sync between devices?</strong></summary>

Yes, through manual [local QR synchronization](#local-qr-synchronization), including the EPUB/PDF files themselves. Both devices must be reachable on the same local network and keep Lira open. Cloud and automatic background sync are not implemented.

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
