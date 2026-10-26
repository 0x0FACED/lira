import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/providers/books_provider.dart';
import 'widgets/book_card.dart';
import 'widgets/responsive_grid_delegate.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final booksAsyncValue = ref.watch(booksControllerProvider);
    final controller = ref.read(booksControllerProvider.notifier);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.contentMaxWidth,
            ),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: AppPageHeader(
                    title: l10n.library,
                    actions: [
                      IconButton.filledTonal(
                        tooltip: l10n.importBook,
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          try {
                            await controller.importBook();
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$error',
                                    style: TextStyle(color: colors.onError),
                                  ),
                                  backgroundColor: colors.error,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.compact,
                      0,
                      AppSpacing.compact,
                      AppSpacing.md,
                    ),
                    child: AppSearchField(
                      controller: _searchController,
                      hintText: l10n.searchLibrary,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value.toLowerCase()),
                    ),
                  ),
                ),
                booksAsyncValue.when(
                  data: (books) {
                    final filteredBooks = _searchQuery.isEmpty
                        ? books
                        : books
                              .where(
                                (book) =>
                                    book.title.toLowerCase().contains(
                                      _searchQuery,
                                    ) ||
                                    book.author.toLowerCase().contains(
                                      _searchQuery,
                                    ),
                              )
                              .toList();
                    if (books.isEmpty) {
                      return _stateSliver(
                        AppEmptyState(
                          key: const ValueKey('library-empty'),
                          icon: Icons.local_library_outlined,
                          title: l10n.noBooks,
                          description: l10n.noBooksHint,
                        ),
                      );
                    }
                    if (filteredBooks.isEmpty) {
                      return _stateSliver(
                        AppEmptyState(
                          key: const ValueKey('library-filtered'),
                          icon: Icons.search_off_rounded,
                          title: l10n.searchNoResults,
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.compact,
                        0,
                        AppSpacing.compact,
                        AppSpacing.md,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: ResponsiveGridDelegate(
                          minCrossAxisExtent:
                              MediaQuery.sizeOf(context).width >=
                                  AppLayout.desktopBreakpoint
                              ? 180
                              : 148,
                          maxCrossAxisExtent: 240,
                          crossAxisSpacing: AppSpacing.compact,
                          mainAxisSpacing: AppSpacing.compact,
                          childAspectRatio:
                              0.53 / (textScale < 1 ? 1 : textScale),
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final book = filteredBooks[index];
                          return BookCard(
                            key: ValueKey(book.id),
                            book: book,
                            onTap: () =>
                                context.push('/book-detail', extra: book),
                            onDelete: () => controller.removeBook(book.id),
                          );
                        }, childCount: filteredBooks.length),
                      ),
                    );
                  },
                  loading: () => _stateSliver(
                    const Padding(
                      key: ValueKey('library-loading'),
                      padding: EdgeInsets.all(AppSpacing.compact),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, stackTrace) => _stateSliver(
                    AppEmptyState(
                      key: const ValueKey('library-error'),
                      icon: Icons.error_outline,
                      iconColor: colors.error,
                      title: l10n.errorLoadingBook,
                      description: '$error',
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

  Widget _stateSliver(Widget child) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(child: AppStateTransition(child: child)),
    );
  }
}
