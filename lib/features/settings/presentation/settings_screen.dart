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
import '../../local_sync/presentation/local_sync_screen.dart';
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
  final _proxyFormKey = GlobalKey<FormState>();
  final _proxyHostController = TextEditingController();
  final _proxyPortController = TextEditingController();
  bool _proxyDraftInitialized = false;
  bool _proxyDraftEdited = false;

  @override
  void dispose() {
    _proxyHostController.dispose();
    _proxyPortController.dispose();
    super.dispose();
  }

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
                            title: Text(l10n.localProfileTitle),
                            subtitle: Text(l10n.localProfileHint),
                          ),
                        ],
                      ),
                      AppSection(
                        title: l10n.account,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: Text(l10n.serverAccountInfoTitle),
                            subtitle: Text(l10n.serverAccountInfoHint),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/login'),
                          ),
                        ],
                      ),
                      AppSection(
                        title: l10n.localSyncTitle,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.qr_code_rounded),
                            title: Text(l10n.localSyncSettingsAction),
                            subtitle: Text(l10n.localSyncSettingsHint),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => const LocalSyncScreen(),
                              ),
                            ),
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
                                    const SizedBox(width: AppSpacing.md),
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
    if (!_proxyDraftInitialized) {
      _proxyHostController.text = proxyConfig.host;
      _proxyPortController.text = '${proxyConfig.port}';
      _proxyDraftInitialized = true;
    }
    ref.listen(socks5ConfigProvider, (_, next) {
      if (_proxyDraftEdited) return;
      _proxyHostController.text = next.host;
      _proxyPortController.text = '${next.port}';
    });

    Future<void> applyProxy() async {
      if (!_proxyFormKey.currentState!.validate()) return;
      final host = _proxyHostController.text.trim();
      final port = int.parse(_proxyPortController.text.trim());
      final notifier = ref.read(socks5ConfigProvider.notifier);
      await notifier.setHost(host);
      await notifier.setPort(port);
    }

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
                ? l10n.proxyAppliedEndpoint(proxyConfig.host, proxyConfig.port)
                : l10n.proxyDisabled,
          ),
          value: proxyConfig.enabled,
          onChanged: (value) {
            ref.read(socks5ConfigProvider.notifier).setEnabled(value);
          },
        ),
        if (proxyConfig.enabled)
          Padding(
            key: const ValueKey('proxy-fields'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Form(
              key: _proxyFormKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _proxyHostController,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.proxyHost,
                      errorMaxLines: 3,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? l10n.proxyHostRequired
                        : null,
                    onChanged: (_) => _proxyDraftEdited = true,
                  ),
                  const SizedBox(height: AppSpacing.compact),
                  TextFormField(
                    controller: _proxyPortController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.proxyPort,
                      errorMaxLines: 3,
                    ),
                    validator: (value) {
                      final port = int.tryParse(value?.trim() ?? '');
                      return port == null || port < 1 || port > 65535
                          ? l10n.proxyPortInvalid
                          : null;
                    },
                    onChanged: (_) => _proxyDraftEdited = true,
                    onFieldSubmitted: (_) => applyProxy(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: applyProxy,
                      child: Text(l10n.save),
                    ),
                  ),
                ],
              ),
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
