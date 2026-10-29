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
  String get guestSyncHint => 'Local only — sign in to sync';

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
  String get readerSettingsHint =>
      'Font size, theme, and other settings will be available in a future update.';

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
  String get readerBrightness => 'Brightness';

  @override
  String get readerBackground => 'Page background';

  @override
  String get readerPaper => 'Warm paper';

  @override
  String get readerNight => 'Night';

  @override
  String get readerCharcoal => 'Charcoal';

  @override
  String get readerGraphite => 'Graphite';

  @override
  String get readerWhite => 'White';

  @override
  String get readerSepia => 'Sepia';

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
}
