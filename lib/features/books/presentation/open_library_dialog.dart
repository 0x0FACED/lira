import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/open_library_client.dart';
import '../data/open_library_covers.dart';
import '../domain/models/book_dto.dart';
import '../domain/open_library_genres.dart';
import '../domain/providers/book_organization_provider.dart';
import '../domain/providers/books_provider.dart';
import '../domain/providers/open_library_provider.dart';
import 'book_labels.dart';
import 'widgets/book_cover.dart';

class OpenLibraryDialog extends ConsumerStatefulWidget {
  const OpenLibraryDialog({
    super.key,
    required this.book,
    required this.organization,
  });

  final BookDto book;
  final BookOrganization organization;

  @override
  ConsumerState<OpenLibraryDialog> createState() => _OpenLibraryDialogState();
}

class _OpenLibraryDialogState extends ConsumerState<OpenLibraryDialog> {
  late final _title = TextEditingController(text: widget.book.title);
  late final _author = TextEditingController(
    text: widget.book.author.trim() == 'Unknown Author'
        ? ''
        : widget.book.author,
  );
  final _isbn = TextEditingController();
  String? _bookIsbn;
  String? _bookLanguage;
  bool _byIsbn = false;
  bool _draftEdited = false;
  bool _hintsLoading = true;
  bool _hintsFailed = false;
  bool _searching = false;
  bool _searched = false;
  bool _searchFailed = false;
  bool _invalidSearch = false;
  List<OpenLibraryCandidate> _results = const [];
  OpenLibraryCandidate? _candidate;
  List<String> _candidateGenres = const [];
  OpenLibraryCover? _cover;
  bool _coverLoading = false;
  bool _coverFailed = false;
  int _coverRequest = 0;
  bool _useTitle = false;
  bool _useAuthor = false;
  bool _useGenres = false;
  bool _useCover = false;
  bool _saving = false;
  bool _saveFailed = false;
  bool _openingSource = false;
  bool _sourceFailed = false;

  @override
  void initState() {
    super.initState();
    _loadHints();
  }

