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

  /// No description provided for @yourLibrary.
  ///
  /// In en, this message translates to:
  /// **'Your personal library reader'**
  String get yourLibrary;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @interfaceFontSize.
  ///
  /// In en, this message translates to:
  /// **'Interface font size'**
  String get interfaceFontSize;

  /// No description provided for @interfaceFontSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Does not change book text size in the reader.'**
  String get interfaceFontSizeHint;

  /// No description provided for @libraryBooksPerRow.
  ///
  /// In en, this message translates to:
  /// **'Books per row'**
  String get libraryBooksPerRow;

  /// No description provided for @libraryTwoBooksPerRow.
  ///
  /// In en, this message translates to:
  /// **'2 books per row'**
  String get libraryTwoBooksPerRow;

  /// No description provided for @libraryThreeBooksPerRow.
  ///
  /// In en, this message translates to:
  /// **'3 books per row'**
  String get libraryThreeBooksPerRow;

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

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

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

  /// No description provided for @readerPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Reader preview'**
  String get readerPreviewTitle;

  /// No description provided for @readerPreviewBook.
  ///
  /// In en, this message translates to:
  /// **'Sample book'**
  String get readerPreviewBook;

  /// No description provided for @readerCurrentBook.
  ///
  /// In en, this message translates to:
  /// **'Current book'**
  String get readerCurrentBook;

  /// No description provided for @readerPreviewError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the sample book.'**
  String get readerPreviewError;

  /// No description provided for @readerCloseSettings.
  ///
  /// In en, this message translates to:
  /// **'Close reader settings'**
  String get readerCloseSettings;

  /// No description provided for @readerCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize reader'**
  String get readerCustomize;

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
  /// **'Search'**
  String get searchLibrary;

  /// No description provided for @libraryReadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Reading progress'**
  String get libraryReadingProgress;

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
  /// **'Position: {percentage}'**
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

  /// No description provided for @readerBackground.
  ///
  /// In en, this message translates to:
  /// **'Page background'**
  String get readerBackground;

  /// No description provided for @readerTypography.
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get readerTypography;

  /// No description provided for @readerLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get readerLayout;

  /// No description provided for @readerColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get readerColors;

  /// No description provided for @readerFontWeight.
  ///
  /// In en, this message translates to:
  /// **'Font weight'**
  String get readerFontWeight;

  /// No description provided for @readerParagraphIndent.
  ///
  /// In en, this message translates to:
  /// **'First-line indent'**
  String get readerParagraphIndent;

  /// No description provided for @readerParagraphSpacing.
  ///
  /// In en, this message translates to:
  /// **'Paragraph spacing'**
  String get readerParagraphSpacing;

  /// No description provided for @readerEmUnit.
  ///
  /// In en, this message translates to:
  /// **'em'**
  String get readerEmUnit;

  /// No description provided for @readerHyphenation.
  ///
  /// In en, this message translates to:
  /// **'Word hyphenation'**
  String get readerHyphenation;

  /// No description provided for @readerHyphenationHint.
  ///
  /// In en, this message translates to:
  /// **'Break words across lines using the book’s language.'**
  String get readerHyphenationHint;

  /// No description provided for @readerReadingMode.
  ///
  /// In en, this message translates to:
  /// **'Reading mode'**
  String get readerReadingMode;

  /// No description provided for @readerTextAlignment.
  ///
  /// In en, this message translates to:
  /// **'Text alignment'**
  String get readerTextAlignment;

  /// No description provided for @readerAlignOriginal.
  ///
  /// In en, this message translates to:
  /// **'From book'**
  String get readerAlignOriginal;

  /// No description provided for @readerAlignLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get readerAlignLeft;

  /// No description provided for @readerAlignJustify.
  ///
  /// In en, this message translates to:
  /// **'Justified'**
  String get readerAlignJustify;

  /// No description provided for @readerPalette.
  ///
  /// In en, this message translates to:
  /// **'Reader palette'**
  String get readerPalette;

  /// No description provided for @readerPaletteDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get readerPaletteDay;

  /// No description provided for @readerPalettePaper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get readerPalettePaper;

  /// No description provided for @readerPaletteDark.
  ///
  /// In en, this message translates to:
  /// **'Readable dark'**
  String get readerPaletteDark;

  /// No description provided for @readerPaletteEvening.
  ///
  /// In en, this message translates to:
  /// **'Warm evening'**
  String get readerPaletteEvening;

  /// No description provided for @readerPaletteHint.
  ///
  /// In en, this message translates to:
  /// **'Presets set page, text, link and selection colors without changing extra dimming.'**
  String get readerPaletteHint;

  /// No description provided for @readerTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get readerTextColor;

  /// No description provided for @readerHexColor.
  ///
  /// In en, this message translates to:
  /// **'Hex color'**
  String get readerHexColor;

  /// No description provided for @readerEditColor.
  ///
  /// In en, this message translates to:
  /// **'Edit color'**
  String get readerEditColor;

  /// No description provided for @readerHexColorError.
  ///
  /// In en, this message translates to:
  /// **'Enter six hexadecimal digits, for example #AABBCC.'**
  String get readerHexColorError;

  /// No description provided for @readerTextContrast.
  ///
  /// In en, this message translates to:
  /// **'Text contrast'**
  String get readerTextContrast;

  /// No description provided for @readerTextContrastHint.
  ///
  /// In en, this message translates to:
  /// **'100% uses the chosen text color. Lower values blend it toward the page background.'**
  String get readerTextContrastHint;

  /// No description provided for @readerAdditionalDimming.
  ///
  /// In en, this message translates to:
  /// **'Additional dimming'**
  String get readerAdditionalDimming;

  /// No description provided for @readerAdditionalDimmingHint.
  ///
  /// In en, this message translates to:
  /// **'Darkens the entire page, including letters. Separate from your device’s system brightness.'**
  String get readerAdditionalDimmingHint;

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

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @discoverSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get discoverSources;

  /// No description provided for @discoverSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search books, articles and RFCs'**
  String get discoverSearchHint;

  /// No description provided for @discoverSourceSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search this source'**
  String get discoverSourceSearchHint;

  /// No description provided for @discoverSourcesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Find a source by name or description'**
  String get discoverSourcesSearchHint;

  /// No description provided for @discoverBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get discoverBooks;

  /// No description provided for @discoverArticles.
  ///
  /// In en, this message translates to:
  /// **'Articles'**
  String get discoverArticles;

  /// No description provided for @discoverDocuments.
  ///
  /// In en, this message translates to:
  /// **'RFC'**
  String get discoverDocuments;

  /// No description provided for @discoverSelectedOnly.
  ///
  /// In en, this message translates to:
  /// **'Selected only'**
  String get discoverSelectedOnly;

  /// No description provided for @discoverTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get discoverTopic;

  /// No description provided for @discoverAllTopics.
  ///
  /// In en, this message translates to:
  /// **'All topics'**
  String get discoverAllTopics;

  /// No description provided for @discoverTopicTechnology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get discoverTopicTechnology;

  /// No description provided for @discoverTopicEconomics.
  ///
  /// In en, this message translates to:
  /// **'Economics'**
  String get discoverTopicEconomics;

  /// No description provided for @discoverTopicNature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get discoverTopicNature;

  /// No description provided for @discoverTopicHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get discoverTopicHistory;

  /// No description provided for @discoverTopicCulture.
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get discoverTopicCulture;

  /// No description provided for @discoverTopicPsychology.
  ///
  /// In en, this message translates to:
  /// **'Psychology'**
  String get discoverTopicPsychology;

  /// No description provided for @discoverTopicScience.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get discoverTopicScience;

  /// No description provided for @discoverContentLanguage.
  ///
  /// In en, this message translates to:
  /// **'Content language'**
  String get discoverContentLanguage;

  /// No description provided for @discoverAllLanguages.
  ///
  /// In en, this message translates to:
  /// **'All languages'**
  String get discoverAllLanguages;

  /// No description provided for @discoverLanguageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get discoverLanguageRussian;

  /// No description provided for @discoverLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get discoverLanguageEnglish;

  /// No description provided for @discoverLanguageMultilingual.
  ///
  /// In en, this message translates to:
  /// **'Multilingual'**
  String get discoverLanguageMultilingual;

  /// No description provided for @discoverSourceTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics: {topics}'**
  String discoverSourceTopics(String topics);

  /// No description provided for @discoverSourceContentLanguage.
  ///
  /// In en, this message translates to:
  /// **'Content language: {language}'**
  String discoverSourceContentLanguage(String language);

  /// No description provided for @discoverSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} selected source} other {{count} selected sources}}'**
  String discoverSelectedCount(int count);

  /// No description provided for @discoverSourcePosition.
  ///
  /// In en, this message translates to:
  /// **'Position {position}'**
  String discoverSourcePosition(int position);

  /// No description provided for @discoverMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move source up'**
  String get discoverMoveUp;

  /// No description provided for @discoverMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move source down'**
  String get discoverMoveDown;

  /// No description provided for @discoverSavingSources.
  ///
  /// In en, this message translates to:
  /// **'Saving selection…'**
  String get discoverSavingSources;

  /// No description provided for @discoverSourcesSaved.
  ///
  /// In en, this message translates to:
  /// **'Selection saved on this device'**
  String get discoverSourcesSaved;

  /// No description provided for @discoverSourcesSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your source selection'**
  String get discoverSourcesSaveError;

  /// No description provided for @discoverNoSources.
  ///
  /// In en, this message translates to:
  /// **'Choose your sources'**
  String get discoverNoSources;

  /// No description provided for @discoverNoSourcesHint.
  ///
  /// In en, this message translates to:
  /// **'Enable sources to see their publications and include them in search.'**
  String get discoverNoSourcesHint;

  /// No description provided for @discoverNoMatchingSources.
  ///
  /// In en, this message translates to:
  /// **'No matching sources'**
  String get discoverNoMatchingSources;

  /// No description provided for @discoverSearchOnly.
  ///
  /// In en, this message translates to:
  /// **'Ready to search'**
  String get discoverSearchOnly;

  /// No description provided for @discoverSearchOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Your selected book catalogs are search-only. Search above to find EPUB and PDF books.'**
  String get discoverSearchOnlyHint;

  /// No description provided for @discoverSearchSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Search this catalog by title, author or ISBN.'**
  String get discoverSearchSourceHint;

  /// No description provided for @discoverSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'What would you like to read?'**
  String get discoverSearchPrompt;

  /// No description provided for @discoverSearchPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Search only your selected sources. Switch categories to see separate results.'**
  String get discoverSearchPromptHint;

  /// No description provided for @discoverNoMaterials.
  ///
  /// In en, this message translates to:
  /// **'No publications found'**
  String get discoverNoMaterials;

  /// No description provided for @discoverFeedError.
  ///
  /// In en, this message translates to:
  /// **'Could not load publications'**
  String get discoverFeedError;

  /// No description provided for @discoverSearchError.
  ///
  /// In en, this message translates to:
  /// **'Could not search this source'**
  String get discoverSearchError;

  /// No description provided for @discoverRecentOnly.
  ///
  /// In en, this message translates to:
  /// **'Searches recent publications only'**
  String get discoverRecentOnly;

  /// No description provided for @discoverWholeCatalog.
  ///
  /// In en, this message translates to:
  /// **'Searches the full RFC catalog'**
  String get discoverWholeCatalog;

  /// No description provided for @discoverCachedFeed.
  ///
  /// In en, this message translates to:
  /// **'Showing saved publications. Refresh to try again.'**
  String get discoverCachedFeed;

  /// No description provided for @discoverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String discoverUpdated(String date);

  /// No description provided for @discoverRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh publications'**
  String get discoverRefresh;

  /// No description provided for @discoverRead.
  ///
  /// In en, this message translates to:
  /// **'Read in Lira'**
  String get discoverRead;

  /// No description provided for @discoverSave.
  ///
  /// In en, this message translates to:
  /// **'Save to library'**
  String get discoverSave;

  /// No description provided for @discoverSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved in library'**
  String get discoverSaved;

  /// No description provided for @discoverSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'“{title}” saved to your library'**
  String discoverSavedMessage(String title);

  /// No description provided for @discoverPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing for reading…'**
  String get discoverPreparing;

  /// No description provided for @discoverPrepareError.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare this publication. Try again.'**
  String get discoverPrepareError;

  /// No description provided for @discoverSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this publication. Try again.'**
  String get discoverSaveError;

  /// No description provided for @discoverOpenOriginal.
  ///
  /// In en, this message translates to:
  /// **'Open original'**
  String get discoverOpenOriginal;

  /// No description provided for @discoverOpenOriginalError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the original in your browser.'**
  String get discoverOpenOriginalError;

  /// No description provided for @discoverMaterialDetails.
  ///
  /// In en, this message translates to:
  /// **'Publication'**
  String get discoverMaterialDetails;

  /// No description provided for @discoverClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get discoverClearAll;

  /// No description provided for @zLibraryMirrors.
  ///
  /// In en, this message translates to:
  /// **'Z-Library mirrors'**
  String get zLibraryMirrors;

  /// No description provided for @zLibraryMirrorsSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Used for search, sign-in and downloads'**
  String get zLibraryMirrorsSettingsHint;

  /// No description provided for @zLibraryMirrorsHint.
  ///
  /// In en, this message translates to:
  /// **'Mirrors are alternate addresses of the same catalog. Lira tries them in order when an address is unavailable; it does not send the same search to every mirror.'**
  String get zLibraryMirrorsHint;

  /// No description provided for @zLibraryMirrorsTrustWarning.
  ///
  /// In en, this message translates to:
  /// **'Only add addresses you trust. Configured mirrors may receive your Z-Library session or sign-in credentials. Suggestions are never enabled without your review and Save.'**
  String get zLibraryMirrorsTrustWarning;

  /// No description provided for @zLibraryMirrorsField.
  ///
  /// In en, this message translates to:
  /// **'Mirror addresses'**
  String get zLibraryMirrorsField;

  /// No description provided for @zLibraryMirrorsFieldHint.
  ///
  /// In en, this message translates to:
  /// **'One HTTPS origin per line, in priority order. You can also paste a hostname without https://.'**
  String get zLibraryMirrorsFieldHint;

  /// No description provided for @zLibraryMirrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one valid HTTPS origin. Paths, query parameters and embedded credentials are not allowed.'**
  String get zLibraryMirrorInvalid;

  /// No description provided for @zLibraryMirrorsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get zLibraryMirrorsSaving;

  /// No description provided for @zLibraryMirrorsSaved.
  ///
  /// In en, this message translates to:
  /// **'Mirror list saved'**
  String get zLibraryMirrorsSaved;

  /// No description provided for @zLibraryMirrorsSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the mirror list. Your previous list is still active.'**
  String get zLibraryMirrorsSaveError;

  /// No description provided for @zLibraryMirrorsFind.
  ///
  /// In en, this message translates to:
  /// **'Find mirrors'**
  String get zLibraryMirrorsFind;

  /// No description provided for @zLibraryMirrorsFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding mirrors…'**
  String get zLibraryMirrorsFinding;

  /// No description provided for @zLibraryMirrorsRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore known addresses'**
  String get zLibraryMirrorsRestore;

  /// No description provided for @zLibraryMirrorsFound.
  ///
  /// In en, this message translates to:
  /// **'Review mirror suggestions'**
  String get zLibraryMirrorsFound;

  /// No description provided for @zLibraryMirrorsReviewHint.
  ///
  /// In en, this message translates to:
  /// **'These addresses came from Z-Library\'s access information. Review them before adding. Availability can differ across networks.'**
  String get zLibraryMirrorsReviewHint;

  /// No description provided for @zLibraryMirrorsAddSelected.
  ///
  /// In en, this message translates to:
  /// **'Add selected'**
  String get zLibraryMirrorsAddSelected;

  /// No description provided for @zLibraryMirrorsReviewSave.
  ///
  /// In en, this message translates to:
  /// **'Addresses added to the editor. Press Save to use the new list.'**
  String get zLibraryMirrorsReviewSave;

  /// No description provided for @zLibraryMirrorDirectoryHint.
  ///
  /// In en, this message translates to:
  /// **'Suggestions come from Z-Library\'s public access-information file, not an unverified third-party mirror directory.'**
  String get zLibraryMirrorDirectoryHint;

  /// No description provided for @zLibraryMirrorDirectoryOpen.
  ///
  /// In en, this message translates to:
  /// **'Open official access information'**
  String get zLibraryMirrorDirectoryOpen;

  /// No description provided for @zLibraryMirrorDirectoryError.
  ///
  /// In en, this message translates to:
  /// **'Could not retrieve the official mirror list. The source may be unavailable or require browser verification. Open its access information or edit known addresses manually.'**
  String get zLibraryMirrorDirectoryError;

  /// No description provided for @zLibraryMirrorDirectoryOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the access-information page.'**
  String get zLibraryMirrorDirectoryOpenError;

  /// No description provided for @annaSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Anna’s Archive access'**
  String get annaSessionTitle;

  /// No description provided for @annaSessionHint.
  ///
  /// In en, this message translates to:
  /// **'Anna’s Archive may require browser verification before showing search results. After passing it legitimately, you can use that browser session here. A session is sent only to its selected official domain.'**
  String get annaSessionHint;

  /// No description provided for @annaSessionDomain.
  ///
  /// In en, this message translates to:
  /// **'Verified browser domain'**
  String get annaSessionDomain;

  /// No description provided for @annaSessionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open search in browser'**
  String get annaSessionOpen;

  /// No description provided for @annaSessionConnectionWarning.
  ///
  /// In en, this message translates to:
  /// **'The browser and Lira must use the same connection or proxy exit IP and User-Agent. A session cleared without a proxy will not clear a blocked proxy. Expired verification must be completed again.'**
  String get annaSessionConnectionWarning;

  /// No description provided for @annaSessionInstructions.
  ///
  /// In en, this message translates to:
  /// **'After verification, open browser developer tools → Network → a successful /search request → Request Headers. Copy its Cookie and User-Agent values below. Do not share these values with anyone. They are stored only on this device.'**
  String get annaSessionInstructions;

  /// No description provided for @annaSessionToggleCookies.
  ///
  /// In en, this message translates to:
  /// **'Show or hide browser cookies'**
  String get annaSessionToggleCookies;

  /// No description provided for @annaSessionClear.
  ///
  /// In en, this message translates to:
  /// **'Remove session'**
  String get annaSessionClear;

  /// No description provided for @annaSessionSaved.
  ///
  /// In en, this message translates to:
  /// **'Browser session saved'**
  String get annaSessionSaved;

  /// No description provided for @annaSessionCleared.
  ///
  /// In en, this message translates to:
  /// **'Browser session removed'**
  String get annaSessionCleared;

  /// No description provided for @annaSessionInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose an official domain and enter a valid Cookie header and matching User-Agent.'**
  String get annaSessionInvalid;

  /// No description provided for @annaSessionSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the browser session.'**
  String get annaSessionSaveError;

  /// No description provided for @readerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search in book'**
  String get readerSearch;

  /// No description provided for @readerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Word or phrase'**
  String get readerSearchHint;

  /// No description provided for @readerSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Find a passage in this book. Search works offline.'**
  String get readerSearchPrompt;

  /// No description provided for @readerSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get readerSearching;

  /// No description provided for @readerSearchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get readerSearchNoResults;

  /// No description provided for @readerSearchNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try another word or a shorter phrase.'**
  String get readerSearchNoResultsHint;

  /// No description provided for @readerSearchNoPdfText.
  ///
  /// In en, this message translates to:
  /// **'This PDF has no searchable text layer. Search does not recognize text in scanned images.'**
  String get readerSearchNoPdfText;

  /// No description provided for @readerSearchError.
  ///
  /// In en, this message translates to:
  /// **'Could not search this book'**
  String get readerSearchError;

  /// No description provided for @readerSearchRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get readerSearchRetry;

  /// No description provided for @readerSearchPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get readerSearchPrevious;

  /// No description provided for @readerSearchNext.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get readerSearchNext;

  /// No description provided for @readerSearchFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish search'**
  String get readerSearchFinish;

  /// No description provided for @readerSearchReturn.
  ///
  /// In en, this message translates to:
  /// **'Return to reading'**
  String get readerSearchReturn;

  /// No description provided for @readerSearchNavigationError.
  ///
  /// In en, this message translates to:
  /// **'Could not open this location. Try again.'**
  String get readerSearchNavigationError;

  /// No description provided for @readerSearchCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No matches} one{1 match} other{{count} matches}}'**
  String readerSearchCount(int count);

  /// No description provided for @readerSearchPosition.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String readerSearchPosition(int current, int total);

  /// No description provided for @readerSearchPage.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String readerSearchPage(int number);

  /// No description provided for @readerSearchChapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String readerSearchChapter(int number);

  /// No description provided for @annaSessionOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open Anna’s Archive in the browser.'**
  String get annaSessionOpenError;

  /// No description provided for @annotationsToolsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search quotes and notes'**
  String get annotationsToolsSearch;

  /// No description provided for @annotationsToolsHasNote.
  ///
  /// In en, this message translates to:
  /// **'With note'**
  String get annotationsToolsHasNote;

  /// No description provided for @annotationsToolsClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get annotationsToolsClearFilters;

  /// No description provided for @annotationsToolsSelectVisible.
  ///
  /// In en, this message translates to:
  /// **'Select visible'**
  String get annotationsToolsSelectVisible;

  /// No description provided for @annotationsToolsDeselectVisible.
  ///
  /// In en, this message translates to:
  /// **'Deselect visible'**
  String get annotationsToolsDeselectVisible;

  /// No description provided for @annotationsToolsSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String annotationsToolsSelected(String count);

  /// No description provided for @annotationsToolsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get annotationsToolsExport;

  /// No description provided for @annotationsToolsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching annotations'**
  String get annotationsToolsNoMatches;

  /// No description provided for @annotationsToolsNoMatchesHint.
  ///
  /// In en, this message translates to:
  /// **'Change your search or clear the filters.'**
  String get annotationsToolsNoMatchesHint;

  /// No description provided for @annotationsToolsSelectQuote.
  ///
  /// In en, this message translates to:
  /// **'Select quote for export'**
  String get annotationsToolsSelectQuote;

  /// No description provided for @annotationsToolsCopyQuote.
  ///
  /// In en, this message translates to:
  /// **'Copy quote with source'**
  String get annotationsToolsCopyQuote;

  /// No description provided for @annotationsToolsCopyError.
  ///
  /// In en, this message translates to:
  /// **'Could not copy quote: {error}'**
  String annotationsToolsCopyError(String error);

  /// No description provided for @annotationsToolsExportScope.
  ///
  /// In en, this message translates to:
  /// **'Annotations to export'**
  String get annotationsToolsExportScope;

  /// No description provided for @annotationsToolsAllSaved.
  ///
  /// In en, this message translates to:
  /// **'All saved ({count})'**
  String annotationsToolsAllSaved(String count);

  /// No description provided for @annotationsToolsVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible results ({count})'**
  String annotationsToolsVisible(String count);

  /// No description provided for @annotationsToolsSelectedVisible.
  ///
  /// In en, this message translates to:
  /// **'Selected visible ({count})'**
  String annotationsToolsSelectedVisible(String count);

  /// No description provided for @annotationsToolsPlainText.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get annotationsToolsPlainText;

  /// No description provided for @annotationsToolsSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get annotationsToolsSourceTitle;

  /// No description provided for @annotationsToolsSourceAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get annotationsToolsSourceAuthor;

  /// No description provided for @annotationsToolsSourceFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get annotationsToolsSourceFormat;

  /// No description provided for @annotationsToolsSourceId.
  ///
  /// In en, this message translates to:
  /// **'Library book ID'**
  String get annotationsToolsSourceId;

  /// No description provided for @annotationsToolsSourceAdded.
  ///
  /// In en, this message translates to:
  /// **'Book added (UTC)'**
  String get annotationsToolsSourceAdded;

  /// No description provided for @annotationsToolsExportedAt.
  ///
  /// In en, this message translates to:
  /// **'Exported (UTC)'**
  String get annotationsToolsExportedAt;

  /// No description provided for @annotationsToolsNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get annotationsToolsNote;

  /// No description provided for @annotationsToolsColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get annotationsToolsColor;

  /// No description provided for @annotationsToolsCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Annotation created (UTC)'**
  String get annotationsToolsCreatedAt;

  /// No description provided for @annotationsToolsChapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter (reading order)'**
  String get annotationsToolsChapter;

  /// No description provided for @annotationsToolsPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get annotationsToolsPage;

  /// No description provided for @annotationsToolsSaved.
  ///
  /// In en, this message translates to:
  /// **'Annotations saved: {path}'**
  String annotationsToolsSaved(String path);

  /// No description provided for @annotationsToolsExportError.
  ///
  /// In en, this message translates to:
  /// **'Could not export annotations: {error}'**
  String annotationsToolsExportError(String error);

  /// No description provided for @localSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Local sync'**
  String get localSyncTitle;

  /// No description provided for @localSyncSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Sync with another device'**
  String get localSyncSettingsAction;

  /// No description provided for @localSyncSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Transfer your library and annotations over local Wi-Fi using a QR code. No account needed.'**
  String get localSyncSettingsHint;

  /// No description provided for @localSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect both devices to the same Wi-Fi network or personal hotspot. Keep Lira open on both devices to exchange books, reading progress, highlights, notes and bookmarks in both directions. No account or cloud service is used.'**
  String get localSyncDescription;

  /// No description provided for @localSyncSecurity.
  ///
  /// In en, this message translates to:
  /// **'Use a trusted local network. The invitation is a secret: share it only with your other device. Before approving, compare the requesting device with the one you are connecting. Transfers are encrypted. Leaving this screen or putting Lira in the background stops the session.'**
  String get localSyncSecurity;

  /// No description provided for @localSyncMergePolicy.
  ///
  /// In en, this message translates to:
  /// **'For conflicting changes, the most recently modified version wins. Deleted highlights and bookmarks stay deleted after merging. Deleting a book remains local and does not delete it from the other device.'**
  String get localSyncMergePolicy;

  /// No description provided for @localSyncHost.
  ///
  /// In en, this message translates to:
  /// **'Show invitation QR code'**
  String get localSyncHost;

  /// No description provided for @localSyncNewSession.
  ///
  /// In en, this message translates to:
  /// **'Start a new invitation'**
  String get localSyncNewSession;

  /// No description provided for @localSyncJoin.
  ///
  /// In en, this message translates to:
  /// **'Join another device'**
  String get localSyncJoin;

  /// No description provided for @localSyncScan.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get localSyncScan;

  /// No description provided for @localSyncScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the invitation QR code in Lira on your other device.'**
  String get localSyncScanHint;

  /// No description provided for @localSyncCloseCamera.
  ///
  /// In en, this message translates to:
  /// **'Close camera'**
  String get localSyncCloseCamera;

  /// No description provided for @localSyncCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera is unavailable or permission was denied. Close the camera and import a QR image or paste an invitation instead. You can enable camera access in system settings and scan again.'**
  String get localSyncCameraUnavailable;

  /// No description provided for @localSyncDesktopScanHint.
  ///
  /// In en, this message translates to:
  /// **'Camera scanning is not available on this platform. Import an image of the invitation QR code or paste the invitation below.'**
  String get localSyncDesktopScanHint;

  /// No description provided for @localSyncImportImage.
  ///
  /// In en, this message translates to:
  /// **'Read QR code from image'**
  String get localSyncImportImage;

  /// No description provided for @localSyncImportingImage.
  ///
  /// In en, this message translates to:
  /// **'Reading QR image…'**
  String get localSyncImportingImage;

  /// No description provided for @localSyncInvitation.
  ///
  /// In en, this message translates to:
  /// **'Paste invitation'**
  String get localSyncInvitation;

  /// No description provided for @localSyncConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect with invitation'**
  String get localSyncConnect;

  /// No description provided for @localSyncShowQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan this code on your other device, then approve its request here. The invitation expires in five minutes. Start a new session to get a fresh code.'**
  String get localSyncShowQrHint;

  /// No description provided for @localSyncQrLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret local sync invitation QR code'**
  String get localSyncQrLabel;

  /// No description provided for @localSyncCopyInvitation.
  ///
  /// In en, this message translates to:
  /// **'Copy invitation'**
  String get localSyncCopyInvitation;

  /// No description provided for @localSyncCopied.
  ///
  /// In en, this message translates to:
  /// **'Invitation copied'**
  String get localSyncCopied;

  /// No description provided for @localSyncIdle.
  ///
  /// In en, this message translates to:
  /// **'Ready to start a session'**
  String get localSyncIdle;

  /// No description provided for @localSyncPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing local sync…'**
  String get localSyncPreparing;

  /// No description provided for @localSyncHosting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for another device'**
  String get localSyncHosting;

  /// No description provided for @localSyncConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the other device…'**
  String get localSyncConnecting;

  /// No description provided for @localSyncWaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval on the other device…'**
  String get localSyncWaitingApproval;

  /// No description provided for @localSyncApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'A device wants to sync'**
  String get localSyncApproveTitle;

  /// No description provided for @localSyncApproveHint.
  ///
  /// In en, this message translates to:
  /// **'Approve only if this is your device and you just scanned or entered this invitation. Approval shares the entire library and annotations in both directions.'**
  String get localSyncApproveHint;

  /// No description provided for @localSyncApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve and sync'**
  String get localSyncApprove;

  /// No description provided for @localSyncReject.
  ///
  /// In en, this message translates to:
  /// **'Reject request'**
  String get localSyncReject;

  /// No description provided for @localSyncPeer.
  ///
  /// In en, this message translates to:
  /// **'Other device: {name}'**
  String localSyncPeer(String name);

  /// No description provided for @localSyncTransferring.
  ///
  /// In en, this message translates to:
  /// **'Exchanging library and annotations… Keep both devices open.'**
  String get localSyncTransferring;

  /// No description provided for @localSyncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get localSyncComplete;

  /// No description provided for @localSyncResult.
  ///
  /// In en, this message translates to:
  /// **'Changes on this device: books received — {books}; reading progress — {progress}; highlights and notes — {highlights}; bookmarks — {bookmarks}.'**
  String localSyncResult(
    int books,
    int progress,
    int highlights,
    int bookmarks,
  );

  /// No description provided for @localSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'The session ended with an error'**
  String get localSyncFailed;

  /// No description provided for @localSyncStop.
  ///
  /// In en, this message translates to:
  /// **'Stop session'**
  String get localSyncStop;

  /// No description provided for @localSyncTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get localSyncTryAgain;

  /// No description provided for @localSyncStoppedBackground.
  ///
  /// In en, this message translates to:
  /// **'The session stopped because Lira left the foreground. Start a new invitation or join again to retry.'**
  String get localSyncStoppedBackground;

  /// No description provided for @localSyncErrorInitialization.
  ///
  /// In en, this message translates to:
  /// **'Could not open the local library for sync. Try again.'**
  String get localSyncErrorInitialization;

  /// No description provided for @localSyncErrorInvalidInvitation.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid Lira sync invitation. Scan or paste a fresh invitation from your other device.'**
  String get localSyncErrorInvalidInvitation;

  /// No description provided for @localSyncErrorNoLocalAddress.
  ///
  /// In en, this message translates to:
  /// **'No local network address is available. Connect to Wi-Fi or a hotspot, then start a new session.'**
  String get localSyncErrorNoLocalAddress;

  /// No description provided for @localSyncErrorExpired.
  ///
  /// In en, this message translates to:
  /// **'The invitation expired. Show a new invitation on the other device and connect again.'**
  String get localSyncErrorExpired;

  /// No description provided for @localSyncErrorRejected.
  ///
  /// In en, this message translates to:
  /// **'The other device rejected the request. Start a new session if you want to try again.'**
  String get localSyncErrorRejected;

  /// No description provided for @localSyncErrorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'The devices could not authenticate this session. Use a new invitation and approve only your own device.'**
  String get localSyncErrorUnauthorized;

  /// No description provided for @localSyncErrorConnection.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the other device. Check that both devices are on the same local network, keep Lira open, and allow local network access through the system firewall. Then start a new session.'**
  String get localSyncErrorConnection;

  /// No description provided for @localSyncErrorTransfer.
  ///
  /// In en, this message translates to:
  /// **'The transfer could not finish. Some verified changes may already have been saved. Check the connection and available storage, then start a new session; changes already received will be merged safely.'**
  String get localSyncErrorTransfer;

  /// No description provided for @localSyncErrorCancelled.
  ///
  /// In en, this message translates to:
  /// **'The session was cancelled. Start a new invitation or join again to retry.'**
  String get localSyncErrorCancelled;

  /// No description provided for @localSyncErrorImage.
  ///
  /// In en, this message translates to:
  /// **'Could not read a Lira invitation QR code from this image. Choose a clear PNG, JPEG, BMP or WebP image up to 20 MB, or paste the invitation.'**
  String get localSyncErrorImage;

  /// No description provided for @localSyncQrImageType.
  ///
  /// In en, this message translates to:
  /// **'QR code image'**
  String get localSyncQrImageType;

  /// No description provided for @localSyncDetails.
  ///
  /// In en, this message translates to:
  /// **'Security and merge rules'**
  String get localSyncDetails;

  /// No description provided for @localSyncErrorClipboard.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the invitation. Scan the displayed QR code instead.'**
  String get localSyncErrorClipboard;

  /// No description provided for @localAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Read without an account'**
  String get localAccessTitle;

  /// No description provided for @localAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'Books and reading data stay on this device. Use local QR sync to exchange your library with another device without an account.'**
  String get localAccessDescription;

  /// No description provided for @serverAccountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Lira accounts and server sign-in are not available. No password is needed to read or use local sync.'**
  String get serverAccountUnavailable;

  /// No description provided for @localAccessContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue to library'**
  String get localAccessContinue;

  /// No description provided for @localAccessError.
  ///
  /// In en, this message translates to:
  /// **'Could not save local access. Try again.'**
  String get localAccessError;

  /// No description provided for @bookAuthorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown author'**
  String get bookAuthorUnknown;

  /// No description provided for @searchFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'Could not search for books. Try again or check source access.'**
  String get searchFailedDescription;

  /// No description provided for @searchSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{source} is unavailable'**
  String searchSourceUnavailable(String source);

  /// No description provided for @searchTechnicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get searchTechnicalDetails;

  /// No description provided for @searchDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download the book'**
  String get searchDownloadFailed;

  /// No description provided for @localProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Local library'**
  String get localProfileTitle;

  /// No description provided for @localProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Books and reading data are stored on this device. Use QR sync to exchange them with another device.'**
  String get localProfileHint;

  /// No description provided for @serverAccountInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Server account information'**
  String get serverAccountInfoTitle;

  /// No description provided for @serverAccountInfoHint.
  ///
  /// In en, this message translates to:
  /// **'Server sign-in is not available. Your local library and QR sync do not require an account.'**
  String get serverAccountInfoHint;

  /// No description provided for @proxyAppliedEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Applied: {host}:{port}'**
  String proxyAppliedEndpoint(String host, int port);

  /// No description provided for @proxyHostRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a proxy host'**
  String get proxyHostRequired;

  /// No description provided for @proxyPortInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a port from 1 to 65535'**
  String get proxyPortInvalid;

  /// No description provided for @zLibraryLoginError.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in to Z-Library. Check your credentials and the source’s availability.'**
  String get zLibraryLoginError;

  /// No description provided for @zLibraryLoginErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get zLibraryLoginErrorDetails;
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
