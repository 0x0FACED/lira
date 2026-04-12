import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epub_engine/epub_engine.dart';
import '../../../l10n/app_localizations.dart';
import '../data/settings_provider.dart';

class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withAlpha(40),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Reading Mode toggle
          SegmentedButton<ReadingMode>(
            segments: const [
              ButtonSegment(
                value: ReadingMode.vertical,
                icon: Icon(Icons.swap_vert, size: 18),
                label: Text('Vertical'),
              ),
              ButtonSegment(
                value: ReadingMode.horizontal,
                icon: Icon(Icons.swap_horiz, size: 18),
                label: Text('Horizontal'),
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

          if (settings.readingMode == ReadingMode.horizontal) ...[
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

          // Font family chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _fontChip(
                  theme,
                  'Sans Serif',
                  'sans-serif',
                  settings,
                  notifier,
                ),
                _fontChip(theme, 'Serif', 'serif', settings, notifier),
                _fontChip(theme, 'Mono', 'monospace', settings, notifier),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Font size
          _sliderRow(
            icon: Icons.text_fields,
            value: settings.fontSize,
            min: 12,
            max: 32,
            divisions: 10,
            label: '${settings.fontSize.round()}',
            onChanged: (v) =>
                notifier.updateSettings(settings.copyWith(fontSize: v)),
          ),

          // Line height
          _sliderRow(
            icon: Icons.format_line_spacing,
            value: settings.lineHeight,
            min: 1.0,
            max: 2.5,
            label: settings.lineHeight.toStringAsFixed(1),
            onChanged: (v) =>
                notifier.updateSettings(settings.copyWith(lineHeight: v)),
          ),

          // Horizontal padding
          _sliderRow(
            icon: Icons.horizontal_distribute,
            value: settings.horizontalPadding,
            min: 8,
            max: 64,
            label: '${settings.horizontalPadding.round()}',
            onChanged: (v) => notifier.updateSettings(
              settings.copyWith(horizontalPadding: v),
            ),
          ),

          // Brightness
          _sliderRow(
            icon: Icons.brightness_6_rounded,
            value: settings.brightness,
            min: 0.2,
            max: 1.0,
            label: '${(settings.brightness * 100).round()}%',
            onChanged: (v) =>
                notifier.updateSettings(settings.copyWith(brightness: v)),
          ),

          const SizedBox(height: 8),

          // Background colors
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

  Widget _fontChip(
    ThemeData theme,
    String label,
    String family,
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    final selected = settings.fontFamily == family;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ChoiceChip(
          label: Text(
            label,
            style: TextStyle(fontFamily: family, fontSize: 12),
          ),
          selected: selected,
          onSelected: (_) =>
              notifier.updateSettings(settings.copyWith(fontFamily: family)),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
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
              ),
            ),
          ),
          SizedBox(
            width: 36,
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
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : (border ?? Colors.transparent),
              width: selected ? 2.5 : 1,
            ),
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
}
