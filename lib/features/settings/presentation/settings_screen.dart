import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/providers/preferences_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_update/presentation/app_update_controller.dart';
import '../../app_update/presentation/app_update_settings_section.dart';
import '../../auth/domain/providers/auth_provider.dart';
import '../../search/domain/providers/book_source_clients.dart';
import '../../search/presentation/zlibrary_mirrors_screen.dart';
import '../../search/presentation/anna_access_screen.dart';

import '../data/interface_font_scale_provider.dart';
import 'reader_settings_workspace.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final interfaceFontScale = ref.watch(interfaceFontScaleProvider);
    final zLibCredentials = ref.watch(zLibraryCredentialsProvider);

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
                      AppSection(
                        title: l10n.profile,
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.person_outline,
                              color: colors.onSurfaceVariant,
                            ),
                            title: Text(
                              auth.isLoggedIn
                                  ? auth.username ?? 'User'
                                  : auth.isGuest
                                  ? l10n.guest
                                  : l10n.notSignedIn,
                            ),
                            subtitle: auth.isLoggedIn
                                ? Text(l10n.signedIn)
                                : auth.isGuest
                                ? Text(l10n.guestSyncHint)
                                : null,
                          ),
                        ],
                      ),
                      AppSection(
                        title: l10n.account,
                        children: [
                          if (!auth.isLoggedIn)
                            ListTile(
                              leading: const Icon(Icons.login),
                              title: Text(l10n.signIn),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/login'),
                            )
                          else
                            ListTile(
                              leading: Icon(Icons.logout, color: colors.error),
                              title: Text(
                                l10n.logout,
                                style: TextStyle(color: colors.error),
                              ),
                              onTap: () async {
                                await ref.read(authProvider.notifier).logout();
                              },
                            ),
                        ],
                      ),
                      AppSection(
                        title: 'Anna’s Archive',
                        children: [
                          ListTile(
                            leading: const Icon(Icons.key_outlined),
                            title: Text(l10n.annaSessionTitle),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => const AnnaAccessScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSection(
                        title: l10n.zLibrary,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.dns_outlined),
                            title: Text(l10n.zLibraryMirrors),
                            subtitle: Text(l10n.zLibraryMirrorsSettingsHint),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => const ZLibraryMirrorsScreen(),
                              ),
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.library_books_outlined,
                              color: zLibCredentials != null
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                            title: Text(
                              zLibCredentials != null
                                  ? l10n.zLibraryLoggedIn(zLibCredentials.email)
                                  : l10n.zLibraryNotLoggedIn,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: zLibCredentials != null
                                  ? OutlinedButton.icon(
                                      onPressed: () {
                                        ref
                                            .read(
                                              zLibraryCredentialsProvider
                                                  .notifier,
                                            )
                                            .clearCredentials();
                                      },
                                      icon: const Icon(Icons.logout),
                                      label: Text(l10n.zLibraryLogout),
                                    )
                                  : FilledButton(
                                      onPressed: () => showAppDialog<void>(
                                        context: context,
                                        builder: (_) =>
                                            const _ZLibraryLoginDialog(),
                                      ),
                                      child: Text(l10n.signIn),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      AppSection(
                        title: l10n.appearance,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.compact,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.text_fields),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        l10n.interfaceFontSize,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  l10n.interfaceFontSizeHint,
                                  style: theme.textTheme.bodySmall,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Semantics(
                                    label: l10n.interfaceFontSize,
                                    child: DropdownButton<int>(
                                      value: interfaceFontScale,
                                      itemHeight: null,
                                      underline: const SizedBox.shrink(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          ref
                                              .read(
                                                interfaceFontScaleProvider
                                                    .notifier,
                                              )
                                              .setPercent(value);
                                        }
                                      },
                                      items: [
                                        for (final percent
                                            in interfaceFontScaleOptions)
                                          DropdownMenuItem(
                                            value: percent,
                                            child: Text('$percent%'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ListTile(
                            leading: const Icon(Icons.menu_book_outlined),
                            title: Text(l10n.readerCustomize),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ReaderCustomizationScreen(),
                              ),
                            ),
                          ),
                          SwitchListTile(
                            secondary: Icon(
                              themeMode == ThemeMode.dark
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                            ),
                            title: Text(l10n.theme),
                            subtitle: Text(
                              themeMode == ThemeMode.dark
                                  ? l10n.themeDark
                                  : l10n.themeLight,
                            ),
                            value: themeMode == ThemeMode.dark,
                            onChanged: (_) {
                              ref.read(themeModeProvider.notifier).toggle();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.language),
                            title: Text(l10n.language),
                            subtitle: Text(
                              locale.languageCode == 'ru'
                                  ? 'Русский'
                                  : 'English',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => showAppDialog<void>(
                              context: context,
                              builder: (dialogContext) => SimpleDialog(
                                title: Text(l10n.language),
                                children: [
                                  for (final language in const [
                                    ('en', 'English'),
                                    ('ru', 'Русский'),
                                  ])
                                    ListTile(
                                      leading: Icon(
                                        locale.languageCode == language.$1
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                      ),
                                      title: Text(language.$2),
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
                        ],
                      ),
                      _buildProxySection(context, ref),
                      const AppUpdateSettingsSection(),
                      AppSection(
                        title: l10n.about,
                        children: [
                          FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) => ListTile(
                              leading: const Icon(Icons.info_outline),
                              title: Text(l10n.version),
                              subtitle: AppMetadata(
                                label: snapshot.data?.version ?? '—',
                              ),
                            ),
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

  Widget _buildProxySection(BuildContext context, WidgetRef ref) {
    final proxyConfig = ref.watch(socks5ConfigProvider);
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return AppSection(
      title: 'SOCKS5 Proxy',
      children: [
        SwitchListTile(
          secondary: Icon(
            Icons.vpn_lock_outlined,
            color: proxyConfig.enabled
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
          title: const Text('SOCKS5 Proxy'),
          subtitle: Text(
            proxyConfig.enabled
                ? '${proxyConfig.host}:${proxyConfig.port}'
                : l10n.proxyDisabled,
          ),
          value: proxyConfig.enabled,
          onChanged: (value) {
            ref.read(socks5ConfigProvider.notifier).setEnabled(value);
          },
        ),
        AppStateTransition(
          child: proxyConfig.enabled
              ? Padding(
                  key: const ValueKey('proxy-fields'),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: proxyConfig.host,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(labelText: l10n.proxyHost),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            ref
                                .read(socks5ConfigProvider.notifier)
                                .setHost(value);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      TextFormField(
                        initialValue: proxyConfig.port.toString(),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(labelText: l10n.proxyPort),
                        onChanged: (value) {
                          final port = int.tryParse(value);
                          if (port != null && port > 0 && port <= 65535) {
                            ref
                                .read(socks5ConfigProvider.notifier)
                                .setPort(port);
                          }
                        },
                      ),
                    ],
                  ),
                )
              : const SizedBox(
                  key: ValueKey('proxy-disabled'),
                  width: double.infinity,
                ),
        ),
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
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
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
