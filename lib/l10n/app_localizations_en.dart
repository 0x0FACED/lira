// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Lira';

  @override
  String get signIn => 'Sign In';

  @override
  String get register => 'Register';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get guestLocalOnly => 'Books and progress will be stored locally only';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register';

  @override
  String get haveAccountSignIn => 'Already have an account? Sign In';

  @override
  String get yourLibrary => 'Your personal library reader';

  @override
  String get fillAllFields => 'Please fill in all fields';

  @override
  String get library => 'Library';

  @override
  String get interfaceFontSize => 'Interface font size';

  @override
  String get interfaceFontSizeHint =>
      'Does not change book text size in the reader.';

  @override
  String get libraryBooksPerRow => 'Books per row';

  @override
  String get libraryTwoBooksPerRow => '2 books per row';

  @override
  String get libraryThreeBooksPerRow => '3 books per row';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get noBooks => 'No books in library';

  @override
  String get noBooksHint => 'Tap + to add your first book';

  @override
  String get importBook => 'Import Book';

  @override
  String get deleteBook => 'Delete Book';

  @override
  String deleteBookConfirm(String title) {
    return 'Are you sure you want to delete $title?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get readBook => 'Read';

  @override
  String get openBook => 'Open';

  @override
  String get duplicateBookError => 'This book already exists in your library.';

  @override
  String get searchBooks => 'Search Books';

  @override
  String get searchBooksHint =>
      'Search for books online will be available in a future update.\nYou\'ll be able to search z-library and download books directly.';

  @override
  String get profile => 'Profile';

  @override
  String get signedIn => 'Signed in';

  @override
  String get guest => 'Guest';

  @override
  String get guestSyncHint =>
      'Stored on this device · local QR sync needs no account';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get account => 'Account';

  @override
  String get logout => 'Logout';

  @override
  String get signInComingSoon => 'Sign in coming soon';

  @override
  String get registrationComingSoon => 'Registration coming soon';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageEn => 'English';

  @override
  String get themeComingSoon => 'Theme toggle coming soon';

  @override
  String get languageComingSoon => 'Language selector coming soon';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get editBook => 'Edit Book';

  @override
  String get editBookTitle => 'Title';

  @override
  String get editBookAuthor => 'Author';

  @override
  String get save => 'Save';

  @override
  String get details => 'Details';

  @override
  String get size => 'Size';

  @override
  String get pages => 'Pages';

  @override
  String get added => 'Added';

  @override
  String get unknown => 'Unknown';

  @override
  String get tableOfContents => 'Table of Contents';

  @override
  String get tocComingSoon => 'TOC will be available in a future update.';

  @override
  String get readerSettings => 'Reader Settings';

  @override
  String get readerPreviewTitle => 'Reader preview';

  @override
  String get readerPreviewBook => 'Sample book';

  @override
  String get readerCurrentBook => 'Current book';

  @override
  String get readerPreviewError => 'Could not open the sample book.';

  @override
  String get readerCloseSettings => 'Close reader settings';

  @override
  String get readerCustomize => 'Customize reader';

  @override
  String get readerVertical => 'Vertical';

  @override
  String get readerHorizontal => 'Horizontal';

  @override
  String get readerFont => 'Font';

  @override
  String get readerTwoPageSpread => 'Two-page spread';

  @override
  String get highlightSaved => 'Highlight saved';

  @override
  String get errorLoadingBook => 'Error loading book';

  @override
  String get errorLoadingProgress => 'Error loading progress';

  @override
  String get failedToInitReader => 'Failed to initialize reader engine.';

  @override
  String get noChapters => 'This EPUB has no readable chapters.';

  @override
  String get searchLibrary => 'Search library...';

  @override
  String get libraryReadingProgress => 'Reading progress';

  @override
  String get downloadCancelled => 'Download cancelled';

  @override
  String get zLibrary => 'Z-Library';

  @override
  String get zLibraryLogin => 'Z-Library Login';

  @override
  String get zLibraryEmail => 'Email';

  @override
  String get zLibraryPassword => 'Password';

  @override
  String zLibraryLoggedIn(String email) {
    return 'Logged in as $email';
  }

  @override
  String get zLibraryNotLoggedIn => 'Not logged in to Z-Library';

  @override
  String get zLibraryLogout => 'Logout';

  @override
  String get themeLight => 'Light';

  @override
  String get proxyHost => 'Host';

  @override
  String get proxyPort => 'Port';

  @override
  String get proxyDisabled => 'Disabled';

  @override
  String get searchBothSources => 'Both sources';

  @override
  String get searchAllFormats => 'All formats';

  @override
  String get searchSort => 'Sort';

  @override
  String get searchSortRelevance => 'Relevance';

  @override
  String get searchSortTitleAsc => 'Title: A to Z';

  @override
  String get searchSortTitleDesc => 'Title: Z to A';

  @override
  String get searchSortAuthorAsc => 'Author: A to Z';

  @override
  String get searchLoading => 'Searching the shelves…';

  @override
  String get searchNoResults => 'No books found';

  @override
  String get searchNoFilterResults => 'No books match these filters';

  @override
  String get searchResetFilters => 'Reset filters';

  @override
  String get searchFailed => 'Search is unavailable';

  @override
  String get searchRetry => 'Try again';

  @override
  String get searchSourcesPartialFailure =>
      'Some sources are unavailable. Showing the results we could find.';

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get downloadBook => 'Download book';

  @override
  String get searchAnnaDescription =>
      'Find books by title, author or ISBN in Anna’s Archive.';

  @override
  String get searchZLibraryDescription =>
      'Find your next read in Z-Library. Sign in from Settings to download books.';

  @override
  String get searchBothDescription =>
      'Search Anna’s Archive and Z-Library together.';

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '$count book',
    );
    return '$_temp0';
  }

  @override
  String get highlights => 'Highlights';

  @override
  String get highlightsEmpty => 'No highlights yet';

  @override
  String get highlightsEmptyHint =>
      'Select text in the book to save a highlight or note.';

  @override
  String get highlightsLoadError => 'Could not load highlights';

  @override
  String get annotations => 'Annotations';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get bookmarksEmpty => 'No bookmarks yet';

  @override
  String get bookmarksEmptyHint =>
      'Use the bookmark button in the reader to save your place.';

  @override
  String get bookmarksLoadError => 'Could not load bookmarks';

  @override
  String bookmarkPosition(String percentage) {
    return 'Position: $percentage%';
  }

  @override
  String get addBookmark => 'Add bookmark';

  @override
  String get removeBookmark => 'Remove bookmark';

  @override
  String bookmarkSaveError(String error) {
    return 'Could not save bookmark: $error';
  }

  @override
  String bookmarkDeleteError(String error) {
    return 'Could not remove bookmark: $error';
  }

  @override
  String highlightDeleteError(String error) {
    return 'Could not delete highlight: $error';
  }

  @override
  String noteSaveError(String error) {
    return 'Could not save note: $error';
  }

  @override
  String get addNote => 'Add note';

  @override
  String get editNote => 'Edit note';

  @override
  String get noteHint => 'Your note…';

  @override
  String get copyText => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get highlightText => 'Highlight';

  @override
  String get tableOfContentsUnavailable => 'Table of contents is not available';

  @override
  String get readerSansSerif => 'Sans serif';

  @override
  String get readerSerif => 'Serif';

  @override
  String get readerMonospace => 'Monospace';

  @override
  String get readerFontSize => 'Font size';

  @override
  String get readerLineHeight => 'Line spacing';

  @override
  String get readerPageMargins => 'Page margins';

  @override
  String get readerBackground => 'Page background';

  @override
  String get readerTypography => 'Typography';

  @override
  String get readerLayout => 'Layout';

  @override
  String get readerColors => 'Colors';

  @override
  String get readerFontWeight => 'Font weight';

  @override
  String get readerParagraphIndent => 'First-line indent';

  @override
  String get readerParagraphSpacing => 'Paragraph spacing';

  @override
  String get readerEmUnit => 'em';

  @override
  String get readerHyphenation => 'Word hyphenation';

  @override
  String get readerHyphenationHint =>
      'Break words across lines using the book’s language.';

  @override
  String get readerReadingMode => 'Reading mode';

  @override
  String get readerTextAlignment => 'Text alignment';

  @override
  String get readerAlignOriginal => 'From book';

  @override
  String get readerAlignLeft => 'Left';

  @override
  String get readerAlignJustify => 'Justified';

  @override
  String get readerPalette => 'Reader palette';

  @override
  String get readerPaletteDay => 'Day';

  @override
  String get readerPalettePaper => 'Paper';

  @override
  String get readerPaletteDark => 'Readable dark';

  @override
  String get readerPaletteEvening => 'Warm evening';

  @override
  String get readerPaletteHint =>
      'Presets set page, text, link and selection colors without changing extra dimming.';

  @override
  String get readerTextColor => 'Text color';

  @override
  String get readerHexColor => 'Hex color';

  @override
  String get readerEditColor => 'Edit color';

  @override
  String get readerHexColorError =>
      'Enter six hexadecimal digits, for example #AABBCC.';

  @override
  String get readerTextContrast => 'Text contrast';

  @override
  String get readerTextContrastHint =>
      '100% uses the chosen text color. Lower values blend it toward the page background.';

  @override
  String get readerAdditionalDimming => 'Additional dimming';

  @override
  String get readerAdditionalDimmingHint =>
      'Darkens the entire page, including letters. Separate from your device’s system brightness.';

  @override
  String readerSavePositionError(String error) {
    return 'Could not save reading position: $error';
  }

  @override
  String highlightSaveError(String error) {
    return 'Could not save highlight: $error';
  }

  @override
  String bookDownloaded(String title) {
    return '“$title” added to your library';
  }

  @override
  String get updateSection => 'App updates';

  @override
  String get updateSource => 'Official releases on GitHub';

  @override
  String get updateCheckAction => 'Check for updates';

  @override
  String get updateCheckHint =>
      'Check whether a newer version of Lira is available.';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateUpToDate => 'You have the latest version.';

  @override
  String updateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String updateDownloading(String percent, String received, String total) {
    return 'Downloading: $percent · $received / $total MB';
  }

  @override
  String updateReady(String version) {
    return 'Version $version is ready to install';
  }

  @override
  String get updateOpeningInstaller => 'Opening the system installer…';

  @override
  String updateDownloadAction(String size) {
    return 'Download APK · $size MB';
  }

  @override
  String get updateInstallAction => 'Install update';

  @override
  String get updateInstallHint =>
      'Android will ask you to confirm installation. Your library and settings will be kept.';

  @override
  String get updateReleaseAction => 'Open release on GitHub';

  @override
  String get updateExternalHint =>
      'Download and install the version for your device from the release page.';

  @override
  String get updateNoApk =>
      'This release has no verified APK available. Open the release page for installation options.';

  @override
  String get updateUnavailable => 'No published release is available yet.';

  @override
  String get updateNetworkError =>
      'Could not check for updates. Check your connection and try again.';

  @override
  String get updateRateLimited =>
      'GitHub\'s request limit has been reached. Try again later.';

  @override
  String get updateInvalidRelease =>
      'The release information could not be verified.';

  @override
  String get updateDownloadError =>
      'Could not download the update. Try downloading it again.';

  @override
  String get updateChecksumError =>
      'The downloaded APK failed verification. Download it again.';

  @override
  String get updatePermissionHint =>
      'Allow Lira to install unknown apps in Android settings, then tap “Install update” again.';

  @override
  String get updateSignatureError =>
      'This APK was signed with a different key and cannot update the installed app.';

  @override
  String get updateInvalidApk =>
      'This APK is not a compatible update for the installed version of Lira.';

  @override
  String get updateInstallError =>
      'Could not open the Android installer. Try again or open the release page.';

  @override
  String get updateReleaseError =>
      'Could not open the release page in your browser.';

  @override
  String get discover => 'Discover';

  @override
  String get discoverSources => 'Sources';

  @override
  String get discoverSearchHint => 'Search books, articles and RFCs';

  @override
  String get discoverSourceSearchHint => 'Search this source';

  @override
  String get discoverSourcesSearchHint =>
      'Find a source by name or description';

  @override
  String get discoverBooks => 'Books';

  @override
  String get discoverArticles => 'Articles';

  @override
  String get discoverDocuments => 'RFC';

  @override
  String get discoverSelectedOnly => 'Selected only';

  @override
  String get discoverTopic => 'Topic';

  @override
  String get discoverAllTopics => 'All topics';

  @override
  String get discoverTopicTechnology => 'Technology';

  @override
  String get discoverTopicEconomics => 'Economics';

  @override
  String get discoverTopicNature => 'Nature';

  @override
  String get discoverTopicHistory => 'History';

  @override
  String get discoverTopicCulture => 'Culture';

  @override
  String get discoverTopicPsychology => 'Psychology';

  @override
  String get discoverTopicScience => 'Science';

  @override
  String get discoverContentLanguage => 'Content language';

  @override
  String get discoverAllLanguages => 'All languages';

  @override
  String get discoverLanguageRussian => 'Russian';

  @override
  String get discoverLanguageEnglish => 'English';

  @override
  String get discoverLanguageMultilingual => 'Multilingual';

  @override
  String discoverSourceTopics(String topics) {
    return 'Topics: $topics';
  }

  @override
  String discoverSourceContentLanguage(String language) {
    return 'Content language: $language';
  }

  @override
  String discoverSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected sources',
      one: '$count selected source',
    );
    return '$_temp0';
  }

  @override
  String discoverSourcePosition(int position) {
    return 'Position $position';
  }

  @override
  String get discoverMoveUp => 'Move source up';

  @override
  String get discoverMoveDown => 'Move source down';

  @override
  String get discoverSavingSources => 'Saving selection…';

  @override
  String get discoverSourcesSaved => 'Selection saved on this device';

  @override
  String get discoverSourcesSaveError => 'Could not save your source selection';

  @override
  String get discoverNoSources => 'Choose your sources';

  @override
  String get discoverNoSourcesHint =>
      'Enable sources to see their publications and include them in search.';

  @override
  String get discoverNoMatchingSources => 'No matching sources';

  @override
  String get discoverSearchOnly => 'Ready to search';

  @override
  String get discoverSearchOnlyHint =>
      'Your selected book catalogs are search-only. Search above to find EPUB and PDF books.';

  @override
  String get discoverSearchSourceHint =>
      'Search this catalog by title, author or ISBN.';

  @override
  String get discoverSearchPrompt => 'What would you like to read?';

  @override
  String get discoverSearchPromptHint =>
      'Search only your selected sources. Switch categories to see separate results.';

  @override
  String get discoverNoMaterials => 'No publications found';

  @override
  String get discoverFeedError => 'Could not load publications';

  @override
  String get discoverSearchError => 'Could not search this source';

  @override
  String get discoverRecentOnly => 'Searches recent publications only';

  @override
  String get discoverWholeCatalog => 'Searches the full RFC catalog';

  @override
  String get discoverCachedFeed =>
      'Showing saved publications. Refresh to try again.';

  @override
  String discoverUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String get discoverRefresh => 'Refresh publications';

  @override
  String get discoverRead => 'Read in Lira';

  @override
  String get discoverSave => 'Save to library';

  @override
  String get discoverSaved => 'Saved in library';

  @override
  String discoverSavedMessage(String title) {
    return '“$title” saved to your library';
  }

  @override
  String get discoverPreparing => 'Preparing for reading…';

  @override
  String get discoverPrepareError =>
      'Could not prepare this publication. Try again.';

  @override
  String get discoverSaveError => 'Could not save this publication. Try again.';

  @override
  String get discoverOpenOriginal => 'Open original';

  @override
  String get discoverOpenOriginalError =>
      'Could not open the original in your browser.';

  @override
  String get discoverMaterialDetails => 'Publication';

  @override
  String get discoverClearAll => 'Clear selection';

  @override
  String get zLibraryMirrors => 'Z-Library mirrors';

  @override
  String get zLibraryMirrorsSettingsHint =>
      'Used for search, sign-in and downloads';

  @override
  String get zLibraryMirrorsHint =>
      'Mirrors are alternate addresses of the same catalog. Lira tries them in order when an address is unavailable; it does not send the same search to every mirror.';

  @override
  String get zLibraryMirrorsTrustWarning =>
      'Only add addresses you trust. Configured mirrors may receive your Z-Library session or sign-in credentials. Suggestions are never enabled without your review and Save.';

  @override
  String get zLibraryMirrorsField => 'Mirror addresses';

  @override
  String get zLibraryMirrorsFieldHint =>
      'One HTTPS origin per line, in priority order. You can also paste a hostname without https://.';

  @override
  String get zLibraryMirrorInvalid =>
      'Enter at least one valid HTTPS origin. Paths, query parameters and embedded credentials are not allowed.';

  @override
  String get zLibraryMirrorsSaving => 'Saving…';

  @override
  String get zLibraryMirrorsSaved => 'Mirror list saved';

  @override
  String get zLibraryMirrorsSaveError =>
      'Could not save the mirror list. Your previous list is still active.';

  @override
  String get zLibraryMirrorsFind => 'Find mirrors';

  @override
  String get zLibraryMirrorsFinding => 'Finding mirrors…';

  @override
  String get zLibraryMirrorsRestore => 'Restore known addresses';

  @override
  String get zLibraryMirrorsFound => 'Review mirror suggestions';

  @override
  String get zLibraryMirrorsReviewHint =>
      'These addresses came from Z-Library\'s access information. Review them before adding. Availability can differ across networks.';

  @override
  String get zLibraryMirrorsAddSelected => 'Add selected';

  @override
  String get zLibraryMirrorsReviewSave =>
      'Addresses added to the editor. Press Save to use the new list.';

  @override
  String get zLibraryMirrorDirectoryHint =>
      'Suggestions come from Z-Library\'s public access-information file, not an unverified third-party mirror directory.';

  @override
  String get zLibraryMirrorDirectoryOpen => 'Open official access information';

  @override
  String get zLibraryMirrorDirectoryError =>
      'Could not retrieve the official mirror list. The source may be unavailable or require browser verification. Open its access information or edit known addresses manually.';

  @override
  String get zLibraryMirrorDirectoryOpenError =>
      'Could not open the access-information page.';

  @override
  String get annaSessionTitle => 'Anna’s Archive access';

  @override
  String get annaSessionHint =>
      'Anna’s Archive may require browser verification before showing search results. After passing it legitimately, you can use that browser session here. A session is sent only to its selected official domain.';

  @override
  String get annaSessionDomain => 'Verified browser domain';

  @override
  String get annaSessionOpen => 'Open search in browser';

  @override
  String get annaSessionConnectionWarning =>
      'The browser and Lira must use the same connection or proxy exit IP and User-Agent. A session cleared without a proxy will not clear a blocked proxy. Expired verification must be completed again.';

  @override
  String get annaSessionInstructions =>
      'After verification, open browser developer tools → Network → a successful /search request → Request Headers. Copy its Cookie and User-Agent values below. Do not share these values with anyone. They are stored only on this device.';

  @override
  String get annaSessionToggleCookies => 'Show or hide browser cookies';

  @override
  String get annaSessionClear => 'Remove session';

  @override
  String get annaSessionSaved => 'Browser session saved';

  @override
  String get annaSessionCleared => 'Browser session removed';

  @override
  String get annaSessionInvalid =>
      'Choose an official domain and enter a valid Cookie header and matching User-Agent.';

  @override
  String get annaSessionSaveError => 'Could not save the browser session.';

  @override
  String get readerSearch => 'Search in book';

  @override
  String get readerSearchHint => 'Word or phrase';

  @override
  String get readerSearchPrompt =>
      'Find a passage in this book. Search works offline.';

  @override
  String get readerSearching => 'Searching…';

  @override
  String get readerSearchNoResults => 'No matches';

  @override
  String get readerSearchNoResultsHint =>
      'Try another word or a shorter phrase.';

  @override
  String get readerSearchNoPdfText =>
      'This PDF has no searchable text layer. Search does not recognize text in scanned images.';

  @override
  String get readerSearchError => 'Could not search this book';

  @override
  String get readerSearchRetry => 'Try again';

  @override
  String get readerSearchPrevious => 'Previous match';

  @override
  String get readerSearchNext => 'Next match';

  @override
  String get readerSearchFinish => 'Finish search';

  @override
  String get readerSearchReturn => 'Return to reading';

  @override
  String get readerSearchNavigationError =>
      'Could not open this location. Try again.';

  @override
  String readerSearchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
      zero: 'No matches',
    );
    return '$_temp0';
  }

  @override
  String readerSearchPosition(int current, int total) {
    return '$current of $total';
  }

  @override
  String readerSearchPage(int number) {
    return 'Page $number';
  }

  @override
  String readerSearchChapter(int number) {
    return 'Chapter $number';
  }

  @override
  String get annaSessionOpenError =>
      'Could not open Anna’s Archive in the browser.';

  @override
  String get annotationsToolsSearch => 'Search quotes and notes';

  @override
  String get annotationsToolsHasNote => 'With note';

  @override
  String get annotationsToolsClearFilters => 'Clear filters';

  @override
  String get annotationsToolsSelectVisible => 'Select visible';

  @override
  String get annotationsToolsDeselectVisible => 'Deselect visible';

  @override
  String annotationsToolsSelected(String count) {
    return 'Selected: $count';
  }

  @override
  String get annotationsToolsExport => 'Export';

  @override
  String get annotationsToolsNoMatches => 'No matching annotations';

  @override
  String get annotationsToolsNoMatchesHint =>
      'Change your search or clear the filters.';

  @override
  String get annotationsToolsSelectQuote => 'Select quote for export';

  @override
  String get annotationsToolsCopyQuote => 'Copy quote with source';

  @override
  String annotationsToolsCopyError(String error) {
    return 'Could not copy quote: $error';
  }

  @override
  String get annotationsToolsExportScope => 'Annotations to export';

  @override
  String annotationsToolsAllSaved(String count) {
    return 'All saved ($count)';
  }

  @override
  String annotationsToolsVisible(String count) {
    return 'Visible results ($count)';
  }

  @override
  String annotationsToolsSelectedVisible(String count) {
    return 'Selected visible ($count)';
  }

  @override
  String get annotationsToolsPlainText => 'Plain text';

  @override
  String get annotationsToolsSourceTitle => 'Title';

  @override
  String get annotationsToolsSourceAuthor => 'Author';

  @override
  String get annotationsToolsSourceFormat => 'Format';

  @override
  String get annotationsToolsSourceId => 'Library book ID';

  @override
  String get annotationsToolsSourceAdded => 'Book added (UTC)';

  @override
  String get annotationsToolsExportedAt => 'Exported (UTC)';

  @override
  String get annotationsToolsNote => 'Note';

  @override
  String get annotationsToolsColor => 'Color';

  @override
  String get annotationsToolsCreatedAt => 'Annotation created (UTC)';

  @override
  String get annotationsToolsChapter => 'Chapter (reading order)';

  @override
  String get annotationsToolsPage => 'Page';

  @override
  String annotationsToolsSaved(String path) {
    return 'Annotations saved: $path';
  }

  @override
  String annotationsToolsExportError(String error) {
    return 'Could not export annotations: $error';
  }

  @override
  String get localSyncTitle => 'Local sync';

  @override
  String get localSyncSettingsAction => 'Sync with another device';

  @override
  String get localSyncSettingsHint =>
      'Transfer your library and annotations over local Wi-Fi using a QR code. No account needed.';

  @override
  String get localSyncDescription =>
      'Connect both devices to the same Wi-Fi network or personal hotspot. Keep Lira open on both devices to exchange books, reading progress, highlights, notes and bookmarks in both directions. No account or cloud service is used.';

  @override
  String get localSyncSecurity =>
      'Use a trusted local network. The invitation is a secret: share it only with your other device. Before approving, compare the requesting device with the one you are connecting. Transfers are encrypted. Leaving this screen or putting Lira in the background stops the session.';

  @override
  String get localSyncMergePolicy =>
      'For conflicting changes, the most recently modified version wins. Deleted highlights and bookmarks stay deleted after merging. Deleting a book remains local and does not delete it from the other device.';

  @override
  String get localSyncHost => 'Show invitation QR code';

  @override
  String get localSyncNewSession => 'Start a new invitation';

  @override
  String get localSyncJoin => 'Join another device';

  @override
  String get localSyncScan => 'Scan QR code';

  @override
  String get localSyncScanHint =>
      'Point the camera at the invitation QR code in Lira on your other device.';

  @override
  String get localSyncCloseCamera => 'Close camera';

  @override
  String get localSyncCameraUnavailable =>
      'The camera is unavailable or permission was denied. Close the camera and import a QR image or paste an invitation instead. You can enable camera access in system settings and scan again.';

  @override
  String get localSyncDesktopScanHint =>
      'Camera scanning is not available on this platform. Import an image of the invitation QR code or paste the invitation below.';

  @override
  String get localSyncImportImage => 'Read QR code from image';

  @override
  String get localSyncImportingImage => 'Reading QR image…';

  @override
  String get localSyncInvitation => 'Paste invitation';

  @override
  String get localSyncConnect => 'Connect with invitation';

  @override
  String get localSyncShowQrHint =>
      'Scan this code on your other device, then approve its request here. The invitation expires in five minutes. Start a new session to get a fresh code.';

  @override
  String get localSyncQrLabel => 'Secret local sync invitation QR code';

  @override
  String get localSyncCopyInvitation => 'Copy invitation';

  @override
  String get localSyncCopied => 'Invitation copied';

  @override
  String get localSyncIdle => 'Ready to start a session';

  @override
  String get localSyncPreparing => 'Preparing local sync…';

  @override
  String get localSyncHosting => 'Waiting for another device';

  @override
  String get localSyncConnecting => 'Connecting to the other device…';

  @override
  String get localSyncWaitingApproval =>
      'Waiting for approval on the other device…';

  @override
  String get localSyncApproveTitle => 'A device wants to sync';

  @override
  String get localSyncApproveHint =>
      'Approve only if this is your device and you just scanned or entered this invitation. Approval shares the entire library and annotations in both directions.';

  @override
  String get localSyncApprove => 'Approve and sync';

  @override
  String get localSyncReject => 'Reject request';

  @override
  String localSyncPeer(String name) {
    return 'Other device: $name';
  }

  @override
  String get localSyncTransferring =>
      'Exchanging library and annotations… Keep both devices open.';

  @override
  String get localSyncComplete => 'Sync complete';

  @override
  String localSyncResult(
    int books,
    int progress,
    int highlights,
    int bookmarks,
  ) {
    return 'Changes on this device: books received — $books; reading progress — $progress; highlights and notes — $highlights; bookmarks — $bookmarks.';
  }

  @override
  String get localSyncFailed => 'The session ended with an error';

  @override
  String get localSyncStop => 'Stop session';

  @override
  String get localSyncTryAgain => 'Try again';

  @override
  String get localSyncStoppedBackground =>
      'The session stopped because Lira left the foreground. Start a new invitation or join again to retry.';

  @override
  String get localSyncErrorInitialization =>
      'Could not open the local library for sync. Try again.';

  @override
  String get localSyncErrorInvalidInvitation =>
      'This is not a valid Lira sync invitation. Scan or paste a fresh invitation from your other device.';

  @override
  String get localSyncErrorNoLocalAddress =>
      'No local network address is available. Connect to Wi-Fi or a hotspot, then start a new session.';

  @override
  String get localSyncErrorExpired =>
      'The invitation expired. Show a new invitation on the other device and connect again.';

  @override
  String get localSyncErrorRejected =>
      'The other device rejected the request. Start a new session if you want to try again.';

  @override
  String get localSyncErrorUnauthorized =>
      'The devices could not authenticate this session. Use a new invitation and approve only your own device.';

  @override
  String get localSyncErrorConnection =>
      'Could not reach the other device. Check that both devices are on the same local network, keep Lira open, and allow local network access through the system firewall. Then start a new session.';

  @override
  String get localSyncErrorTransfer =>
      'The transfer could not finish. Some verified changes may already have been saved. Check the connection and available storage, then start a new session; changes already received will be merged safely.';

  @override
  String get localSyncErrorCancelled =>
      'The session was cancelled. Start a new invitation or join again to retry.';

  @override
  String get localSyncErrorImage =>
      'Could not read a Lira invitation QR code from this image. Choose a clear PNG, JPEG, BMP or WebP image up to 20 MB, or paste the invitation.';

  @override
  String get localSyncQrImageType => 'QR code image';

  @override
  String get localSyncDetails => 'Security and merge rules';

  @override
  String get localSyncErrorClipboard =>
      'Could not copy the invitation. Scan the displayed QR code instead.';
}
