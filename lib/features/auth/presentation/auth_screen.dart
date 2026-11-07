import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _loading = false;
  bool _failed = false;

  Future<void> _continue() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await ref.read(authProvider.notifier).continueAsGuest();
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppLayout.pageGutter(context),
              vertical: AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.formMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (context.canPop())
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MergeSemantics(
                        child: Semantics(
                          label: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          child: BackButton(onPressed: () => context.pop()),
                        ),
                      ),
                    ),
                  Text(l10n.appTitle, style: theme.textTheme.displaySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.yourLibrary, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l10n.localAccessTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.localAccessDescription),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.serverAccountUnavailable,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_failed) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.localAccessError,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  FilledButton.icon(
                    onPressed: _loading ? null : _continue,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.menu_book_outlined),
                    label: Text(
                      l10n.localAccessContinue,
                      textAlign: TextAlign.center,
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
