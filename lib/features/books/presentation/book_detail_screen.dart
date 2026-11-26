import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../progress/domain/providers/reading_progress_provider.dart';
import '../domain/models/book_dto.dart';
import '../domain/providers/book_organization_provider.dart'
    show
        BookOrganization,
        bookOrganizationProvider,
        bookOrganizationsProvider,
        normalizeBookTags;
import '../domain/providers/books_provider.dart';
import '../domain/providers/favorite_books_provider.dart';
import 'book_actions.dart';
import 'book_export.dart';
import 'book_labels.dart';
import 'book_page_progress.dart';
import 'open_library_dialog.dart';
import 'widgets/book_cover.dart';
import 'widgets/inline_book_labels.dart';

enum _BookExportChoice { saveCopy, copyFile }

class BookDetailScreen extends ConsumerStatefulWidget {
  final BookDto book;

  const BookDetailScreen({super.key, required this.book});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  _BookDraft? _draft;
  bool _saving = false;
  bool _saveFailed = false;

  BookDto _currentBook(AsyncValue<List<BookDto>> books) =>
      books.valueOrNull?.firstWhere(
        (book) => book.id == widget.book.id,
        orElse: () => widget.book,
      ) ??
      widget.book;

  void _startEdit(BookDto book, BookOrganization organization) {
    setState(() => _draft = _BookDraft(book, organization));
  }

  void _finishEdit() {
    FocusScope.of(context).unfocus();
    setState(() {
      _draft = null;
      _saving = false;
      _saveFailed = false;
    });
  }

