import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/app_update.dart';
import 'app_update_controller.dart';

class AppUpdateSettingsSection extends ConsumerStatefulWidget {
  const AppUpdateSettingsSection({super.key});

  @override
  ConsumerState<AppUpdateSettingsSection> createState() =>
      _AppUpdateSettingsSectionState();
}

class _AppUpdateSettingsSectionState
    extends ConsumerState<AppUpdateSettingsSection> {
  Future<void> _openRelease(Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Platform launch failures have the same user-facing recovery action.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.updateReleaseError)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appUpdateControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final decimal = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    );
    final release = controller.release;
    final status = controller.status;
    final message = switch (status) {
      AppUpdateStatus.idle => l10n.updateCheckHint,
      AppUpdateStatus.checking => l10n.updateChecking,
      AppUpdateStatus.upToDate => l10n.updateUpToDate,
      AppUpdateStatus.available => l10n.updateAvailable(
        release!.version.displayVersion,
      ),
      AppUpdateStatus.downloading => l10n.updateDownloading(
        NumberFormat.percentPattern(locale).format(controller.progress),
        decimal.format(controller.receivedBytes / (1024 * 1024)),
        decimal.format(controller.totalBytes / (1024 * 1024)),
      ),
      AppUpdateStatus.ready => l10n.updateReady(
        release!.version.displayVersion,
      ),
      AppUpdateStatus.installing => l10n.updateOpeningInstaller,
    };
    final failure = controller.failure;
    final installFailure = controller.installFailure;
    final error = failure != null
        ? switch (failure) {
            UpdateFailure.unavailable => l10n.updateUnavailable,
            UpdateFailure.network => l10n.updateNetworkError,
            UpdateFailure.rateLimited => l10n.updateRateLimited,
            UpdateFailure.invalidRelease => l10n.updateInvalidRelease,
            UpdateFailure.download => l10n.updateDownloadError,
            UpdateFailure.checksum => l10n.updateChecksumError,
          }
        : switch (installFailure) {
            AppUpdateInstallFailure.permission => l10n.updatePermissionHint,
            AppUpdateInstallFailure.signature => l10n.updateSignatureError,
            AppUpdateInstallFailure.invalidApk => l10n.updateInvalidApk,
            AppUpdateInstallFailure.failed => l10n.updateInstallError,
            null => null,
          };

    return AppSection(
      title: l10n.updateSection,
      children: [
        ListTile(
          leading: const Icon(Icons.system_update_outlined),
          title: Text(l10n.updateCheckAction),
          subtitle: Text(l10n.updateSource),
          trailing: const Icon(Icons.refresh),
          enabled: !controller.busy,
          onTap: controller.busy ? null : controller.check,
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.compact),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: status != AppUpdateStatus.downloading,
                child: Text(message, style: theme.textTheme.bodyLarge),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          installFailure == AppUpdateInstallFailure.permission
                          ? colors.onSurfaceVariant
                          : colors.error,
                    ),
                  ),
                ),
              ],
              if (status == AppUpdateStatus.checking ||
                  status == AppUpdateStatus.downloading) ...[
                const SizedBox(height: AppSpacing.compact),
                LinearProgressIndicator(
                  value: status == AppUpdateStatus.downloading
                      ? controller.progress
                      : null,
                  semanticsLabel: message,
                ),
              ],
              if (status == AppUpdateStatus.available) ...[
                const SizedBox(height: AppSpacing.sm),
                if (controller.canInstall && release!.apk != null)
                  FilledButton.icon(
                    onPressed: controller.download,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(
                      l10n.updateDownloadAction(
                        decimal.format(release.apk!.sizeBytes / (1024 * 1024)),
                      ),
                    ),
                  )
                else
                  Text(
                    controller.canInstall
                        ? l10n.updateNoApk
                        : l10n.updateExternalHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
              if (status == AppUpdateStatus.ready) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.updateInstallHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.compact),
                FilledButton.icon(
                  onPressed: controller.install,
                  icon: const Icon(Icons.install_mobile_outlined),
                  label: Text(l10n.updateInstallAction),
                ),
              ],
              if (release != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _openRelease(release.releaseUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.updateReleaseAction),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
