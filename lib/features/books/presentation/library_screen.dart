import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final booksAsyncValue = ref.watch(booksControllerProvider);
    final controller = ref.read(booksControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchLibrary,
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              )
            : Text(l10n.library),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await controller.importBook();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$e')));
            }
          }
        },
        tooltip: l10n.importBook,
        child: const Icon(Icons.add),
      ),
      body: booksAsyncValue.when(
        data: (books) {
          // Filter books by search query
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
                  Text(
                    l10n.noBooks,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noBooksHint,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (filteredBooks.isEmpty) {
            return Center(
              child: Text(
                l10n.noBooks,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
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
    );
  }
}