  Future<void> _save() async {
    final draft = _draft!;
    final book = _currentBook(ref.read(booksControllerProvider));
    final enteredTitle = draft.title.trim();
    final enteredAuthor = draft.author.trim();
    final title =
        enteredTitle.isNotEmpty && enteredTitle != draft.originalTitle.trim()
        ? enteredTitle
        : book.title;
    final author =
        enteredAuthor != draft.originalAuthor ||
            book.author.trim() == 'Unknown Author'
        ? enteredAuthor
        : book.author;
    final genresChanged = !listEquals(
      draft.genres,
      draft.originalLabels.genres,
    );
    final tagsChanged = !listEquals(draft.tags, draft.originalLabels.tags);
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveFailed = false;
    });

    try {
      if (title != book.title || author != book.author) {
        await ref
            .read(booksControllerProvider.notifier)
            .updateBook(book.copyWith(title: title, author: author));
      }
      if (!mounted) return;
      if (genresChanged || tagsChanged) {
        final current = ref.read(bookOrganizationProvider(book.id));
        await ref
            .read(bookOrganizationsProvider.notifier)
            .setLabels(
              book.id,
              BookOrganization(
                genres: genresChanged ? draft.genres : current.genres,
                tags: tagsChanged ? draft.tags : current.tags,
              ),
            );
      }
      if (mounted) _finishEdit();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  Future<void> _commitInlineLabels(
    String bookId, {
    List<String>? genres,
    List<String>? tags,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.read(bookOrganizationProvider(bookId));
    final nextGenres = genres ?? current.genres;
    final nextTags = tags ?? current.tags;
    if (listEquals(nextGenres, current.genres) &&
        listEquals(nextTags, current.tags)) {
      return;
    }
    try {
      await ref
          .read(bookOrganizationsProvider.notifier)
          .setLabels(
            bookId,
            BookOrganization(genres: nextGenres, tags: nextTags),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookEditError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final book = _currentBook(ref.watch(booksControllerProvider));
    final organization = ref.watch(bookOrganizationProvider(book.id));
    final draft = _draft;
    final gutter = AppLayout.pageGutter(context);
    final editBook = () => _startEdit(book, organization);
    final padding = EdgeInsets.fromLTRB(
      gutter,
      AppSpacing.md,
      gutter,
      AppSpacing.lg,
    );

    return PopScope(
      canPop: draft == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _draft != null && !_saving) _finishEdit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: gutter,
                      vertical: AppSpacing.sm,
                    ),
                    child: draft != null
                        ? Row(
                            children: [
                              IconButton(
                                tooltip: l10n.cancel,
                                onPressed: _saving ? null : _finishEdit,
                                icon: Icon(
                                  Icons.close,
                                  semanticLabel: l10n.cancel,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.compact),
                              Expanded(
                                child: Text(
                                  l10n.editBook,
                                  style: theme.textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              FilledButton(
                                onPressed: _saving ? null : _save,
                                child: Text(l10n.save),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              MergeSemantics(
                                child: Semantics(
                                  label: MaterialLocalizations.of(
                                    context,
                                  ).backButtonTooltip,
                                  child: BackButton(
                                    onPressed: () => context.pop(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: TooltipVisibility(
                                  visible: true,
                                  child: Wrap(
                                    alignment: WrapAlignment.end,
                                    children: [
                                      IconButton(
                                        tooltip: l10n.openLibraryFind,
                                        onPressed: () => showAppDialog<void>(
                                          context: context,
                                          builder: (_) => OpenLibraryDialog(
                                            book: book,
                                            organization: organization,
                                          ),
                                        ),
                                        icon: Icon(
                                          Icons.manage_search_outlined,
                                          semanticLabel: l10n.openLibraryFind,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: l10n.editBook,
                                        onPressed: editBook,
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          semanticLabel: l10n.editBook,
                                        ),
                                      ),
                                      if (bookFileClipboardAvailable)
                                        PopupMenuButton<_BookExportChoice>(
                                          tooltip: l10n.bookExportMenu,
                                          icon: const Icon(
                                            Icons.ios_share_outlined,
                                          ),
                                          onSelected: (choice) =>
                                              switch (choice) {
                                                _BookExportChoice.saveCopy =>
                                                  exportBook(context, book),
                                                _BookExportChoice.copyFile =>
                                                  copyBookToClipboard(
                                                    context,
                                                    book,
                                                  ),
                                              },
                                          itemBuilder: (_) => [
                                            PopupMenuItem(
                                              value: _BookExportChoice.saveCopy,
                                              child: Text(l10n.exportBook),
                                            ),
                                            PopupMenuItem(
                                              value: _BookExportChoice.copyFile,
                                              child: Text(l10n.bookCopyFile),
                                            ),
                                          ],
                                        )
                                      else
                                        Builder(
                                          builder: (buttonContext) =>
                                              IconButton(
                                                tooltip: bookExportActionLabel(
                                                  buttonContext,
                                                ),
                                                onPressed: () => exportBook(
                                                  buttonContext,
                                                  book,
                                                ),
                                                icon: const Icon(
                                                  Icons.ios_share_outlined,
                                                ),
                                              ),
                                        ),
                                      IconButton(
                                        tooltip: l10n.deleteBook,
                                        style: IconButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.error,
                                        ),
                                        onPressed: () => _confirmDelete(book),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          semanticLabel: l10n.deleteBook,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: padding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BookIdentity(
                            book: book,
                            draft: draft,
                            saving: _saving,
                          ),
                          if (_saveFailed) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                l10n.bookEditError,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          _ReadingAction(book: book, enabled: draft == null),
                          const SizedBox(height: AppSpacing.md),
                          const Divider(),
                          const SizedBox(height: AppSpacing.md),
                          InlineBookLabels(
                            key: const ValueKey('book-genres'),
                            title: l10n.bookGenres,
                            addLabelTooltip: l10n.bookAddGenre,
                            initialLabels: draft != null
                                ? draft.originalLabels.genres
                                : organization.genres,
                            enabled: !_saving,
                            readOnlyChips: draft == null,
                            onChanged: draft == null
                                ? null
                                : (genres) => draft.genres = genres,
                            onCommit: draft == null
                                ? (genres) => _commitInlineLabels(
                                    book.id,
                                    genres: genres,
                                  )
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.compact),
                          InlineBookLabels(
                            key: const ValueKey('book-tags'),
                            title: l10n.bookTags,
                            addLabelTooltip: l10n.bookAddTag,
                            initialLabels: draft != null
                                ? draft.originalLabels.tags
                                : organization.tags,
                            enabled: !_saving,
                            readOnlyChips: draft == null,
                            normalizeLabels: normalizeBookTags,
                            onChanged: draft == null
                                ? null
                                : (tags) => draft.tags = tags,
                            onCommit: draft == null
                                ? (tags) =>
                                      _commitInlineLabels(book.id, tags: tags)
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Divider(),
                          const SizedBox(height: AppSpacing.md),
                          _FileMetadata(book: book),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BookDto currentBook) async {
    final l10n = AppLocalizations.of(context)!;
    if (!await confirmBookDeletion(context, currentBook) || !mounted) return;
    try {
      await ref
          .read(booksControllerProvider.notifier)
          .removeBook(currentBook.id);
      if (context.mounted) context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookDeleteError)));
    }
  }
}

class _BookIdentity extends StatelessWidget {
  const _BookIdentity({
    required this.book,
    required this.draft,
    required this.saving,
  });

  final BookDto book;
  final _BookDraft? draft;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 480;
        final coverWidth = compact ? 104.0 : 124.0;
        final stacked =
            constraints.maxWidth <
            coverWidth +
                AppSpacing.md +
                MediaQuery.textScalerOf(context).scale(160);
        final cover = SizedBox(
          width: coverWidth,
          child: BookCover(book: book),
        );
        final titleStyle = compact && !stacked
            ? theme.textTheme.titleLarge
            : theme.textTheme.headlineMedium;
        final authorStyle = theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        final draft = this.draft;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (draft == null)
              Semantics(
                header: true,
                child: Text(book.title, style: titleStyle),
              )
            else
              TextFormField(
                initialValue: draft.title,
                onChanged: (value) => draft.title = value,
                enabled: !saving,
                style: titleStyle,
                decoration: InputDecoration(
                  labelText: l10n.editBookTitle,
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
              ),
            const SizedBox(height: AppSpacing.sm),
            if (draft == null)
              Text(bookAuthorLabel(book.author, l10n), style: authorStyle)
            else
              TextFormField(
                initialValue: draft.author,
                onChanged: (value) => draft.author = value,
                enabled: !saving,
                style: authorStyle,
                decoration: InputDecoration(
                  labelText: l10n.editBookAuthor,
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
              ),
          ],
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cover,
              const SizedBox(height: AppSpacing.md),
              identity,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cover,
            const SizedBox(width: AppSpacing.md),
            Expanded(child: identity),
          ],
        );
      },
    );
  }
}

class _ReadingAction extends ConsumerWidget {
  const _ReadingAction({required this.book, required this.enabled});

  final BookDto book;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = ref.watch(readingProgressControllerProvider(book.id));
    final isFavorite = ref.watch(isBookFavoriteProvider(book.id));
    final progressValue = progress.valueOrNull;
    final savedPercentage = progressValue?.percentage;
    final percentage = savedPercentage?.isFinite == true
        ? savedPercentage!.clamp(0.0, 100.0).toDouble()
        : 0.0;
    final isRead = percentage >= 100;
    final percentLabel = formatReadingPercentage(
      percentage,
      l10n.localeName,
      floor: true,
    );
    final pageLabels = bookProgressLabels(
      l10n: l10n,
      book: book,
      readingPercentage: savedPercentage,
      readingLocation: progressValue?.location,
    );
    final progressLabel = savedPercentage?.isFinite == true
        ? pageLabels.full
        : pageLabels.full.isEmpty
        ? percentLabel
        : '${pageLabels.full} · $percentLabel';
    final status = isRead
        ? l10n.bookReadStatus
        : percentage > 0
        ? l10n.libraryInProgress
        : l10n.libraryUnread;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: enabled
                    ? () => context.push('/reader', extra: book)
                    : null,
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(
                  percentage > 0
                      ? l10n.bookContinueReading
                      : book.format == 'epub'
                      ? l10n.readBook
                      : l10n.openBook,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TooltipVisibility(
              visible: true,
              child: IconButton(
                tooltip: isFavorite
                    ? l10n.bookRemoveFavorite
                    : l10n.bookAddFavorite,
                style: IconButton.styleFrom(
                  backgroundColor: isFavorite
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHigh,
                  foregroundColor: isFavorite
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: enabled
                    ? () => setBookFavorite(context, ref, book.id, !isFavorite)
                    : null,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  semanticLabel: isFavorite
                      ? l10n.bookRemoveFavorite
                      : l10n.bookAddFavorite,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (progress.hasError)
          Text(
            l10n.errorLoadingProgress,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (progress.isLoading && !progress.hasValue)
          LinearProgressIndicator(
            minHeight: 2,
            semanticsLabel: l10n.libraryReadingProgress,
          )
        else ...[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                progressLabel,
                key: const ValueKey('book-detail-progress-label'),
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 2,
            color: theme.colorScheme.onSurfaceVariant,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            semanticsLabel: l10n.libraryReadingProgress,
            semanticsValue: '${percentage.floor()}',
          ),
        ],
        const SizedBox(height: AppSpacing.compact),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: AlignmentDirectional.centerStart,
            ),
            onPressed: enabled
                ? () => setBookReadMark(context, ref, book, !isRead)
                : null,
            icon: Icon(
              isRead ? Icons.remove_done : Icons.check_circle_outline,
              size: 18,
            ),
            label: Text(isRead ? l10n.bookUnmarkRead : l10n.bookMarkRead),
          ),
        ),
      ],
    );
  }
}

class _FileMetadata extends StatelessWidget {
  const _FileMetadata({required this.book});

  final BookDto book;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final format = book.format.trim().toUpperCase();
    final pageCount = book.pageCount > 0
        ? NumberFormat.decimalPattern(l10n.localeName).format(book.pageCount)
        : null;
    final size = book.fileSizeBytes > 0
        ? _formatBytes(book.fileSizeBytes, l10n.localeName)
        : null;
    final values = [
      if (format.isNotEmpty) format,
      if (pageCount != null) l10n.bookPageCountCompact(pageCount),
      if (size != null) size,
    ];
    final added = DateFormat.yMMMd(
      l10n.localeName,
    ).format(book.createdAt.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (values.isNotEmpty) ...[
          Text(
            values.join(' · '),
            style: style,
            semanticsLabel: [
              l10n.bookFileInfo,
              if (format.isNotEmpty) format,
              if (pageCount != null) '${l10n.pages}: $pageCount',
              if (size != null) '${l10n.size}: $size',
            ].join(', '),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text('${l10n.added}: $added', style: style),
      ],
    );
  }

  String _formatBytes(int bytes, String locale) {
    const suffixes = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < suffixes.length - 1) {
      size /= 1024;
      unit++;
    }
    final number = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    ).format(size);
    return '$number ${suffixes[unit]}';
  }
}

class _BookDraft {
  _BookDraft(BookDto book, this.originalLabels)
    : originalTitle = book.title,
      originalAuthor = book.author.trim() == 'Unknown Author'
          ? ''
          : book.author.trim(),
      title = book.title,
      author = book.author.trim() == 'Unknown Author' ? '' : book.author,
      genres = originalLabels.genres,
      tags = originalLabels.tags;

  final String originalTitle;
  final String originalAuthor;
  final BookOrganization originalLabels;
  String title;
  String author;
  List<String> genres;
  List<String> tags;
}
