import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        children: [
          // Profile section
          _buildSection(
            context,
            title: 'Profile',
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
                  subtitle: const Text('Signed in'),
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
                  title: const Text('Guest'),
                  subtitle: const Text('Local only — sign in to sync'),
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
                  title: const Text('Not signed in'),
                ),
            ],
          ),

          // Account actions
          _buildSection(
            context,
            title: 'Account',
            children: [
              if (!auth.isLoggedIn) ...[
                // TODO: Navigate to login screen
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Sign In'),
                  onTap: () {
                    // TODO: Navigate to auth screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sign in coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add_outlined),
                  title: const Text('Register'),
                  onTap: () {
                    // TODO: Navigate to auth screen with register mode
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Registration coming soon')),
                    );
                  },
                ),
              ],
              if (auth.isAuthenticated)
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                  },
                ),
            ],
          ),

          // App settings
          _buildSection(
            context,
            title: 'Appearance',
            children: [
              // TODO: Implement theme toggle with Riverpod provider
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Theme'),
                subtitle: const Text('Dark'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Theme toggle coming soon')),
                  );
                },
              ),
              // TODO: Implement language selector
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Language'),
                subtitle: const Text('English'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Language selector coming soon'),
                    ),
                  );
                },
              ),
            ],
          ),

          // About
          _buildSection(
            context,
            title: 'About',
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Version'),
                subtitle: Text('1.0.0'),
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