  Future<void> _loadHints() async {
    try {
      final hints = await ref
          .read(booksControllerProvider.notifier)
          .openLibraryHints(widget.book);
      if (!mounted) return;
      setState(() {
        _bookIsbn = hints.isbn;
        _bookLanguage = hints.language;
        if (!_draftEdited) {
          _isbn.text = hints.isbn ?? '';
          _byIsbn = normalizeIsbn(_isbn.text) != null;
        }
        _hintsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hintsLoading = false;
        _hintsFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _isbn.dispose();
    super.dispose();
  }

  void _editQuery() {
    setState(() {
      _draftEdited = true;
      _invalidSearch = false;
      _searched = false;
      _searchFailed = false;
      _results = const [];
    });
  }

  Future<void> _search() async {
    final isbn = normalizeIsbn(_isbn.text);
    if ((_byIsbn && isbn == null) ||
        (!_byIsbn &&
            _title.text.trim().isEmpty &&
            _author.text.trim().isEmpty)) {
      setState(() => _invalidSearch = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _invalidSearch = false;
      _searchFailed = false;
      _results = const [];
    });
    try {
      final results = await ref
          .read(openLibraryClientProvider)
          .search(
            isbn: _byIsbn ? isbn : null,
            title: _byIsbn ? null : _title.text.trim(),
            author: _byIsbn ? null : _author.text.trim(),
            language:
                _bookLanguage ?? Localizations.localeOf(context).languageCode,
          );
      if (!mounted) return;
      setState(() {
        _results = results.take(8).toList();
        _searched = true;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  void _select(OpenLibraryCandidate candidate) {
    final additions = openLibraryGenres(
      candidate.subjects,
      russian: Localizations.localeOf(context).languageCode == 'ru',
    );
    final genres = additions.isEmpty
        ? <String>[]
        : mergeOpenLibraryGenres(widget.organization.genres, additions);
    setState(() {
      _candidate = candidate;
      _candidateGenres = genres;
      _useTitle =
          candidate.title.trim().isNotEmpty &&
          candidate.title.trim() != widget.book.title.trim();
      _useAuthor =
          candidate.author.trim().isNotEmpty &&
          candidate.author.trim() != widget.book.author.trim();
      _useGenres =
          genres.isNotEmpty && !listEquals(genres, widget.organization.genres);
      _cover = null;
      _useCover = false;
      _coverFailed = false;
      _saveFailed = false;
      _sourceFailed = false;
    });
    _loadCover(candidate);
  }

  Future<void> _loadCover(OpenLibraryCandidate candidate) async {
    final request = ++_coverRequest;
    final coverId = candidate.coverId;
    if (coverId == null) {
      setState(() => _coverLoading = false);
      return;
    }
    setState(() {
      _coverLoading = true;
      _coverFailed = false;
    });
    try {
      final cover = await ref
          .read(openLibraryClientProvider)
          .fetchCover(coverId);
      final book = widget.book;
      final currentPath = book.coverUrl;
      final sameEdition =
          candidate.coverFromEdition &&
          _bookIsbn != null &&
          candidate.isbns.contains(_bookIsbn);
      final recommend =
          cover != null &&
          await recommendOpenLibraryCover(
            currentPath,
            cover,
            sameEdition: sameEdition,
            pdfPreview:
                book.format == 'pdf' &&
                currentPath != null &&
                p.basename(currentPath) == '${book.id}.png',
          );
      if (!mounted || request != _coverRequest) return;
      setState(() {
        _cover = cover;
        _coverLoading = false;
        _useCover = recommend;
      });
    } catch (_) {
      if (!mounted || request != _coverRequest) return;
      setState(() {
        _coverLoading = false;
        _coverFailed = true;
      });
    }
  }

  Future<void> _apply() async {
    final candidate = _candidate;
    if (candidate == null) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await ref
          .read(booksControllerProvider.notifier)
          .applyOpenLibraryMetadata(
            widget.book,
            candidate,
            title: _useTitle,
            author: _useAuthor,
            genres: _useGenres,
            cover: _useCover ? _cover : null,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  Future<void> _openSource() async {
    final candidate = _candidate;
    if (candidate == null) return;
    setState(() {
      _openingSource = true;
      _sourceFailed = false;
    });
    var failed = false;
    try {
      failed = !await launchUrl(
        candidate.sourceUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _openingSource = false;
      _sourceFailed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final preview = _candidate != null;
    final canApply = _useTitle || _useAuthor || _useGenres || _useCover;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(preview ? l10n.openLibraryPreview : l10n.openLibraryFind),
        content: SizedBox(
          width: AppLayout.formMaxWidth,
          child: preview ? _buildPreview(l10n) : _buildSearch(l10n),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          if (preview) ...[
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      ++_coverRequest;
                      _candidate = null;
                      _coverLoading = false;
                    }),
              child: Text(l10n.openLibraryBack),
            ),
            FilledButton(
              onPressed: _saving || !canApply || _saveFailed ? null : _apply,
              child: Text(
                _saving ? l10n.openLibrarySaving : l10n.openLibraryApply,
              ),
            ),
          ] else
            FilledButton(
              onPressed: _searching || _hintsLoading ? null : _search,
              child: Text(l10n.search),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.openLibrarySearchHint),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: Text(l10n.openLibrarySearchByIsbn),
              selected: _byIsbn,
              onSelected: _searching
                  ? null
                  : (_) {
                      _editQuery();
                      setState(() => _byIsbn = true);
                    },
            ),
            ChoiceChip(
              label: Text(l10n.openLibrarySearchByText),
              selected: !_byIsbn,
              onSelected: _searching
                  ? null
                  : (_) {
                      _editQuery();
                      setState(() => _byIsbn = false);
                    },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_byIsbn)
          TextField(
            controller: _isbn,
            enabled: !_searching,
            decoration: InputDecoration(
              labelText: l10n.openLibrarySearchByIsbn,
            ),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            onChanged: (_) => _editQuery(),
            onSubmitted: (_) {
              if (!_searching && !_hintsLoading) _search();
            },
          )
        else ...[
          TextField(
            controller: _title,
            enabled: !_searching,
            decoration: InputDecoration(labelText: l10n.editBookTitle),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            minLines: 1,
            maxLines: 3,
            onChanged: (_) => _editQuery(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _author,
            enabled: !_searching,
            decoration: InputDecoration(labelText: l10n.editBookAuthor),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.search,
            onChanged: (_) => _editQuery(),
            onSubmitted: (_) {
              if (!_searching && !_hintsLoading) _search();
            },
          ),
        ],
        if (_hintsLoading) ...[
          const SizedBox(height: AppSpacing.md),
          const LinearProgressIndicator(),
        ],
        if (_hintsFailed) _message(l10n.openLibraryHintsError),
        if (_invalidSearch)
          _message(
            _byIsbn
                ? l10n.openLibraryIsbnInvalid
                : l10n.openLibrarySearchRequired,
            error: true,
          ),
        if (_searching) ...[
          const SizedBox(height: AppSpacing.lg),
          const LinearProgressIndicator(),
          _message(l10n.openLibrarySearching),
        ],
        if (_searchFailed) _message(l10n.openLibraryNetworkError, error: true),
        if (_searched && _results.isEmpty && !_searching)
          _message(l10n.openLibraryNoResults),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          for (final candidate in _results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(candidate.title),
              subtitle: Text(
                [
                  if (candidate.author.isNotEmpty) candidate.author,
                  _candidateDescription(candidate, l10n),
                ].join('\n'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _select(candidate),
            ),
        ],
      ],
    );
  }

  String _candidateDescription(
    OpenLibraryCandidate candidate,
    AppLocalizations l10n,
  ) {
    return [
      candidate.editionKey == null
          ? l10n.openLibraryWork
          : l10n.openLibraryEdition,
      if (candidate.language?.isNotEmpty ?? false) candidate.language!,
      if (candidate.year != null) candidate.year.toString(),
      if (candidate.isbns.isNotEmpty) 'ISBN ${candidate.isbns.first}',
    ].join(' · ');
  }

  Widget _buildPreview(AppLocalizations l10n) {
    final candidate = _candidate!;
    final titleChanged =
        candidate.title.trim().isNotEmpty &&
        candidate.title.trim() != widget.book.title.trim();
    final authorChanged =
        candidate.author.trim().isNotEmpty &&
        candidate.author.trim() != widget.book.author.trim();
    final genresChanged =
        _candidateGenres.isNotEmpty &&
        !listEquals(_candidateGenres, widget.organization.genres);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.openLibraryPreviewHint),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _candidateDescription(candidate, l10n),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        _fieldPreview(
          label: l10n.editBookTitle,
          current: widget.book.title,
          next: candidate.title,
          selected: _useTitle,
          changed: titleChanged,
          onChanged: (value) => setState(() => _useTitle = value),
          l10n: l10n,
        ),
        _fieldPreview(
          label: l10n.editBookAuthor,
          current: bookAuthorLabel(widget.book.author, l10n),
          next: candidate.author,
          selected: _useAuthor,
          changed: authorChanged,
          onChanged: (value) => setState(() => _useAuthor = value),
          l10n: l10n,
        ),
        _fieldPreview(
          label: l10n.bookGenres,
          current: widget.organization.genres.join(', '),
          next: _candidateGenres.join(', '),
          selected: _useGenres,
          changed: genresChanged,
          onChanged: (value) => setState(() => _useGenres = value),
          l10n: l10n,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l10n.openLibraryCover),
          value: _useCover,
          onChanged: _saving || _cover == null
              ? null
              : (value) => setState(() => _useCover = value ?? false),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.openLibraryCurrent,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: 88,
                    height: 132,
                    child: BookCover(book: widget.book),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.openLibraryNew,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_coverLoading) ...[
                    const LinearProgressIndicator(),
                    Text(l10n.openLibraryCoverLoading),
                  ] else if (_cover != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.memory(
                        _cover!.bytes,
                        width: 88,
                        height: 132,
                        cacheWidth: 256,
                        fit: BoxFit.contain,
                        semanticLabel: l10n.openLibraryCover,
                      ),
                    )
                  else
                    Text(
                      _coverFailed
                          ? l10n.openLibraryCoverError
                          : l10n.openLibraryCoverMissing,
                    ),
                  if (_coverFailed)
                    TextButton(
                      onPressed: _saving ? null : () => _loadCover(candidate),
                      child: Text(l10n.openLibraryCoverRetry),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _saving || _openingSource ? null : _openSource,
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.openLibrarySource),
          ),
        ),
        if (_sourceFailed) _message(l10n.openLibrarySourceError, error: true),
        if (_saving) const LinearProgressIndicator(),
        if (_saveFailed) _message(l10n.openLibrarySaveError, error: true),
      ],
    );
  }

  Widget _fieldPreview({
    required String label,
    required String current,
    required String next,
    required bool selected,
    required bool changed,
    required ValueChanged<bool> onChanged,
    required AppLocalizations l10n,
  }) {
    final empty = next.trim().isEmpty;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: selected,
      onChanged: _saving || !changed
          ? null
          : (value) => onChanged(value ?? false),
      title: Text(label),
      subtitle: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.sm,
        ),
        child: Text(
          [
            '${l10n.openLibraryCurrent}: ${current.isEmpty ? l10n.openLibraryNoData : current}',
            '${l10n.openLibraryNew}: ${empty ? l10n.openLibraryNoData : next}',
            if (!empty && !changed) l10n.openLibraryUnchanged,
          ].join('\n'),
        ),
      ),
    );
  }

  Widget _message(String message, {bool error = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: error
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : null,
        ),
      ),
    );
  }
}
