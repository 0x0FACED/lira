import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(40),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ReadingMode>(
            segments: [
              ButtonSegment(
                value: ReadingMode.vertical,
                icon: const Icon(Icons.swap_vert, size: 18),
                label: Text(l10n.readerVertical),
              ),
              ButtonSegment(
                value: ReadingMode.horizontal,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(l10n.readerHorizontal),
              ),
            ],
            selected: {settings.readingMode},
            onSelectionChanged: (s) => notifier.updateSettings(
              settings.copyWith(readingMode: s.first),
            ),
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 14),
          if (settings.readingMode == ReadingMode.horizontal && !isPhone) ...[
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              secondary: const Icon(Icons.chrome_reader_mode_rounded, size: 18),
              title: Text(
                l10n.readerTwoPageSpread,
                style: theme.textTheme.bodyMedium,
              ),
              value: settings.enableDualPageSpread,
              onChanged: (value) => notifier.updateSettings(
                settings.copyWith(enableDualPageSpread: value),
              ),
            ),
            const SizedBox(height: 8),
          ],
          DropdownButtonFormField<String>(
            key: ValueKey(settings.fontFamily),
            initialValue: settings.fontFamily,
            isExpanded: true,
            menuMaxHeight: 280,
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.readerFont,
              prefixIcon: const Icon(Icons.font_download_outlined, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: _readerFontOptions
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option.family,
                    child: Text(
                      option.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: option.family, fontSize: 14),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              notifier.updateSettings(settings.copyWith(fontFamily: value));
            },
          ),
          const SizedBox(height: 10),
          _sliderRow(
            icon: Icons.text_fields,
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
            value: _brightness,
            min: 0.2,
            max: 1.0,
            label: '${(_brightness * 100).round()}%',
            onChanged: (v) => setState(() => _brightness = v),
            onChangeEnd: (v) =>
                notifier.updateSettings(settings.copyWith(brightness: v)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _colorDot(theme, 0xFF121212, settings, notifier),
              _colorDot(theme, 0xFF1E1E1E, settings, notifier),
              _colorDot(theme, 0xFF2C2C2C, settings, notifier),
              _colorDot(
                theme,
                0xFFF5F5F5,
                settings,
                notifier,
                border: Colors.grey,
              ),
              _colorDot(theme, 0xFFFFF8E1, settings, notifier),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sliderRow({
    required IconData icon,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String label,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.right,
            ),
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
    Color? border,
  }) {
    final selected = settings.backgroundColor == colorValue;
    final color = Color(colorValue);
    final borderColor = _resolveSwatchBorderColor(
      theme: theme,
      swatchColor: color,
      selected: selected,
      explicitBorder: border,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => notifier.updateSettings(
          settings.copyWith(backgroundColor: colorValue),
        ),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: selected ? 2.5 : 1.5),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(60),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  size: 16,
                  color: color.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }

  Color _resolveSwatchBorderColor({
    required ThemeData theme,
    required Color swatchColor,
    required bool selected,
    Color? explicitBorder,
  }) {
    if (selected) return theme.colorScheme.primary;
    if (explicitBorder != null) return explicitBorder;

    final surfaceLuminance = theme.colorScheme.surface.computeLuminance();
    final swatchLuminance = swatchColor.computeLuminance();
    final luminanceDelta = (surfaceLuminance - swatchLuminance).abs();

    if (luminanceDelta < 0.08) {
      return theme.colorScheme.outline.withAlpha(220);
    }

    return swatchLuminance < 0.35 ? Colors.white24 : Colors.black12;
  }
}

class _ReaderFontOption {
  final String label;
  final String family;

  const _ReaderFontOption({required this.label, required this.family});
}
