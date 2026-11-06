import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../books/presentation/library_screen.dart';
import '../../discover/presentation/discover_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final _screens = const [LibraryScreen(), DiscoverScreen(), SettingsScreen()];
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
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= AppLayout.desktopBreakpoint;
        final textScaler = MediaQuery.textScalerOf(context);
        final railWidth =
            (192.0 +
                    (textScaler.scale(14) - 14).clamp(0.0, double.infinity) * 7)
                .clamp(192.0, 280.0)
                .toDouble();
        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (desktop) ...[
                SizedBox(
                  width: railWidth,
                  child: ColoredBox(
                    color: theme.scaffoldBackgroundColor,
                    child: SafeArea(
                      right: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.lg + AppSpacing.xs,
                              AppSpacing.lg,
                              AppSpacing.lg,
                            ),
                            child: Text(
                              l10n.appTitle,
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                          Expanded(
                            child: NavigationRail(
                              extended: true,
                              minExtendedWidth: railWidth,
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
                                  icon: const Icon(Icons.explore_outlined),
                                  selectedIcon: const Icon(
                                    Icons.explore_rounded,
                                  ),
                                  label: Text(l10n.discover),
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
              : NavigationBar(
                  height:
                      AppLayout.bottomNavHeight +
                      (textScaler.scale(12) - 12).clamp(0.0, double.infinity) *
                          1.3,
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
                      icon: const Icon(Icons.explore_outlined),
                      selectedIcon: const Icon(Icons.explore_rounded),
                      label: l10n.discover,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.tune_outlined),
                      selectedIcon: const Icon(Icons.tune_rounded),
                      label: l10n.settings,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
