import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/providers/books_provider.dart';
import 'widgets/book_card.dart';
import 'widgets/responsive_grid_delegate.dart';

/// Bottom nav bar height to add as scroll padding so content goes behind the glass bar.
const kBottomNavBarHeight = 64.0;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isSearching = false;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final booksAsyncValue = ref.watch(booksControllerProvider);
    final controller = ref.read(booksControllerProvider.notifier);
    final bottomPadding =
        MediaQuery.of(context).padding.bottom + kBottomNavBarHeight + 16;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: kBottomNavBarHeight + MediaQuery.of(context).padding.bottom,
        ),
        child: FloatingActionButton(
          onPressed: () async {
            try {
              await controller.importBook();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
          tooltip: l10n.importBook,
          child: const Icon(Icons.add),
        ),
      ),
      body: Stack(
        children: [
          // Scrollable content — extends behind both bars
          Positioned.fill(
            child: booksAsyncValue.when(
              data: (books) {
                final filteredBooks = _searchQuery.isEmpty
                    ? books
                    : books
                          .where(
                            (b) =>
                                b.title.toLowerCase().contains(_searchQuery) ||
                                b.author.toLowerCase().contains(_searchQuery),
                          )
                          .toList();

                if (books.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_books,
                          size: 64,
                          color: Colors.grey.withAlpha(120),
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.noBooks, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          l10n.noBooksHint,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredBooks.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noBooks,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: Colors.grey),
                    ),
                  );
                }

                return GridView.builder(
                  // Top padding = space for glass AppBar, bottom = space for glass nav bar
                  padding: EdgeInsets.fromLTRB(
                    16,
                    topPadding + 56 + 16, // safe area + appbar + gap
                    16,
                    bottomPadding,
                  ),
                  gridDelegate: const ResponsiveGridDelegate(
                    minCrossAxisExtent: 160,
                    maxCrossAxisExtent: 220,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.55,
                  ),
                  itemCount: filteredBooks.length,
                  itemBuilder: (context, index) {
                    final book = filteredBooks[index];
                    return BookCard(
                      book: book,
                      onTap: () {
                        context.push('/book-detail', extra: book);
                      },
                      onDelete: () => controller.removeBook(book.id),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),

          // Glass AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF121212).withAlpha(180)
                        : Colors.white.withAlpha(200),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white.withAlpha(15)
                            : Colors.black.withAlpha(15),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Expanded(
                            child: _isSearching
                                ? TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: l10n.searchLibrary,
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(100),
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                    onChanged: (value) {
                                      setState(
                                        () =>
                                            _searchQuery = value.toLowerCase(),
                                      );
                                    },
                                  )
                                : Text(
                                    l10n.library,
                                    style:
                                        theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isSearching ? Icons.close : Icons.search,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSearching = !_isSearching;
                                if (!_isSearching) {
                                  _searchQuery = '';
                                  _searchController.clear();
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
