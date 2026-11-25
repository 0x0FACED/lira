import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/proxy_connection_check.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'settings_controls.dart';

class ProxySettingsCard extends ConsumerStatefulWidget {
  const ProxySettingsCard({super.key});

  @override
  ConsumerState<ProxySettingsCard> createState() => _ProxySettingsCardState();
}

class _ProxySettingsCardState extends ConsumerState<ProxySettingsCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  static final _invalidHostCharacters = RegExp(r'[\s/@?#\\\[\]]');
  bool _draftEdited = false;
  bool _checking = false;
  bool _saving = false;
  bool _saved = false;
  bool _saveFailed = false;
  int _draftRevision = 0;
  int? _checkingRevision;
  ProxyConnectionResult? _checkResult;

  @override
  void initState() {
    super.initState();
    final config = ref.read(socks5ConfigProvider);
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: '${config.port}');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  String get _draftHost {
    final host = _hostController.text.trim();
    return host.startsWith('[') && host.endsWith(']')
        ? host.substring(1, host.length - 1)
        : host;
  }

  String? _validateHost(AppLocalizations l10n) {
    final host = _draftHost;
    if (host.isEmpty) return l10n.proxyHostRequired;
    if (_invalidHostCharacters.hasMatch(host) ||
        (host.contains(':') &&
            InternetAddress.tryParse(host)?.type != InternetAddressType.IPv6)) {
      return l10n.proxyHostInvalid;
    }
    return null;
  }

  void _draftChanged(String _) {
    setState(() {
      _draftEdited = true;
      _draftRevision++;
      _checkResult = null;
      _saved = false;
      _saveFailed = false;
    });
  }

  Future<void> _check() async {
    if (_checking || !_formKey.currentState!.validate()) return;
    final revision = _draftRevision;
    final config = Socks5Config(
      enabled: true,
      host: _draftHost,
      port: int.parse(_portController.text.trim()),
    );
    setState(() {
      _checking = true;
      _checkingRevision = revision;
      _checkResult = null;
      _saved = false;
      _saveFailed = false;
    });
    final result = await checkProxyConnection(config);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _checkingRevision = null;
      if (_draftRevision == revision) _checkResult = result;
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final revision = _draftRevision;
    final host = _draftHost;
    final port = int.parse(_portController.text.trim());
    setState(() {
      _saving = true;
      _saved = false;
      _saveFailed = false;
    });
    try {
      await ref.read(socks5ConfigProvider.notifier).setEndpoint(host, port);
      if (!mounted || revision != _draftRevision) return;
      setState(() {
        _draftEdited = false;
        _saved = true;
      });
    } catch (_) {
      if (!mounted || revision != _draftRevision) return;
      setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(socks5ConfigProvider);
    final displayHost = config.host.contains(':')
        ? '[${config.host}]'
        : config.host;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    ref.listen(socks5ConfigProvider, (previous, next) {
      if (_draftEdited ||
          (previous?.host == next.host && previous?.port == next.port)) {
        return;
      }
      _hostController.text = next.host;
      _portController.text = '${next.port}';
      setState(() {
        _draftRevision++;
        _checkResult = null;
        _saved = false;
        _saveFailed = false;
      });
    });

    final host = TextFormField(
      controller: _hostController,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: l10n.proxyHost,
        filled: true,
        fillColor: colors.surface,
        errorMaxLines: 3,
      ),
      validator: (_) => _validateHost(l10n),
      onChanged: _draftChanged,
    );
    final port = TextFormField(
      controller: _portController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: l10n.proxyPort,
        filled: true,
        fillColor: colors.surface,
        errorMaxLines: 3,
      ),
      validator: (value) {
        final port = int.tryParse(value?.trim() ?? '');
        return port == null || port < 1 || port > 65535
            ? l10n.proxyPortInvalid
            : null;
      },
      onChanged: _draftChanged,
      onFieldSubmitted: (_) => _save(),
    );
    final checkingCurrentDraft =
        _checking && _checkingRevision == _draftRevision;
    final resultMessage = switch (_checkResult) {
      ProxyConnectionResult.connected => l10n.proxyCheckConnected,
      ProxyConnectionResult.timedOut => l10n.proxyCheckTimedOut,
      ProxyConnectionResult.proxyUnavailable => l10n.proxyCheckProxyUnavailable,
      ProxyConnectionResult.serviceUnavailable =>
        l10n.proxyCheckServiceUnavailable,
      null => null,
    };

    return SettingsCard(
      children: [
        SettingsSwitchRow(
          leading: const Icon(Icons.vpn_lock_outlined),
          title: Text(l10n.proxyTitle),
          subtitle: Text(
            config.enabled
                ? l10n.proxyAppliedEndpoint(displayHost, config.port)
                : l10n.proxySavedEndpoint(displayHost, config.port),
          ),
          value: config.enabled,
          onChanged: (value) =>
              ref.read(socks5ConfigProvider.notifier).setEnabled(value),
        ),
        Padding(
          key: const ValueKey('proxy-fields'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.proxyDraftHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale =
                        MediaQuery.textScalerOf(context).scale(16) / 16;
                    if (constraints.maxWidth < 400 || textScale > 1.3) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          host,
                          const SizedBox(height: AppSpacing.compact),
                          port,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: host),
                        const SizedBox(width: AppSpacing.compact),
                        SizedBox(width: 128, child: port),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.compact),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    TextButton(
                      onPressed: _checking ? null : _check,
                      child: Text(l10n.proxyCheckAction),
                    ),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(l10n.save),
                    ),
                  ],
                ),
                if (checkingCurrentDraft || resultMessage != null) ...[
                  const SizedBox(height: AppSpacing.compact),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (checkingCurrentDraft)
                          const ExcludeSemantics(
                            child: SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          Icon(
                            _checkResult == ProxyConnectionResult.connected
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            checkingCurrentDraft
                                ? l10n.proxyCheckInProgress
                                : resultMessage!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_saving || _saved || _saveFailed) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _saving
                          ? l10n.proxySaving
                          : _saveFailed
                          ? l10n.proxySaveFailed
                          : l10n.proxySaved,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _saveFailed ? colors.error : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
