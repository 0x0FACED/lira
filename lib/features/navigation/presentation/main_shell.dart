import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../books/presentation/library_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [LibraryScreen(), SearchScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Nav bar total height: content + safe area
    const navBarHeight = 64.0;
    final totalBarHeight = navBarHeight + bottomPadding;

    return Scaffold(
      // No bottomNavigationBar — we overlay it with blur
      body: Stack(
        children: [
          // Content extends behind the nav bar (no clipping)
          Positioned.fill(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),

          // Glass bottom nav bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: totalBarHeight,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E).withAlpha(180)
                        : Colors.white.withAlpha(200),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withAlpha(15)
                            : Colors.black.withAlpha(15),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: navBarHeight,
                      child: Row(
                        children: [
                          _buildNavItem(
                            index: 0,
                            icon: Icons.library_books_outlined,
                            selectedIcon: Icons.library_books,
                            label: l10n.library,
                            theme: theme,
                          ),
                          _buildNavItem(
                            index: 1,
                            icon: Icons.search_outlined,
                            selectedIcon: Icons.search,
                            label: l10n.search,
                            theme: theme,
                          ),
                          _buildNavItem(
                            index: 2,
                            icon: Icons.settings_outlined,
                            selectedIcon: Icons.settings,
                            label: l10n.settings,
                            theme: theme,
                          ),
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

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required ThemeData theme,
  }) {
    final selected = _currentIndex == index;

    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primary.withAlpha(30)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                size: 24,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
