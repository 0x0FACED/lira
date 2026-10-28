import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../data/anna_archive_client.dart';
import '../domain/providers/anna_access_provider.dart';

class AnnaAccessScreen extends ConsumerStatefulWidget {
  const AnnaAccessScreen({super.key});
  @override
  ConsumerState<AnnaAccessScreen> createState() => _AnnaAccessScreenState();
}

class _AnnaAccessScreenState extends ConsumerState<AnnaAccessScreen> {
  late String _origin;
  late final TextEditingController _cookies;
  late final TextEditingController _userAgent;
  bool _saving = false;
  bool _showCookies = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final session = ref.read(annaAccessSessionProvider);
    _origin = session?.origin ?? defaultAnnaArchiveMirrors.first;
    _cookies = TextEditingController(text: session?.cookieHeader ?? '');
    _userAgent = TextEditingController(text: session?.userAgent ?? '');
  }

  @override
  void dispose() {
    _cookies.dispose();
    _userAgent.dispose();
    super.dispose();
  }

  Future<void> _save({bool clear = false}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final session = clear
          ? null
          : AnnaAccessSession(
              origin: _origin,
              cookieHeader: _cookies.text,
              userAgent: _userAgent.text,
            );
      await ref.read(annaAccessSessionProvider.notifier).setSession(session);
      if (!mounted) return;
      if (clear) {
        _cookies.clear();
        _userAgent.clear();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clear ? l10n.annaSessionCleared : l10n.annaSessionSaved,
          ),
        ),
      );
    } on FormatException {
      if (mounted) setState(() => _error = l10n.annaSessionInvalid);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.annaSessionSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (!await launchUrl(
        Uri.parse(_origin).resolve('/search'),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Could not open Anna browser verification');
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.annaSessionOpenError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: AppLayout.formMaxWidth,
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              children: [
                AppPageHeader(
                  title: l10n.annaSessionTitle,
                  leading: const BackButton(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.compact,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.annaSessionHint,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: _origin,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.annaSessionDomain,
                        ),
                        items: [
                          for (final origin in defaultAnnaArchiveMirrors)
                            DropdownMenuItem(
                              value: origin,
                              child: Text(Uri.parse(origin).host),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null && value != _origin)
                                  setState(() {
                                    _origin = value;
                                    _cookies.clear();
                                    _error = null;
                                  });
                              },
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      OutlinedButton.icon(
                        onPressed: _open,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(l10n.annaSessionOpen),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppSurface(
                        color: theme.colorScheme.secondaryContainer,
                        child: Text(
                          l10n.annaSessionConnectionWarning,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.annaSessionInstructions,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      TextField(
                        controller: _cookies,
                        enabled: !_saving,
                        obscureText: !_showCookies,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableIMEPersonalizedLearning: false,
                        decoration: InputDecoration(
                          labelText: 'Cookie',
                          suffixIcon: IconButton(
                            tooltip: l10n.annaSessionToggleCookies,
                            onPressed: () =>
                                setState(() => _showCookies = !_showCookies),
                            icon: Icon(
                              _showCookies
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      TextField(
                        controller: _userAgent,
                        enabled: !_saving,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'User-Agent',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          FilledButton.icon(
                            onPressed: _saving ? null : () => _save(),
                            icon: const Icon(Icons.save_outlined),
                            label: Text(l10n.save),
                          ),
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => _save(clear: true),
                            child: Text(l10n.annaSessionClear),
                          ),
                        ],
                      ),
                      if (_saving) ...[
                        const SizedBox(height: AppSpacing.sm),
                        const LinearProgressIndicator(),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.compact),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
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
}
