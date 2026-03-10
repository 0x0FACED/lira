import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zlibrary_api/zlibrary_api.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../auth/domain/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showZLibraryLoginDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? error;

    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.zLibraryLogin),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(labelText: l10n.zLibraryEmail),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(labelText: l10n.zLibraryPassword),
                    obscureText: true,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() {
                            isLoading = true;
                            error = null;
                          });
                          try {
                            final api = ZLibraryApi();
                            await api.login(
                              emailController.text,
                              passwordController.text,
                            );
                            await ref.read(zLibraryCredentialsProvider.notifier).saveCredentials(
                              emailController.text,
                              api.cookies,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            setState(() {
                              error = e.toString();
                              isLoading = false;
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.signIn),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings), centerTitle: true),
      body: ListView(
        children: [
          _buildSection(
            context,
            title: l10n.profile,
            children: [
              if (auth.isLoggedIn)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      (auth.username ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(auth.username ?? 'User'),
                  subtitle: Text(l10n.signedIn),
                )
              else if (auth.isGuest)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[700],
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(l10n.guest),
                  subtitle: Text(l10n.guestSyncHint),
                )
              else
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[700],
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(l10n.notSignedIn),
                ),
            ],
          ),

          _buildSection(
            context,
            title: l10n.account,
            children: [
              if (!auth.isLoggedIn)
                ListTile(
                  leading: const Icon(Icons.login),
                  title: Text(l10n.signIn),
                  onTap: () => context.push('/login'),
                ),
              if (auth.isLoggedIn)
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    l10n.logout,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                  },
                ),
            ],
          ),

          _buildSection(
            context,
            title: l10n.zLibrary,
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final zLibCreds = ref.watch(zLibraryCredentialsProvider);
                  
                  if (zLibCreds != null) {
                    return ListTile(
                      leading: const Icon(Icons.library_books, color: Colors.green),
                      title: Text(l10n.zLibraryLoggedIn(zLibCreds.email)),
                      trailing: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        onPressed: () {
                          ref.read(zLibraryCredentialsProvider.notifier).clearCredentials();
                        },
                      ),
                    );
                  } else {
                    return ListTile(
                      leading: const Icon(Icons.library_books),
                      title: Text(l10n.zLibraryNotLoggedIn),
                      trailing: ElevatedButton(
                        onPressed: () => _showZLibraryLoginDialog(context, ref),
                        child: Text(l10n.signIn),
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          _buildSection(
            context,
            title: l10n.appearance,
            children: [
              ListTile(
                leading: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
                title: Text(l10n.theme),
                subtitle: Text(
                  themeMode == ThemeMode.dark ? l10n.themeDark : 'Light',
                ),
                trailing: Switch(
                  value: themeMode == ThemeMode.dark,
                  onChanged: (_) {
                    ref.read(themeModeProvider.notifier).toggle();
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.language),
                subtitle: Text(
                  locale.languageCode == 'ru' ? 'Русский' : 'English',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: Text(l10n.language),
                      children: [
                        ListTile(
                          leading: Icon(
                            locale.languageCode == 'en'
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          title: const Text('English'),
                          onTap: () {
                            ref.read(localeProvider.notifier).setLocale('en');
                            Navigator.pop(ctx);
                          },
                        ),
                        ListTile(
                          leading: Icon(
                            locale.languageCode == 'ru'
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          title: const Text('Русский'),
                          onTap: () {
                            ref.read(localeProvider.notifier).setLocale('ru');
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          _buildSection(
            context,
            title: l10n.about,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.version),
                subtitle: const Text('1.0.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }
}
