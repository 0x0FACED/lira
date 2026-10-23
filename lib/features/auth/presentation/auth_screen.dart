import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    final l10n = AppLocalizations.of(context)!;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          content: Text(
            l10n.fillAllFields,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await ref
            .read(authProvider.notifier)
            .login(username: username, password: password);
      } else {
        await ref
            .read(authProvider.notifier)
            .register(username: username, password: password);
      }
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            content: Text(
              'Error: $e',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuest() async {
    await ref.read(authProvider.notifier).continueAsGuest();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.formMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Icon(
                      Icons.auto_stories_outlined,
                      size: 32,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.appTitle, style: theme.textTheme.displaySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.yourLibrary,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppSurface(
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppStateTransition(
                            child: Align(
                              key: ValueKey(_isLogin ? 'login' : 'register'),
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                _isLogin ? l10n.signIn : l10n.register,
                                style: theme.textTheme.headlineSmall,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            controller: _usernameController,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.username,
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _passwordController,
                            autofillHints: [
                              _isLogin
                                  ? AutofillHints.password
                                  : AutofillHints.newPassword,
                            ],
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: l10n.password,
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            onSubmitted: (_) => _handleAuth(),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            onPressed: _isLoading ? null : _handleAuth,
                            child: AppStateTransition(
                              child: _isLoading
                                  ? SizedBox(
                                      key: const ValueKey('auth-loading'),
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        semanticsLabel: _isLogin
                                            ? l10n.signIn
                                            : l10n.register,
                                      ),
                                    )
                                  : Text(
                                      key: ValueKey(
                                        _isLogin ? 'sign-in' : 'register',
                                      ),
                                      _isLogin ? l10n.signIn : l10n.register,
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton(
                            onPressed: () =>
                                setState(() => _isLogin = !_isLogin),
                            child: Text(
                              _isLogin
                                  ? l10n.noAccountRegister
                                  : l10n.haveAccountSignIn,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Divider(),
                          ),
                          OutlinedButton.icon(
                            onPressed: _handleGuest,
                            icon: const Icon(Icons.visibility_off_outlined),
                            label: Text(
                              l10n.continueAsGuest,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.compact),
                          Text(
                            l10n.guestLocalOnly,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
