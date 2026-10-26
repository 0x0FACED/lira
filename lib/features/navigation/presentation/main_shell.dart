import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../books/presentation/library_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final _screens = const [LibraryScreen(), SearchScreen(), SettingsScreen()];
  late final AnimationController _transition;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      value: 1,
      duration: AppMotion.normal,
    );
    final curve = CurveTween(curve: AppMotion.curve);
    _opacity = _transition.drive(curve);
    _position = _transition.drive(
      Tween<Offset>(
        begin: const Offset(0, 0.015),
        end: Offset.zero,
      ).chain(curve),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _transition.duration = AppMotion.duration(context);
    if (_transition.duration == Duration.zero) _transition.value = 1;
  }

  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    if (AppMotion.duration(context) == Duration.zero) {
      _transition.value = 1;
    } else {
      _transition.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= AppLayout.desktopBreakpoint;
        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (desktop) ...[
                SizedBox(
                  width: 192,
                  child: ColoredBox(
                    color: colors.surface,
                    child: SafeArea(
                      right: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.compact,
                              AppSpacing.md,
                              AppSpacing.compact,
                              AppSpacing.md,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.auto_stories_outlined,
                                    color: colors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.compact),
                                Text(
                                  l10n.appTitle,
                                  style: theme.textTheme.headlineMedium,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: NavigationRail(
                              extended: true,
                              minExtendedWidth: 192,
                              selectedIndex: _currentIndex,
                              onDestinationSelected: _selectTab,
                              destinations: [
                                NavigationRailDestination(
                                  icon: const Icon(
                                    Icons.library_books_outlined,
                                  ),
                                  selectedIcon: const Icon(
                                    Icons.library_books_rounded,
                                  ),
                                  label: Text(l10n.library),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.search_outlined),
                                  selectedIcon: const Icon(
                                    Icons.search_rounded,
                                  ),
                                  label: Text(l10n.search),
                                ),
                                NavigationRailDestination(
                                  icon: const Icon(Icons.tune_outlined),
                                  selectedIcon: const Icon(Icons.tune_rounded),
                                  label: Text(l10n.settings),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                key: const ValueKey('tab-content'),
                child: FadeTransition(
                  opacity: _opacity,
                  child: SlideTransition(
                    position: _position,
                    child: IndexedStack(
                      index: _currentIndex,
                      children: [
                        for (var index = 0; index < _screens.length; index++)
                          TickerMode(
                            enabled: index == _currentIndex,
                            child: _screens[index],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(color: colors.outlineVariant),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: NavigationBar(
                      animationDuration: AppMotion.duration(context),
                      selectedIndex: _currentIndex,
                      onDestinationSelected: _selectTab,
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.library_books_outlined),
                          selectedIcon: const Icon(Icons.library_books_rounded),
                          label: l10n.library,
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.search_outlined),
                          selectedIcon: const Icon(Icons.search_rounded),
                          label: l10n.search,
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.tune_outlined),
                          selectedIcon: const Icon(Icons.tune_rounded),
                          label: l10n.settings,
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
