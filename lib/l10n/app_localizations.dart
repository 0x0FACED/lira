import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Lira'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @guestLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Books and progress will be stored locally only'**
  String get guestLocalOnly;

  /// No description provided for @noAccountRegister.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get noAccountRegister;

  /// No description provided for @haveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get haveAccountSignIn;

  /// No description provided for @yourLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your personal library reader'**
  String get yourLibrary;

  /// No description provided for @fillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get fillAllFields;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @noBooks.
  ///
  /// In en, this message translates to:
  /// **'No books in library'**
  String get noBooks;

  /// No description provided for @noBooksHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first book'**
  String get noBooksHint;

  /// No description provided for @importBook.
  ///
  /// In en, this message translates to:
  /// **'Import Book'**
  String get importBook;

  /// No description provided for @deleteBook.
  ///
  /// In en, this message translates to:
  /// **'Delete Book'**
  String get deleteBook;

  /// No description provided for @deleteBookConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {title}?'**
  String deleteBookConfirm(String title);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @readBook.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get readBook;

  /// No description provided for @openBook.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openBook;

  /// No description provided for @duplicateBookError.
  ///
  /// In en, this message translates to:
  /// **'This book already exists in your library.'**
  String get duplicateBookError;

  /// No description provided for @searchBooks.
  ///
  /// In en, this message translates to:
  /// **'Search Books'**
  String get searchBooks;

  /// No description provided for @searchBooksHint.
  ///
  /// In en, this message translates to:
  /// **'Search for books online will be available in a future update.\nYou\'ll be able to search z-library and download books directly.'**
  String get searchBooksHint;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @signedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedIn;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @guestSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Local only — sign in to sync'**
  String get guestSyncHint;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @signInComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Sign in coming soon'**
  String get signInComingSoon;

  /// No description provided for @registrationComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Registration coming soon'**
  String get registrationComingSoon;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @themeComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Theme toggle coming soon'**
  String get themeComingSoon;

  /// No description provided for @languageComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Language selector coming soon'**
  String get languageComingSoon;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// Edit book action
  ///
  /// In en, this message translates to:
  /// **'Edit Book'**
  String get editBook;

  /// Book title edit field
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get editBookTitle;

  /// Book author edit field
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get editBookAuthor;

  /// Save action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Details section header
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// File size label
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// Page count label
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get pages;

  /// Date added label
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// Unknown value placeholder
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @tableOfContents.
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get tableOfContents;

  /// No description provided for @tocComingSoon.
  ///
  /// In en, this message translates to:
  /// **'TOC will be available in a future update.'**
  String get tocComingSoon;

  /// No description provided for @readerSettings.
  ///
  /// In en, this message translates to:
  /// **'Reader Settings'**
  String get readerSettings;

  /// No description provided for @readerSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Font size, theme, and other settings will be available in a future update.'**
  String get readerSettingsHint;

  /// No description provided for @readerVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get readerVertical;

  /// No description provided for @readerHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get readerHorizontal;

  /// No description provided for @readerFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get readerFont;

  /// No description provided for @readerTwoPageSpread.
  ///
  /// In en, this message translates to:
  /// **'Two-page spread'**
  String get readerTwoPageSpread;

  /// No description provided for @highlightSaved.
  ///
  /// In en, this message translates to:
  /// **'Highlight saved'**
  String get highlightSaved;

  /// No description provided for @errorLoadingBook.
  ///
  /// In en, this message translates to:
  /// **'Error loading book'**
  String get errorLoadingBook;

  /// No description provided for @errorLoadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Error loading progress'**
  String get errorLoadingProgress;

  /// No description provided for @failedToInitReader.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize reader engine.'**
  String get failedToInitReader;

  /// No description provided for @noChapters.
  ///
  /// In en, this message translates to:
  /// **'This EPUB has no readable chapters.'**
  String get noChapters;

  /// No description provided for @searchLibrary.
  ///
  /// In en, this message translates to:
  /// **'Search library...'**
  String get searchLibrary;

  /// No description provided for @downloadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Download cancelled'**
  String get downloadCancelled;

  /// No description provided for @zLibrary.
  ///
  /// In en, this message translates to:
  /// **'Z-Library'**
  String get zLibrary;

  /// No description provided for @zLibraryLogin.
  ///
  /// In en, this message translates to:
  /// **'Z-Library Login'**
  String get zLibraryLogin;

  /// No description provided for @zLibraryEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get zLibraryEmail;

  /// No description provided for @zLibraryPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get zLibraryPassword;

  /// No description provided for @zLibraryLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Logged in as {email}'**
  String zLibraryLoggedIn(String email);

  /// No description provided for @zLibraryNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in to Z-Library'**
  String get zLibraryNotLoggedIn;

  /// No description provided for @zLibraryLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get zLibraryLogout;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @proxyHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get proxyHost;

  /// No description provided for @proxyPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get proxyPort;

  /// No description provided for @proxyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get proxyDisabled;

  /// No description provided for @searchBothSources.
  ///
  /// In en, this message translates to:
  /// **'Both sources'**
  String get searchBothSources;

  /// No description provided for @searchAllFormats.
  ///
  /// In en, this message translates to:
  /// **'All formats'**
  String get searchAllFormats;

  /// No description provided for @searchSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get searchSort;

  /// No description provided for @searchSortRelevance.
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get searchSortRelevance;

  /// No description provided for @searchSortTitleAsc.
  ///
  /// In en, this message translates to:
  /// **'Title: A to Z'**
  String get searchSortTitleAsc;

  /// No description provided for @searchSortTitleDesc.
  ///
  /// In en, this message translates to:
  /// **'Title: Z to A'**
  String get searchSortTitleDesc;

  /// No description provided for @searchSortAuthorAsc.
  ///
  /// In en, this message translates to:
  /// **'Author: A to Z'**
  String get searchSortAuthorAsc;

  /// No description provided for @searchLoading.
  ///
  /// In en, this message translates to:
  /// **'Searching the shelves…'**
  String get searchLoading;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No books found'**
  String get searchNoResults;

  /// No description provided for @searchNoFilterResults.
  ///
  /// In en, this message translates to:
  /// **'No books match these filters'**
  String get searchNoFilterResults;

  /// No description provided for @searchResetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get searchResetFilters;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search is unavailable'**
  String get searchFailed;

  /// No description provided for @searchRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get searchRetry;

  /// No description provided for @searchSourcesPartialFailure.
  ///
  /// In en, this message translates to:
  /// **'Some sources are unavailable. Showing the results we could find.'**
  String get searchSourcesPartialFailure;

  /// No description provided for @cancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get cancelDownload;

  /// No description provided for @downloadBook.
  ///
  /// In en, this message translates to:
  /// **'Download book'**
  String get downloadBook;

  /// No description provided for @searchAnnaDescription.
  ///
  /// In en, this message translates to:
  /// **'Find books by title, author or ISBN in Anna’s Archive.'**
  String get searchAnnaDescription;

  /// No description provided for @searchZLibraryDescription.
  ///
  /// In en, this message translates to:
  /// **'Find your next read in Z-Library. Sign in from Settings to download books.'**
  String get searchZLibraryDescription;

  /// No description provided for @searchBothDescription.
  ///
  /// In en, this message translates to:
  /// **'Search Anna’s Archive and Z-Library together.'**
  String get searchBothDescription;

  /// No description provided for @searchResultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} book} other {{count} books}}'**
  String searchResultsCount(int count);

  /// No description provided for @highlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// No description provided for @highlightsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No highlights yet'**
  String get highlightsEmpty;

  /// No description provided for @highlightsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Select text in the book to save a highlight or note.'**
  String get highlightsEmptyHint;

  /// No description provided for @highlightsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load highlights'**
  String get highlightsLoadError;

  /// No description provided for @annotations.
  ///
  /// In en, this message translates to:
  /// **'Annotations'**
  String get annotations;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @bookmarksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get bookmarksEmpty;

  /// No description provided for @bookmarksEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Use the bookmark button in the reader to save your place.'**
  String get bookmarksEmptyHint;

  /// No description provided for @bookmarksLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load bookmarks'**
  String get bookmarksLoadError;

  /// No description provided for @bookmarkPosition.
  ///
  /// In en, this message translates to:
  /// **'Position: {percentage}%'**
  String bookmarkPosition(String percentage);

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add bookmark'**
  String get addBookmark;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmark;

  /// No description provided for @bookmarkSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save bookmark: {error}'**
  String bookmarkSaveError(String error);

  /// No description provided for @bookmarkDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Could not remove bookmark: {error}'**
  String bookmarkDeleteError(String error);

  /// No description provided for @highlightDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Could not delete highlight: {error}'**
  String highlightDeleteError(String error);

  /// No description provided for @noteSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save note: {error}'**
  String noteSaveError(String error);

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get editNote;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Your note…'**
  String get noteHint;

  /// No description provided for @copyText.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyText;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @highlightText.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlightText;

  /// No description provided for @tableOfContentsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Table of contents is not available'**
  String get tableOfContentsUnavailable;

  /// No description provided for @readerSansSerif.
  ///
  /// In en, this message translates to:
  /// **'Sans serif'**
  String get readerSansSerif;

  /// No description provided for @readerSerif.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get readerSerif;

  /// No description provided for @readerMonospace.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get readerMonospace;

  /// No description provided for @readerFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get readerFontSize;

  /// No description provided for @readerLineHeight.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get readerLineHeight;

  /// No description provided for @readerPageMargins.
  ///
  /// In en, this message translates to:
  /// **'Page margins'**
  String get readerPageMargins;

  /// No description provided for @readerBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get readerBrightness;

  /// No description provided for @readerBackground.
  ///
  /// In en, this message translates to:
  /// **'Page background'**
  String get readerBackground;

  /// No description provided for @readerPaper.
  ///
  /// In en, this message translates to:
  /// **'Warm paper'**
  String get readerPaper;

  /// No description provided for @readerNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get readerNight;

  /// No description provided for @readerCharcoal.
  ///
  /// In en, this message translates to:
  /// **'Charcoal'**
  String get readerCharcoal;

  /// No description provided for @readerGraphite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get readerGraphite;

  /// No description provided for @readerWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get readerWhite;

  /// No description provided for @readerSepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get readerSepia;

  /// No description provided for @readerSavePositionError.
  ///
  /// In en, this message translates to:
  /// **'Could not save reading position: {error}'**
  String readerSavePositionError(String error);

  /// No description provided for @highlightSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save highlight: {error}'**
  String highlightSaveError(String error);

  /// No description provided for @bookDownloaded.
  ///
  /// In en, this message translates to:
  /// **'“{title}” added to your library'**
  String bookDownloaded(String title);

  /// No description provided for @updateSection.
  ///
  /// In en, this message translates to:
  /// **'App updates'**
  String get updateSection;

  /// No description provided for @updateSource.
  ///
  /// In en, this message translates to:
  /// **'Official releases on GitHub'**
  String get updateSource;

  /// No description provided for @updateCheckAction.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheckAction;

  /// No description provided for @updateCheckHint.
  ///
  /// In en, this message translates to:
  /// **'Check whether a newer version of Lira is available.'**
  String get updateCheckHint;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get updateChecking;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You have the latest version.'**
  String get updateUpToDate;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading: {percent} · {received} / {total} MB'**
  String updateDownloading(String percent, String received, String total);

  /// No description provided for @updateReady.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is ready to install'**
  String updateReady(String version);

  /// No description provided for @updateOpeningInstaller.
  ///
  /// In en, this message translates to:
  /// **'Opening the system installer…'**
  String get updateOpeningInstaller;

  /// No description provided for @updateDownloadAction.
  ///
  /// In en, this message translates to:
  /// **'Download APK · {size} MB'**
  String updateDownloadAction(String size);

  /// No description provided for @updateInstallAction.
  ///
  /// In en, this message translates to:
  /// **'Install update'**
  String get updateInstallAction;

  /// No description provided for @updateInstallHint.
  ///
  /// In en, this message translates to:
  /// **'Android will ask you to confirm installation. Your library and settings will be kept.'**
  String get updateInstallHint;

  /// No description provided for @updateReleaseAction.
  ///
  /// In en, this message translates to:
  /// **'Open release on GitHub'**
  String get updateReleaseAction;

  /// No description provided for @updateExternalHint.
  ///
  /// In en, this message translates to:
  /// **'Download and install the version for your device from the release page.'**
  String get updateExternalHint;

  /// No description provided for @updateNoApk.
  ///
  /// In en, this message translates to:
  /// **'This release has no verified APK available. Open the release page for installation options.'**
  String get updateNoApk;

  /// No description provided for @updateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No published release is available yet.'**
  String get updateUnavailable;

  /// No description provided for @updateNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates. Check your connection and try again.'**
  String get updateNetworkError;

  /// No description provided for @updateRateLimited.
  ///
  /// In en, this message translates to:
  /// **'GitHub\'s request limit has been reached. Try again later.'**
  String get updateRateLimited;

  /// No description provided for @updateInvalidRelease.
  ///
  /// In en, this message translates to:
  /// **'The release information could not be verified.'**
  String get updateInvalidRelease;

  /// No description provided for @updateDownloadError.
  ///
  /// In en, this message translates to:
  /// **'Could not download the update. Try downloading it again.'**
  String get updateDownloadError;

  /// No description provided for @updateChecksumError.
  ///
  /// In en, this message translates to:
  /// **'The downloaded APK failed verification. Download it again.'**
  String get updateChecksumError;

  /// No description provided for @updatePermissionHint.
  ///
  /// In en, this message translates to:
  /// **'Allow Lira to install unknown apps in Android settings, then tap “Install update” again.'**
  String get updatePermissionHint;

  /// No description provided for @updateSignatureError.
  ///
  /// In en, this message translates to:
  /// **'This APK was signed with a different key and cannot update the installed app.'**
  String get updateSignatureError;

  /// No description provided for @updateInvalidApk.
  ///
  /// In en, this message translates to:
  /// **'This APK is not a compatible update for the installed version of Lira.'**
  String get updateInvalidApk;

  /// No description provided for @updateInstallError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Android installer. Try again or open the release page.'**
  String get updateInstallError;

  /// No description provided for @updateReleaseError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the release page in your browser.'**
  String get updateReleaseError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
