import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/preferences_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_update/data/github_update_client.dart';
import '../../app_update/presentation/app_update_controller.dart';
import '../../app_update/presentation/app_update_settings_card.dart';
import '../../books/domain/providers/open_library_preferences.dart';
import '../../local_sync/presentation/local_sync_screen.dart';
import '../../search/domain/providers/book_source_clients.dart';
import '../../search/presentation/anna_access_screen.dart';
import '../../search/presentation/zlibrary_mirrors_screen.dart';

import '../data/interface_font_scale_provider.dart';
import 'proxy_settings_card.dart';
import 'reader_settings_workspace.dart';
import 'settings_controls.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final _packageInfo = PackageInfo.fromPlatform();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The settings tab is also built while hidden in MainShell's IndexedStack.
    if (TickerMode.valuesOf(context).enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !TickerMode.valuesOf(context).enabled) return;
        final controller = ref.read(appUpdateControllerProvider);
        if (controller.status == AppUpdateStatus.idle &&
            controller.failure == null) {
          unawaited(controller.check());
        }
      });
    }
  }

  Future<void> _openSourceCode() async {
    try {
      if (await launchUrl(
        GitHubUpdateClient.repositoryUri,
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      // Platform launch failures share the same user-facing recovery.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.sourceCodeError)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodySmall;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: AppLayout.formMaxWidth,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              children: [
                AppPageHeader(title: l10n.settings),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppLayout.pageGutter(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAppearance(context, l10n),
                      _SettingsGroup(
                        title: l10n.settingsAccountsSync,
                        cards: [
                          SettingsCard(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.devices_outlined),
                                title: Text(l10n.localProfileTitle),
                                subtitle: Text(
                                  l10n.localProfileHint,
                                  style: hintStyle,
                                ),
                              ),
                              SettingsActionRow(
                                leading: const Icon(Icons.qr_code_rounded),
                                title: Text(l10n.localSyncSettingsAction),
                                subtitle: Text(
                                  l10n.localSyncSettingsHint,
                                  style: hintStyle,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => const LocalSyncScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SettingsCard(
                            children: [
                              SettingsActionRow(
                                leading: const Icon(Icons.person_outline),
                                title: Text(l10n.serverAccountInfoTitle),
                                subtitle: Text(
                                  l10n.serverAccountInfoHint,
                                  style: hintStyle,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push('/login'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _SettingsGroup(
                        title: l10n.openLibrarySettingsGroup,
                        cards: [
                          SettingsCard(
                            children: [
                              SettingsSwitchRow(
                                leading: const Icon(
                                  Icons.auto_stories_outlined,
                                ),
                                title: Text(l10n.openLibraryAutoTitle),
                                subtitle: Text(
                                  l10n.openLibraryAutoHint,
                                  style: hintStyle,
                                ),
                                value: ref.watch(openLibraryAutoProvider),
                                onChanged: (enabled) => ref
                                    .read(openLibraryAutoProvider.notifier)
                                    .setEnabled(enabled),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _buildSources(context, l10n),
                      _SettingsGroup(
                        title: l10n.settingsNetwork,
                        cards: const [ProxySettingsCard()],
                      ),
                      _SettingsGroup(
                        title: l10n.about,
                        cards: [
                          SettingsCard(
                            children: [
                              FutureBuilder<PackageInfo>(
                                future: _packageInfo,
                                builder: (context, snapshot) => ListTile(
                                  leading: const Icon(Icons.info_outline),
                                  title: Text(l10n.version),
                                  subtitle: Text(snapshot.data?.version ?? '—'),
                                ),
                              ),
                            ],
                          ),
                          const AppUpdateSettingsCard(),
                          SettingsCard(
                            children: [
                              SettingsActionRow(
                                leading: SvgPicture.asset(
                                  'assets/icon/github-mark.svg',
                                  width: 24,
                                  height: 24,
                                  colorFilter: ColorFilter.mode(
                                    theme.brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                    BlendMode.srcIn,
                                  ),
                                  excludeFromSemantics: true,
                                ),
                                title: Text(l10n.sourceCode),
                                trailing: const Icon(Icons.open_in_new),
                                onTap: _openSourceCode,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppearance(BuildContext context, AppLocalizations l10n) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final locale = ref.watch(localeProvider);
    final interfaceFontScale = ref.watch(interfaceFontScaleProvider);
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;

    return _SettingsGroup(
      title: l10n.settingsReadingAppearance,
      cards: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Leave enough room for the row title when text is enlarged.
            final inline = constraints.maxWidth >= 340 * textScale;
            return SettingsCard(
              children: [
                SettingsActionRow(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(l10n.readerCustomize),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const ReaderCustomizationScreen(),
                    ),
                  ),
                ),
                SettingsSwitchRow(
                  leading: Icon(
                    isDark
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                  ),
                  title: _SettingValue(
                    label: l10n.theme,
                    inline: inline,
                    value: Text(
                      isDark ? l10n.themeDark : l10n.themeLight,
                      style: valueStyle,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  value: isDark,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggle(),
                ),
                SettingsActionRow(
                  leading: const Icon(Icons.language),
                  title: _SettingValue(
                    label: l10n.language,
                    inline: inline,
                    value: Text(
                      locale.languageCode == 'ru' ? 'Русский' : 'English',
                      style: valueStyle,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showAppDialog<void>(
                    context: context,
                    builder: (dialogContext) => SimpleDialog(
                      titlePadding: const EdgeInsets.only(top: AppSpacing.lg),
                      title: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(l10n.language),
                      ),
                      children: [
                        for (final language in const [
                          ('en', 'English'),
                          ('ru', 'Русский'),
                        ])
                          SettingsActionRow(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            leading: Icon(
                              locale.languageCode == language.$1
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                            ),
                            title: Text(language.$2),
                            selected: locale.languageCode == language.$1,
                            onTap: () {
                              ref
                                  .read(localeProvider.notifier)
                                  .setLocale(language.$1);
                              Navigator.pop(dialogContext);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: _SettingValue(
                    label: l10n.interfaceFontSize,
                    hint: l10n.interfaceFontSizeHint,
                    inline: inline,
                    value: Semantics(
                      label: l10n.interfaceFontSize,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: AppLayout.minTouchTarget,
                          minHeight: AppLayout.minTouchTarget,
                        ),
                        child: DropdownButton<int>(
                          value: interfaceFontScale,
                          style: valueStyle,
                          itemHeight: null,
                          underline: const SizedBox.shrink(),
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                  .read(interfaceFontScaleProvider.notifier)
                                  .setPercent(value);
                            }
                          },
                          items: [
                            for (final percent in interfaceFontScaleOptions)
                              DropdownMenuItem(
                                value: percent,
                                child: Text('$percent%'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSources(BuildContext context, AppLocalizations l10n) {
    final credentials = ref.watch(zLibraryCredentialsProvider);
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodySmall;
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final accountAction = credentials == null
        ? FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              foregroundColor: theme.colorScheme.onSurface,
            ),
            onPressed: () => showAppDialog<void>(
              context: context,
              builder: (_) => const _ZLibraryLoginDialog(),
            ),
            child: Text(l10n.signIn),
          )
        : OutlinedButton.icon(
            onPressed: () => ref
                .read(zLibraryCredentialsProvider.notifier)
                .clearCredentials(),
            icon: const Icon(Icons.logout),
            label: Text(l10n.zLibraryLogout),
          );

    return _SettingsGroup(
      title: l10n.discoverSources,
      cards: [
        SettingsCard(
          children: [
            SettingsActionRow(
              leading: const Icon(Icons.key_outlined),
              title: Text(l10n.annaSessionTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const AnnaAccessScreen()),
              ),
            ),
            SettingsActionRow(
              leading: const Icon(Icons.dns_outlined),
              title: Text(l10n.zLibraryMirrors),
              subtitle: Text(
                l10n.zLibraryMirrorsSettingsHint,
                style: hintStyle,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const ZLibraryMirrorsScreen(),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final inline = constraints.maxWidth >= 360 * textScale;
                final account = ListTile(
                  leading: const Icon(Icons.library_books_outlined),
                  title: Text(l10n.zLibrary),
                  subtitle: Text(
                    credentials == null
                        ? l10n.zLibraryNotLoggedIn
                        : l10n.zLibraryLoggedIn(credentials.email),
                    style: hintStyle,
                  ),
                  trailing: inline ? accountAction : null,
                );
                if (inline) return account;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    account,
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.md,
                        bottom: AppSpacing.sm,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: accountAction,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.cards});

  final String title;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ...cards,
        ],
      ),
    );
  }
}

class _SettingValue extends StatelessWidget {
  const _SettingValue({
    required this.label,
    required this.inline,
    required this.value,
    this.hint,
  });

  final String label;
  final bool inline;
  final Widget value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final title = hint == null
        ? Text(label)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: AppSpacing.xs),
              Text(hint!, style: Theme.of(context).textTheme.bodySmall),
            ],
          );

    if (inline) {
      return Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: AppSpacing.compact),
          value,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        Align(alignment: AlignmentDirectional.centerEnd, child: value),
      ],
    );
  }
}

class _ZLibraryLoginDialog extends ConsumerStatefulWidget {
  const _ZLibraryLoginDialog();

  @override
  ConsumerState<_ZLibraryLoginDialog> createState() =>
      _ZLibraryLoginDialogState();
}

class _ZLibraryLoginDialogState extends ConsumerState<_ZLibraryLoginDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text;
    final password = _passwordController.text;
    final credentials = ref.read(zLibraryCredentialsProvider.notifier);
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(zLibraryApiProvider);
      await api.login(email, password);
      await credentials.saveCredentials(email, api.cookies);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      scrollable: true,
      title: Text(l10n.zLibraryLogin),
      content: SizedBox(
        width: AppLayout.formMaxWidth,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: InputDecoration(labelText: l10n.zLibraryEmail),
              ),
              const SizedBox(height: AppSpacing.compact),
              TextField(
                controller: _passwordController,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: l10n.zLibraryPassword),
                obscureText: true,
                onSubmitted: (_) {
                  if (!_isLoading) _login();
                },
              ),
              AppStateTransition(
                child: _error != null
                    ? Padding(
                        key: ValueKey(_error),
                        padding: const EdgeInsets.only(top: AppSpacing.compact),
                        child: Semantics(
                          liveRegion: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.zLibraryLoginError,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: EdgeInsets.zero,
                                title: Text(l10n.zLibraryLoginErrorDetails),
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: SelectableText(_error!),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey('zlibrary-no-error')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _login,
          child: AppStateTransition(
            child: _isLoading
                ? SizedBox(
                    key: const ValueKey('zlibrary-loading'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.signIn,
                    ),
                  )
                : Text(
                    l10n.signIn,
                    key: const ValueKey('zlibrary-sign-in'),
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
      ],
    );
  }
}
