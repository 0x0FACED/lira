import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';

class LocalSyncScanner extends StatefulWidget {
  const LocalSyncScanner({super.key, required this.onInvitation});

  final ValueChanged<String> onInvitation;

  @override
  State<LocalSyncScanner> createState() => _LocalSyncScannerState();
}

class _LocalSyncScannerState extends State<LocalSyncScanner> {
  bool _detected = false;
  bool _wrongCode = false;

  void _detect(BarcodeCapture capture) {
    if (_detected) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null) continue;
      if (!value.startsWith('lira-sync:')) {
        if (!_wrongCode) setState(() => _wrongCode = true);
        continue;
      }
      _detected = true;
      widget.onInvitation(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final supported =
        !kIsWeb &&
        switch (defaultTargetPlatform) {
          TargetPlatform.android ||
          TargetPlatform.iOS ||
          TargetPlatform.macOS => true,
          _ => false,
        };
    if (!supported) return Text(l10n.localSyncDesktopScanHint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.localSyncScanHint),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: l10n.localSyncScan,
          image: true,
          child: SizedBox(
            height: 280,
            // The scanner owns its default controller, including permission
            // prompts, foreground pause/resume, and disposal of the camera.
            child: MobileScanner(
              onDetect: _detect,
              errorBuilder: (context, error) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(l10n.localSyncCameraUnavailable),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_wrongCode) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(l10n.localSyncErrorInvalidInvitation),
          ),
        ],
      ],
    );
  }
}
