import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../bookmarks/domain/providers/bookmarks_provider.dart';
import '../../books/domain/providers/books_provider.dart';
import '../../highlights/domain/providers/highlights_provider.dart';
import '../../progress/domain/providers/reading_progress_provider.dart';
import '../data/local_sync_service.dart';
import '../data/local_sync_store.dart';
import 'local_sync_qr.dart';
import 'local_sync_scanner.dart';

class LocalSyncScreen extends ConsumerStatefulWidget {
  const LocalSyncScreen({super.key, this.service});

  /// An injected service is owned by this screen and closed when it is removed.
  final LocalSyncService? service;

  @override
  ConsumerState<LocalSyncScreen> createState() => _LocalSyncScreenState();
}

class _LocalSyncScreenState extends ConsumerState<LocalSyncScreen>
    with WidgetsBindingObserver {
  final _invitation = TextEditingController();
  LocalSyncService? _service;
  bool _initializing = true;
  bool _operation = false;
  bool _approval = false;
  bool _scanning = false;
  bool _importing = false;
  bool _stopping = false;
  bool _invalidated = false;
  String? _localError;
  int _generation = 0;

  bool get _cameraSupported =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS => true,
        _ => false,
      };

  bool get _active => switch (_service?.phase) {
    LocalSyncPhase.preparing ||
    LocalSyncPhase.hosting ||
    LocalSyncPhase.awaitingApproval ||
    LocalSyncPhase.connecting ||
    LocalSyncPhase.syncing => true,
    _ => false,
  };

  bool get _canStart =>
      _service != null &&
      !_active &&
      !_operation &&
      !_importing &&
      !_stopping &&
      !_scanning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    setState(() {
      _initializing = true;
      _localError = null;
    });
    try {
      final service =
          widget.service ??
          LocalSyncService(
            store: LocalSyncStore(
              database: getIt<AppDatabase>(),
              directory: await getApplicationDocumentsDirectory(),
            ),
          );
      if (!mounted) {
        await service.close();
        return;
      }
      _service = service;
      service.addListener(_serviceChanged);
    } catch (_) {
      if (mounted) _localError = 'initialization';
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _serviceChanged() {
    if (!mounted) return;
    if (_service?.phase == LocalSyncPhase.complete && !_invalidated) {
      _invalidated = true;
      ref.invalidate(booksControllerProvider);
      ref.invalidate(readingProgressControllerProvider);
      ref.invalidate(highlightsControllerProvider);
      ref.invalidate(bookmarksControllerProvider);
    } else if (_service?.phase != LocalSyncPhase.complete) {
      _invalidated = false;
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive)
      return;
    // Permission prompts can temporarily make the app inactive. The scanner
    // owns that transition; removing its widget is safe once actually hidden.
    if (state != AppLifecycleState.inactive && _scanning && mounted) {
      setState(() => _scanning = false);
    }
    if (_active || _operation) unawaited(_stop(background: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _service?.removeListener(_serviceChanged);
    unawaited(_service?.close());
    _invitation.dispose();
    super.dispose();
  }

  Future<void> _start({String? invitation}) async {
    if (!_canStart) return;
    final service = _service!;
    final generation = ++_generation;
    setState(() {
      _operation = true;
      _localError = null;
    });
    try {
      // Explicitly starting again invalidates the old invitation/session.
      await service.stop();
      if (!mounted || generation != _generation) return;
      if (invitation == null) {
        await service.host();
      } else {
        await service.connect(invitation.trim());
      }
    } catch (_) {
      if (mounted &&
          generation == _generation &&
          service.phase != LocalSyncPhase.failed) {
        setState(() => _localError = 'transferFailed');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _operation = false);
      }
    }
  }

  Future<void> _stop({bool background = false}) async {
    if (_stopping) return;
    _generation++;
    setState(() {
      _stopping = true;
      _operation = false;
      _scanning = false;
      _localError = background ? 'background' : null;
    });
    try {
      await _service?.stop();
    } catch (_) {
      if (mounted) setState(() => _localError = 'transferFailed');
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  Future<void> _approve(bool accepted) async {
    if (_approval || _service?.phase != LocalSyncPhase.awaitingApproval) return;
    setState(() => _approval = true);
    try {
      if (accepted) {
        await _service!.approve();
      } else {
        await _service!.reject();
      }
    } catch (_) {
      if (mounted) setState(() => _localError = 'transferFailed');
    } finally {
      if (mounted) setState(() => _approval = false);
    }
  }

  void _scanned(String invitation) {
    if (!_scanning) return;
    setState(() => _scanning = false);
    _invitation.text = invitation;
    unawaited(_start(invitation: invitation));
  }

  Future<void> _importImage() async {
    if (!_canStart) return;
    setState(() {
      _importing = true;
      _localError = null;
    });
    String? invitation;
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: AppLocalizations.of(context)!.localSyncQrImageType,
            extensions: ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
            uniformTypeIdentifiers: ['public.image'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      if (await file.length() > 20 * 1024 * 1024) {
        throw const FormatException('Image too large');
      }
      invitation = await decodeLocalSyncQrImage(await file.readAsBytes());
    } catch (_) {
      if (mounted) setState(() => _localError = 'image');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
    if (mounted && invitation != null) {
      _invitation.text = invitation;
      await _start(invitation: invitation);
    }
  }

  Future<void> _copyInvitation() async {
    final invitation = _service?.invitation;
    if (invitation == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: invitation));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.localSyncCopied)),
      );
    } catch (_) {
      if (mounted) setState(() => _localError = 'clipboard');
    }
  }

  String _errorText(AppLocalizations l10n, String code) => switch (code) {
    'invalidInvitation' => l10n.localSyncErrorInvalidInvitation,
    'noLocalAddress' => l10n.localSyncErrorNoLocalAddress,
    'expired' => l10n.localSyncErrorExpired,
    'rejected' => l10n.localSyncErrorRejected,
    'unauthorized' => l10n.localSyncErrorUnauthorized,
    'connectionFailed' => l10n.localSyncErrorConnection,
    'cancelled' => l10n.localSyncErrorCancelled,
    'background' => l10n.localSyncStoppedBackground,
    'initialization' => l10n.localSyncErrorInitialization,
    'image' => l10n.localSyncErrorImage,
    'clipboard' => l10n.localSyncErrorClipboard,
    _ => l10n.localSyncErrorTransfer,
  };

  String _phaseText(AppLocalizations l10n, LocalSyncPhase phase) =>
      switch (phase) {
        LocalSyncPhase.idle => l10n.localSyncIdle,
        LocalSyncPhase.preparing => l10n.localSyncPreparing,
        LocalSyncPhase.hosting => l10n.localSyncHosting,
        LocalSyncPhase.awaitingApproval =>
          _service?.invitation != null
              ? l10n.localSyncApproveTitle
              : l10n.localSyncWaitingApproval,
        LocalSyncPhase.connecting => l10n.localSyncConnecting,
        LocalSyncPhase.syncing => l10n.localSyncTransferring,
        LocalSyncPhase.complete => l10n.localSyncComplete,
        LocalSyncPhase.failed => l10n.localSyncFailed,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final service = _service;
    final phase = service?.phase ?? LocalSyncPhase.idle;
    final invitation = service?.invitation;
    final error = _localError ?? service?.error;
    final result = service?.result;
    final waitingForApproval =
        phase == LocalSyncPhase.awaitingApproval && invitation != null;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) unawaited(_service?.stop());
      },
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: AppLayout.formMaxWidth,
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                children: [
                  AppPageHeader(
                    title: l10n.localSyncTitle,
                    leading: Semantics(
                      button: true,
                      label: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppLayout.pageGutter(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (phase == LocalSyncPhase.idle ||
                            phase == LocalSyncPhase.failed) ...[
                          Text(
                            l10n.localSyncDescription,
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        if (_initializing)
                          LinearProgressIndicator(
                            semanticsLabel: l10n.localSyncPreparing,
                          ),
                        if (service != null) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _phaseText(l10n, phase),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (phase == LocalSyncPhase.preparing ||
                              phase == LocalSyncPhase.connecting ||
                              phase == LocalSyncPhase.syncing ||
                              _importing) ...[
                            const SizedBox(height: AppSpacing.sm),
                            LinearProgressIndicator(
                              semanticsLabel: _importing
                                  ? l10n.localSyncImportingImage
                                  : _phaseText(l10n, phase),
                            ),
                          ],
                          if (service.peerName != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(l10n.localSyncPeer(service.peerName!)),
                          ],
                        ],
                        if (error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _errorText(l10n, error),
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ],
                        if (!_initializing && service == null) ...[
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                            onPressed: _initialize,
                            child: Text(l10n.localSyncTryAgain),
                          ),
                        ],
                        if (invitation != null &&
                            phase == LocalSyncPhase.hosting) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(l10n.localSyncShowQrHint),
                          const SizedBox(height: AppSpacing.md),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: Semantics(
                                image: true,
                                label: l10n.localSyncQrLabel,
                                child: ExcludeSemantics(
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: QrImageView(
                                      data: invitation,
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.all(16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: _copyInvitation,
                            icon: const Icon(Icons.copy_outlined),
                            label: Text(l10n.localSyncCopyInvitation),
                          ),
                        ],
                        if (waitingForApproval) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(l10n.localSyncApproveHint),
                          const SizedBox(height: AppSpacing.sm),
                          FilledButton.icon(
                            onPressed: _approval ? null : () => _approve(true),
                            icon: const Icon(Icons.check),
                            label: Text(l10n.localSyncApprove),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: _approval ? null : () => _approve(false),
                            icon: const Icon(Icons.close),
                            label: Text(l10n.localSyncReject),
                          ),
                        ],
                        if (phase == LocalSyncPhase.complete &&
                            result != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              l10n.localSyncResult(
                                result.booksReceived,
                                result.progressChanged,
                                result.highlightsChanged,
                                result.bookmarksChanged,
                              ),
                            ),
                          ),
                        ],
                        if (_active || _operation || _stopping) ...[
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed: _stopping ? null : _stop,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: Text(l10n.localSyncStop),
                          ),
                        ],
                        if (!_active && !_operation && service != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton.icon(
                            onPressed: _canStart ? () => _start() : null,
                            icon: const Icon(Icons.qr_code_rounded),
                            label: Text(
                              phase == LocalSyncPhase.idle
                                  ? l10n.localSyncHost
                                  : l10n.localSyncNewSession,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            l10n.localSyncJoin,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (_cameraSupported && !_scanning)
                            OutlinedButton.icon(
                              onPressed: _canStart
                                  ? () => setState(() {
                                      _scanning = true;
                                      _localError = null;
                                    })
                                  : null,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: Text(l10n.localSyncScan),
                            ),
                          if (!_cameraSupported)
                            Text(l10n.localSyncDesktopScanHint),
                          if (_scanning) ...[
                            LocalSyncScanner(onInvitation: _scanned),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _scanning = false),
                              child: Text(l10n.localSyncCloseCamera),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: _canStart ? _importImage : null,
                            icon: const Icon(Icons.image_outlined),
                            label: Text(l10n.localSyncImportImage),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _invitation,
                            enabled: _canStart,
                            minLines: 2,
                            maxLines: 5,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: l10n.localSyncInvitation,
                              hintText: 'lira-sync:…',
                              alignLabelWithHint: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          FilledButton.tonalIcon(
                            onPressed:
                                _canStart && _invitation.text.trim().isNotEmpty
                                ? () => _start(invitation: _invitation.text)
                                : null,
                            icon: const Icon(Icons.link),
                            label: Text(l10n.localSyncConnect),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(l10n.localSyncDetails),
                          children: [
                            Text(l10n.localSyncSecurity),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              l10n.localSyncMergePolicy,
                              style: theme.textTheme.bodySmall,
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
      ),
    );
  }
}
