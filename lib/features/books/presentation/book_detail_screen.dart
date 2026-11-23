import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/formatters.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../progress/domain/providers/reading_progress_provider.dart';
import '../domain/models/book_dto.dart';
import '../domain/providers/book_organization_provider.dart';
import '../domain/providers/books_provider.dart';
import 'book_labels.dart';
import 'widgets/book_cover.dart';

class BookDetailScreen extends ConsumerWidget {
  final BookDto book;

  const BookDetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currentBook =
        ref
            .watch(booksControllerProvider)
            .valueOrNull
            ?.firstWhere((b) => b.id == book.id, orElse: () => book) ??
        book;
    final organization = ref.watch(bookOrganizationProvider(currentBook.id));
    final gutter = AppLayout.pageGutter(context);
    void editBook() => showAppDialog<void>(
      context: context,
      builder: (_) =>
          _BookEditDialog(book: currentBook, organization: organization),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: gutter,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      MergeSemantics(
                        child: Semantics(
                          label: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          child: BackButton(onPressed: () => context.pop()),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l10n.library,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: editBook,
                        icon: Semantics(
                          label: l10n.editBook,
                          child: const Icon(Icons.edit_outlined),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).showMenuTooltip,
                        onSelected: (_) =>
                            _confirmDelete(context, ref, currentBook),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(l10n.deleteBook),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      AppSpacing.sm,
                      gutter,
                      AppSpacing.xl,
                    ),
                    child: AppSurface(
                      radius: AppRadius.lg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BookIdentity(book: currentBook),
                          const SizedBox(height: AppSpacing.lg),
                          _ReadingAction(book: currentBook),
                          const SizedBox(height: AppSpacing.lg),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.md),
                          if (organization.genres.isEmpty &&
                              organization.tags.isEmpty) ...[
                            Text(
                              l10n.libraryLabels,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l10n.bookLabelsEmpty,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ] else ...[
                            if (organization.genres.isNotEmpty) ...[
                              Text(
                                l10n.bookGenres,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _BookLabels(labels: organization.genres),
                            ],
                            if (organization.tags.isNotEmpty) ...[
                              if (organization.genres.isNotEmpty)
                                const SizedBox(height: AppSpacing.md),
                              Text(
                                l10n.bookTags,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _BookLabels(labels: organization.tags),
                            ],
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            l10n.bookFileInfo,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.compact),
                          _FileInfoRow(
                            label: l10n.pages,
                            value: currentBook.pageCount > 0
                                ? NumberFormat.decimalPattern(
                                    l10n.localeName,
                                  ).format(currentBook.pageCount)
                                : l10n.unknown,
                          ),
                          _FileInfoRow(
                            label: l10n.size,
                            value: currentBook.fileSizeBytes > 0
                                ? _formatBytes(
                                    currentBook.fileSizeBytes,
                                    l10n.localeName,
                                  )
                                : l10n.unknown,
                          ),
                          _FileInfoRow(
                            label: l10n.added,
                            value: DateFormat.yMMMd(
                              l10n.localeName,
                            ).format(currentBook.createdAt.toLocal()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BookDto currentBook,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l10n.deleteBook),
        content: Text(l10n.deleteBookConfirm(currentBook.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(booksControllerProvider.notifier)
          .removeBook(currentBook.id);
      if (context.mounted) context.pop();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.bookEditError)));
    }
  }
}

class _BookIdentity extends StatelessWidget {
  const _BookIdentity({required this.book});

  final BookDto book;

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
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                book.title,
                style: compact && !stacked
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              bookAuthorLabel(book.author, l10n),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppMetadata(label: book.format.toUpperCase()),
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
  const _ReadingAction({required this.book});

  final BookDto book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = ref.watch(readingProgressControllerProvider(book.id));
    final savedPercentage = progress.valueOrNull?.percentage ?? 0;
    final percentage = savedPercentage.isFinite
        ? savedPercentage.clamp(0.0, 100.0)
        : 0.0;
    final percentLabel = formatReadingPercentage(
      percentage,
      l10n.localeName,
      floor: true,
    );
    final status = percentage >= 100
        ? l10n.libraryFinished
        : percentage > 0
        ? l10n.libraryInProgress
        : l10n.libraryUnread;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () => context.push('/reader', extra: book),
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
                  Text(percentLabel, style: theme.textTheme.bodySmall),
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
          ],
        ),
      ),
    );
  }
}

class _BookLabels extends StatelessWidget {
  const _BookLabels({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}

class _FileInfoRow extends StatelessWidget {
  const _FileInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          );
          final valueWidget = Text(value, style: theme.textTheme.bodyMedium);
          if (constraints.maxWidth <
              MediaQuery.textScalerOf(context).scale(280)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: AppSpacing.xs),
                valueWidget,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: constraints.maxWidth * 0.36, child: labelWidget),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _BookEditDialog extends ConsumerStatefulWidget {
  const _BookEditDialog({required this.book, required this.organization});

  final BookDto book;
  final BookOrganization organization;

  @override
  ConsumerState<_BookEditDialog> createState() => _BookEditDialogState();
}

class _BookEditDialogState extends ConsumerState<_BookEditDialog> {
  late final _title = TextEditingController(text: widget.book.title);
  late final _author = TextEditingController(
    text: widget.book.author.trim() == 'Unknown Author'
        ? ''
        : widget.book.author,
  );
  late final _genres = TextEditingController(
    text: widget.organization.genres.join(', '),
  );
  late final _tags = TextEditingController(
    text: widget.organization.tags.join(', '),
  );
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _genres.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> _parseLabels(String value) => value
      .split(RegExp(r'[,\r\n]+'))
      .map((label) => label.trim())
      .where((label) => label.isNotEmpty)
      .toList();

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final title = _title.text.trim();
      final updatedBook = widget.book.copyWith(
        title: title.isEmpty ? widget.book.title : title,
        author: _author.text.trim(),
      );
      await ref.read(booksControllerProvider.notifier).updateBook(updatedBook);
      await ref
          .read(bookOrganizationsProvider.notifier)
          .setLabels(
            widget.book.id,
            BookOrganization(
              genres: _parseLabels(_genres.text),
              tags: _parseLabels(_tags.text),
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.editBook),
        content: SizedBox(
          width: AppLayout.formMaxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                enabled: !_saving,
                decoration: InputDecoration(labelText: l10n.editBookTitle),
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _author,
                enabled: !_saving,
                decoration: InputDecoration(labelText: l10n.editBookAuthor),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.bookLabelsHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _genres,
                enabled: !_saving,
                decoration: InputDecoration(labelText: l10n.bookGenres),
                textCapitalization: TextCapitalization.words,
                minLines: 1,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _tags,
                enabled: !_saving,
                decoration: InputDecoration(labelText: l10n.bookTags),
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
              ),
              if (_failed) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.bookEditError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
