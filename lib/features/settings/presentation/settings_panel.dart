import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/settings_provider.dart';

const _readerFontOptions = [
  _ReaderFontOption(label: 'Sans Serif', family: 'sans-serif'),
  _ReaderFontOption(label: 'Serif', family: 'serif'),
  _ReaderFontOption(label: 'Roboto', family: 'Roboto'),
  _ReaderFontOption(label: 'Georgia', family: 'Georgia'),
  _ReaderFontOption(label: 'Monospace', family: 'monospace'),
];

class SettingsPanel extends ConsumerStatefulWidget {
  const SettingsPanel({super.key});

  @override
  ConsumerState<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends ConsumerState<SettingsPanel> {
  late double _fontSize;
  late double _lineHeight;
  late double _horizontalPadding;
  late double _brightness;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(readerSettingsProvider);
    _fontSize = settings.fontSize;
    _lineHeight = settings.lineHeight;
    _horizontalPadding = settings.horizontalPadding;
    _brightness = settings.brightness;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final isPhone =
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) &&
        media.size.shortestSide < 600;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.readerSettings, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.swap_vert, size: 18),
                      label: Text(l10n.readerVertical),
                      selected: settings.readingMode == ReadingMode.vertical,
                      onSelected: (_) => notifier.updateSettings(
                        settings.copyWith(readingMode: ReadingMode.vertical),
                      ),
                    ),
                    ChoiceChip(
                      avatar: const Icon(Icons.swap_horiz, size: 18),
                      label: Text(l10n.readerHorizontal),
                      selected: settings.readingMode == ReadingMode.horizontal,
                      onSelected: (_) => notifier.updateSettings(
                        settings.copyWith(readingMode: ReadingMode.horizontal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (settings.readingMode == ReadingMode.horizontal &&
                    !isPhone) ...[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(
                      Icons.chrome_reader_mode_rounded,
                      size: 20,
                    ),
                    title: Text(
                      l10n.readerTwoPageSpread,
                      style: theme.textTheme.bodyMedium,
                    ),
                    value: settings.enableDualPageSpread,
                    onChanged: (value) => notifier.updateSettings(
                      settings.copyWith(enableDualPageSpread: value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                DropdownButtonFormField<String>(
                  key: ValueKey(settings.fontFamily),
                  initialValue: settings.fontFamily,
                  isExpanded: true,
                  menuMaxHeight: 280,
                  decoration: InputDecoration(
                    labelText: l10n.readerFont,
                    prefixIcon: const Icon(
                      Icons.font_download_outlined,
                      size: 20,
                    ),
                  ),
                  items: _readerFontOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.family,
                          child: Text(
                            switch (option.family) {
                              'sans-serif' => l10n.readerSansSerif,
                              'serif' => l10n.readerSerif,
                              'monospace' => l10n.readerMonospace,
                              _ => option.label,
                            },
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: option.family,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    notifier.updateSettings(
                      settings.copyWith(fontFamily: value),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.compact),
                _sliderRow(
                  icon: Icons.text_fields,
                  semanticsLabel: l10n.readerFontSize,
                  value: _fontSize,
                  min: 12,
                  max: 32,
                  divisions: 10,
                  label: '${_fontSize.round()}',
                  onChanged: (v) => setState(() => _fontSize = v),
                  onChangeEnd: (v) =>
                      notifier.updateSettings(settings.copyWith(fontSize: v)),
                ),
                _sliderRow(
                  icon: Icons.format_line_spacing,
                  semanticsLabel: l10n.readerLineHeight,
                  value: _lineHeight,
                  min: 1.0,
                  max: 2.5,
                  label: _lineHeight.toStringAsFixed(1),
                  onChanged: (v) => setState(() => _lineHeight = v),
                  onChangeEnd: (v) =>
                      notifier.updateSettings(settings.copyWith(lineHeight: v)),
                ),
                _sliderRow(
                  icon: Icons.horizontal_distribute,
                  semanticsLabel: l10n.readerPageMargins,
                  value: _horizontalPadding,
                  min: 8,
                  max: 64,
                  label: '${_horizontalPadding.round()}',
                  onChanged: (v) => setState(() => _horizontalPadding = v),
                  onChangeEnd: (v) => notifier.updateSettings(
                    settings.copyWith(horizontalPadding: v),
                  ),
                ),
                _sliderRow(
                  icon: Icons.brightness_6_rounded,
                  semanticsLabel: l10n.readerBrightness,
                  value: _brightness,
                  min: 0.2,
                  max: 1.0,
                  label: '${(_brightness * 100).round()}%',
                  onChanged: (v) => setState(() => _brightness = v),
                  onChangeEnd: (v) =>
                      notifier.updateSettings(settings.copyWith(brightness: v)),
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.readerBackground,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.compact),
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _colorDot(
                      theme,
                      AppTheme.paperColor.toARGB32(),
                      settings,
                      notifier,
                      label: l10n.readerPaper,
                    ),
                    _colorDot(
                      theme,
                      0xFF121212,
                      settings,
                      notifier,
                      label: l10n.readerNight,
                    ),
                    _colorDot(
                      theme,
                      0xFF1E1E1E,
                      settings,
                      notifier,
                      label: l10n.readerCharcoal,
                    ),
                    _colorDot(
                      theme,
                      0xFF2C2C2C,
                      settings,
                      notifier,
                      label: l10n.readerGraphite,
                    ),
                    _colorDot(
                      theme,
                      0xFFF5F5F5,
                      settings,
                      notifier,
                      label: l10n.readerWhite,
                    ),
                    _colorDot(
                      theme,
                      0xFFFFF8E1,
                      settings,
                      notifier,
                      label: l10n.readerSepia,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sliderRow({
    required IconData icon,
    required String semanticsLabel,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String label,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppLayout.minTouchTarget),
      child: Row(
        children: [
          Tooltip(
            message: semanticsLabel,
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Semantics(
              label: semanticsLabel,
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                label: label,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _colorDot(
    ThemeData theme,
    int colorValue,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier, {
    required String label,
  }) {
    final selected = settings.backgroundColor == colorValue;
    final color = Color(colorValue);
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return Tooltip(
      message: label,
      child: Semantics(
        selected: selected,
        button: true,
        child: SizedBox.square(
          dimension: AppLayout.minTouchTarget,
          child: InkResponse(
            radius: AppSpacing.lg,
            onTap: () => notifier.updateSettings(
              settings.copyWith(backgroundColor: colorValue),
            ),
            child: Center(
              child: Container(
                width: AppSpacing.xl,
                height: AppSpacing.xl,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: borderColor,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderFontOption {
  final String label;
  final String family;

  const _ReaderFontOption({required this.label, required this.family});
}
