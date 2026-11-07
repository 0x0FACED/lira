import 'package:epub_engine/epub_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../data/reader_font_catalog.dart';
import '../data/reader_theme_catalog.dart';
import '../data/settings_provider.dart';

class SettingsPanel extends ConsumerStatefulWidget {
  const SettingsPanel({super.key});

  @override
  ConsumerState<SettingsPanel> createState() => _SettingsPanelState();
}

enum _SettingsCategory { typography, layout, colors }

class _SettingsPanelState extends ConsumerState<SettingsPanel> {
  _SettingsCategory _category = _SettingsCategory.typography;

  void _updateSettings(ReaderSettings Function(ReaderSettings) update) {
    ref
        .read(readerSettingsProvider.notifier)
        .updateSettings(update(ref.read(readerSettingsProvider)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final isPhone =
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) &&
        media.size.shortestSide < 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final category in _SettingsCategory.values) ...[
                        if (category != _SettingsCategory.values.first)
                          const SizedBox(width: AppSpacing.sm),
                        Semantics(
                          selected: _category == category,
                          child: TextButton(
                            onPressed: () =>
                                setState(() => _category = category),
                            child: Text(
                              _categoryLabel(category, l10n),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: _category == category
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Keep floating labels inside the scrolling viewport.
                SizedBox(
                  height: AppSpacing.sm + media.textScaler.scale(AppSpacing.md),
                ),
                switch (_category) {
                  _SettingsCategory.typography => _typographySettings(
                    settings,
                    l10n,
                  ),
                  _SettingsCategory.layout => _layoutSettings(
                    settings,
                    l10n,
                    isPhone: isPhone,
                  ),
                  _SettingsCategory.colors => _colorSettings(settings, l10n),
                },
              ],
            ),
          ),
        );
        // The workspace supplies one scroll view for its header and controls.
        return constraints.hasBoundedHeight
            ? SingleChildScrollView(child: content)
            : content;
      },
    );
  }

  String _categoryLabel(_SettingsCategory category, AppLocalizations l10n) =>
      switch (category) {
        _SettingsCategory.typography => l10n.readerTypography,
        _SettingsCategory.layout => l10n.readerLayout,
        _SettingsCategory.colors => l10n.readerColors,
      };

  Widget _typographySettings(ReaderSettings settings, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final decimal = NumberFormat('0.##', l10n.localeName);
    final fontOptions = [
      _ReaderFontOption(label: l10n.readerSansSerif, family: 'sans-serif'),
      _ReaderFontOption(label: l10n.readerSerif, family: 'serif'),
      for (final font in bundledReaderFonts)
        _ReaderFontOption(label: font.family, family: font.family),
      if (settings.fontFamily == 'Georgia' ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows)
        const _ReaderFontOption(label: 'Georgia', family: 'Georgia'),
      _ReaderFontOption(label: l10n.readerMonospace, family: 'monospace'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(settings.fontFamily),
          initialValue: settings.fontFamily,
          isExpanded: true,
          menuMaxHeight: 280,
          decoration: InputDecoration(
            labelText: l10n.readerFont,
            prefixIcon: const Icon(Icons.font_download_outlined, size: 20),
          ),
          items: fontOptions
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option.family,
                  child: Text(
                    option.label,
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
            _updateSettings((current) => current.copyWith(fontFamily: value));
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _sliderRow(
          icon: Icons.text_fields,
          semanticsLabel: l10n.readerFontSize,
          value: settings.fontSize,
          min: 12,
          max: 32,
          divisions: 10,
          label: '${settings.fontSize.round()}',
          onChanged: (value) =>
              _updateSettings((current) => current.copyWith(fontSize: value)),
        ),
        _sliderRow(
          icon: Icons.format_bold,
          semanticsLabel: l10n.readerFontWeight,
          value: settings.fontWeight.toDouble(),
          min: 100,
          max: 900,
          divisions: 8,
          label: '${settings.fontWeight}',
          onChanged: (value) => _updateSettings(
            (current) => current.copyWith(fontWeight: value.round()),
          ),
        ),
        _sliderRow(
          icon: Icons.format_line_spacing,
          semanticsLabel: l10n.readerLineHeight,
          value: settings.lineHeight,
          min: 1,
          max: 2.5,
          label: '${decimal.format(settings.lineHeight)}×',
          onChanged: (value) =>
              _updateSettings((current) => current.copyWith(lineHeight: value)),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.readerHyphenation),
          subtitle: Text(l10n.readerHyphenationHint),
          value: settings.hyphenation,
          onChanged: (value) => _updateSettings(
            (current) => current.copyWith(hyphenation: value),
          ),
        ),
      ],
    );
  }

  Widget _layoutSettings(
    ReaderSettings settings,
    AppLocalizations l10n, {
    required bool isPhone,
  }) {
    final decimal = NumberFormat('0.##', l10n.localeName);
    final maxPadding = isPhone ? 64.0 : 240.0;
    final displayedPadding = settings.horizontalPadding
        .clamp(8.0, maxPadding)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.readerReadingMode,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Semantics(
              selected: settings.readingMode == ReadingMode.vertical,
              child: TextButton.icon(
                icon: const Icon(Icons.swap_vert, size: 18),
                label: Text(
                  l10n.readerVertical,
                  style: TextStyle(
                    color: settings.readingMode == ReadingMode.vertical
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                onPressed: () => _updateSettings(
                  (current) =>
                      current.copyWith(readingMode: ReadingMode.vertical),
                ),
              ),
            ),
            Semantics(
              selected: settings.readingMode == ReadingMode.horizontal,
              child: TextButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(
                  l10n.readerHorizontal,
                  style: TextStyle(
                    color: settings.readingMode == ReadingMode.horizontal
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                onPressed: () => _updateSettings(
                  (current) =>
                      current.copyWith(readingMode: ReadingMode.horizontal),
                ),
              ),
            ),
          ],
        ),
        if (settings.readingMode == ReadingMode.horizontal && !isPhone)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.chrome_reader_mode_rounded, size: 20),
            title: Text(l10n.readerTwoPageSpread),
            value: settings.enableDualPageSpread,
            onChanged: (value) => _updateSettings(
              (current) => current.copyWith(enableDualPageSpread: value),
            ),
          ),
        const SizedBox(height: AppSpacing.compact),
        DropdownButtonFormField<ReaderTextAlign>(
          key: ValueKey(settings.textAlign),
          initialValue: settings.textAlign,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.readerTextAlignment,
            prefixIcon: const Icon(Icons.format_align_left, size: 20),
          ),
          items: [
            DropdownMenuItem(
              value: ReaderTextAlign.original,
              child: Text(l10n.readerAlignOriginal),
            ),
            DropdownMenuItem(
              value: ReaderTextAlign.left,
              child: Text(l10n.readerAlignLeft),
            ),
            DropdownMenuItem(
              value: ReaderTextAlign.justify,
              child: Text(l10n.readerAlignJustify),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            _updateSettings((current) => current.copyWith(textAlign: value));
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _sliderRow(
          icon: Icons.horizontal_distribute,
          semanticsLabel: l10n.readerPageMargins,
          value: displayedPadding,
          min: 8,
          max: maxPadding,
          label: '${displayedPadding.round()}',
          onChanged: (value) => _updateSettings(
            (current) => current.copyWith(horizontalPadding: value),
          ),
        ),
        _sliderRow(
          icon: Icons.format_indent_increase,
          semanticsLabel: l10n.readerParagraphIndent,
          value: settings.paragraphIndent,
          min: 0,
          max: 3,
          divisions: 12,
          label:
              '${decimal.format(settings.paragraphIndent)} ${l10n.readerEmUnit}',
          onChanged: (value) => _updateSettings(
            (current) => current.copyWith(paragraphIndent: value),
          ),
        ),
        _sliderRow(
          icon: Icons.space_bar,
          semanticsLabel: l10n.readerParagraphSpacing,
          value: settings.paragraphSpacing,
          min: 0,
          max: 2,
          divisions: 8,
          label:
              '${decimal.format(settings.paragraphSpacing)} ${l10n.readerEmUnit}',
          onChanged: (value) => _updateSettings(
            (current) => current.copyWith(paragraphSpacing: value),
          ),
        ),
      ],
    );
  }

  Widget _colorSettings(ReaderSettings settings, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.readerPalette, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final columns = constraints.maxWidth >= 480 * textScale ? 2 : 1;
            final width =
                (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final palette in readerThemePalettes)
                  SizedBox(
                    width: width,
                    child: _paletteButton(palette, settings, l10n),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.readerPaletteHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.compact),
        _colorEditor(
          title: l10n.readerBackground,
          color: settings.backgroundColor,
          isText: false,
          l10n: l10n,
        ),
        _colorEditor(
          title: l10n.readerTextColor,
          color:
              settings.textColor ??
              settings.copyWith(textContrast: 1).resolvedTextColor.toARGB32(),
          isText: true,
          l10n: l10n,
        ),
        const SizedBox(height: AppSpacing.sm),
        _sliderRow(
          icon: Icons.contrast,
          semanticsLabel: l10n.readerTextContrast,
          value: settings.textContrast,
          min: 0,
          max: 1,
          label: '${(settings.textContrast * 100).round()}%',
          onChanged: (value) => _updateSettings(
            (current) => current.copyWith(textContrast: value),
          ),
        ),
        Text(l10n.readerTextContrastHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        _sliderRow(
          icon: Icons.brightness_4_outlined,
          semanticsLabel: l10n.readerAdditionalDimming,
          value: 1 - settings.brightness,
          min: 0,
          max: 0.8,
          label: '${((1 - settings.brightness) * 100).round()}%',
          onChanged: (value) => _updateSettings(
            (current) => current.copyWith(brightness: 1 - value),
          ),
        ),
        Text(
          l10n.readerAdditionalDimmingHint,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  String _paletteLabel(ReaderPaletteKind kind, AppLocalizations l10n) =>
      switch (kind) {
        ReaderPaletteKind.day => l10n.readerPaletteDay,
        ReaderPaletteKind.paper => l10n.readerPalettePaper,
        ReaderPaletteKind.dark => l10n.readerPaletteDark,
        ReaderPaletteKind.evening => l10n.readerPaletteEvening,
      };

  Widget _paletteButton(
    ReaderThemePalette palette,
    ReaderSettings settings,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final selected =
        settings.backgroundColor == palette.backgroundColor &&
        settings.textColor == palette.textColor &&
        settings.linkColor == palette.linkColor &&
        settings.selectionColor == palette.selectionColor &&
        settings.textContrast == 1;
    final textColor = Color(palette.textColor);
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed: () => _updateSettings(
          (current) => current.copyWith(
            backgroundColor: palette.backgroundColor,
            textColor: palette.textColor,
            linkColor: palette.linkColor,
            selectionColor: palette.selectionColor,
            textContrast: 1,
          ),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                alignment: Alignment.center,
                width: AppSpacing.xl,
                height: AppSpacing.xl,
                color: Color(palette.backgroundColor),
                child: Text(
                  'Aa',
                  style: TextStyle(fontSize: 20, color: textColor),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(_paletteLabel(palette.kind, l10n))),
            const SizedBox(width: AppSpacing.xs),
            SizedBox(
              width: 18,
              child: selected
                  ? Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.primary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorEditor({
    required String title,
    required int color,
    required bool isText,
    required AppLocalizations l10n,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            TextButton.icon(
              onPressed: () => _editColor(isText: isText),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Semantics(
                label: '${l10n.readerEditColor}: $title',
                child: Text('#${_rgbHex(color)}'),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final palette in readerThemePalettes)
              _colorDot(
                colorValue: isText
                    ? palette.textColor
                    : palette.backgroundColor,
                selectedColor: color,
                label: '$title: ${_paletteLabel(palette.kind, l10n)}',
                onSelected: (value) => _updateSettings(
                  (current) => isText
                      ? current.copyWith(textColor: value)
                      : current.copyWith(backgroundColor: value),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _rgbHex(int color) =>
      (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  Future<void> _editColor({required bool isText}) async {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.read(readerSettingsProvider);
    final color = isText
        ? settings.textColor ??
              settings.copyWith(textContrast: 1).resolvedTextColor.toARGB32()
        : settings.backgroundColor;
    var draft = _rgbHex(color);
    final formKey = GlobalKey<FormState>();
    final result = await showAppDialog<int>(
      context: context,
      builder: (dialogContext) {
        void saveColor() {
          if (!formKey.currentState!.validate()) return;
          final hex = draft.trim().replaceFirst('#', '');
          Navigator.of(
            dialogContext,
          ).pop(0xFF000000 | int.parse(hex, radix: 16));
        }

        return AlertDialog(
          title: Text(isText ? l10n.readerTextColor : l10n.readerBackground),
          content: Form(
            key: formKey,
            child: TextFormField(
              initialValue: draft,
              onChanged: (value) => draft = value,
              autofocus: true,
              maxLength: 7,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.readerHexColor,
                hintText: '#RRGGBB',
              ),
              validator: (value) =>
                  RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(value?.trim() ?? '')
                  ? null
                  : l10n.readerHexColorError,
              onFieldSubmitted: (_) => saveColor(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(onPressed: saveColor, child: Text(l10n.save)),
          ],
        );
      },
    );
    if (!mounted || result == null) return;
    _updateSettings(
      (current) => isText
          ? current.copyWith(textColor: result)
          : current.copyWith(backgroundColor: result),
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
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(semanticsLabel, style: theme.textTheme.labelLarge),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppLayout.minTouchTarget,
          ),
          child: Semantics(
            label: semanticsLabel,
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              label: label,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _colorDot({
    required int colorValue,
    required int selectedColor,
    required String label,
    required ValueChanged<int> onSelected,
  }) {
    final theme = Theme.of(context);
    final selected = selectedColor == colorValue;
    final color = Color(colorValue);
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: SizedBox.square(
        dimension: AppLayout.minTouchTarget,
        child: IconButton(
          onPressed: () => onSelected(colorValue),
          icon: Center(
            child: Container(
              width: AppSpacing.xl,
              height: AppSpacing.xl,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outline),
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
    );
  }
}

class _ReaderFontOption {
  final String label;
  final String family;

  const _ReaderFontOption({required this.label, required this.family});
}
