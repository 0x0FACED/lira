import '../../../l10n/app_localizations.dart';

String bookAuthorLabel(String author, AppLocalizations l10n) {
  final value = author.trim();
  return value.isEmpty || value == 'Unknown Author'
      ? l10n.bookAuthorUnknown
      : value;
}
