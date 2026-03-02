import 'package:flutter/material.dart';

/// Search screen — placeholder for future z-library / API search
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Search'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 64,
                color: theme.colorScheme.primary.withAlpha(120),
              ),
              const SizedBox(height: 24),
              Text('Search Books', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'Search for books online will be available in a future update.\n'
                'You\'ll be able to search z-library and download books directly.',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              // TODO: Add SearchBar and connect to z-library / custom API
            ],
          ),
        ),
      ),
    );
  }
}
