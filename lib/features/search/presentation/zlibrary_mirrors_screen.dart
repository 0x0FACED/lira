import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zlibrary_api/zlibrary_api.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/providers/book_source_clients.dart';
import '../domain/providers/zlibrary_mirrors_provider.dart';

class ZLibraryMirrorsScreen extends ConsumerStatefulWidget {
  const ZLibraryMirrorsScreen({super.key});

  @override
  ConsumerState<ZLibraryMirrorsScreen> createState() =>
      _ZLibraryMirrorsScreenState();
}

class _ZLibraryMirrorsScreenState extends ConsumerState<ZLibraryMirrorsScreen> {
  late final TextEditingController _controller;
  bool _saving = false;
  bool _discovering = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(zLibraryMirrorsProvider).join('\n'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final lines = _controller.text
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty);
      await ref.read(zLibraryMirrorsProvider.notifier).setMirrors(lines);
      if (!mounted) return;
      _controller.text = ref.read(zLibraryMirrorsProvider).join('\n');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.zLibraryMirrorsSaved)));
    } on FormatException {
      if (mounted) setState(() => _error = l10n.zLibraryMirrorInvalid);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.zLibraryMirrorsSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discover() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _discovering = true;
      _error = null;
    });
    try {
      final suggestions = await ref
          .read(zLibraryMirrorDirectoryProvider)
          .fetch();
      if (!mounted) return;
      final chosen = await showAppDialog<List<String>>(
        context: context,
        builder: (_) => _MirrorSuggestionsDialog(mirrors: suggestions),
      );
      if (!mounted || chosen == null || chosen.isEmpty) return;
      final lines = _controller.text
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toSet();
      lines.addAll(chosen);
      _controller.text = lines.join('\n');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.zLibraryMirrorsReviewSave)));
    } catch (_) {
      if (mounted) setState(() => _error = l10n.zLibraryMirrorDirectoryError);
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Future<void> _openDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (!await launchUrl(
        Uri.parse(zLibraryMirrorDirectoryUrl),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Could not open mirror directory');
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = l10n.zLibraryMirrorDirectoryOpenError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final busy = _saving || _discovering;
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
                  title: l10n.zLibraryMirrors,
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
                        l10n.zLibraryMirrorsHint,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppSurface(
                        color: theme.colorScheme.secondaryContainer,
                        child: Text(
                          l10n.zLibraryMirrorsTrustWarning,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _controller,
                        enabled: !busy,
                        minLines: 4,
                        maxLines: 12,
                        keyboardType: TextInputType.multiline,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: l10n.zLibraryMirrorsField,
                          helperText: l10n.zLibraryMirrorsFieldHint,
                          helperMaxLines: 3,
                        ),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: AppSpacing.compact),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          FilledButton.icon(
                            onPressed: busy ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              _saving ? l10n.zLibraryMirrorsSaving : l10n.save,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : _discover,
                            icon: const Icon(Icons.travel_explore_outlined),
                            label: Text(
                              _discovering
                                  ? l10n.zLibraryMirrorsFinding
                                  : l10n.zLibraryMirrorsFind,
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () {
                                    _controller.text = defaultZLibraryMirrors
                                        .join('\n');
                                    setState(() => _error = null);
                                  },
                            child: Text(l10n.zLibraryMirrorsRestore),
                          ),
                        ],
                      ),
                      if (busy) ...[
                        const SizedBox(height: AppSpacing.compact),
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
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.zLibraryMirrorDirectoryHint,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: _openDirectory,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(l10n.zLibraryMirrorDirectoryOpen),
                        ),
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
}

class _MirrorSuggestionsDialog extends StatefulWidget {
  const _MirrorSuggestionsDialog({required this.mirrors});
  final List<String> mirrors;

  @override
  State<_MirrorSuggestionsDialog> createState() =>
      _MirrorSuggestionsDialogState();
}

class _MirrorSuggestionsDialogState extends State<_MirrorSuggestionsDialog> {
  late final Set<String> _selected = widget.mirrors.toSet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.zLibraryMirrorsFound),
      content: SizedBox(
        width: AppLayout.formMaxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.zLibraryMirrorsReviewHint),
            const SizedBox(height: AppSpacing.sm),
            for (final mirror in widget.mirrors)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(mirror),
                value: _selected.contains(mirror),
                onChanged: (selected) => setState(() {
                  if (selected == true) {
                    _selected.add(mirror);
                  } else {
                    _selected.remove(mirror);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList()),
          child: Text(l10n.zLibraryMirrorsAddSelected),
        ),
      ],
    );
  }
}
