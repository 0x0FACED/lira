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
}
