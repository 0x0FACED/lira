import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_provider.dart';

class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reader Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => notifier.resetSettings(),
                tooltip: 'Reset to default',
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Font Family
          Text('Font Family', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FontChip(
                  label: 'Sans Serif',
                  fontFamily: 'sans-serif',
                  isSelected: settings.fontFamily == 'sans-serif',
                  onTap: () => notifier.updateSettings(settings.copyWith(fontFamily: 'sans-serif')),
                ),
                _FontChip(
                  label: 'Serif',
                  fontFamily: 'serif',
                  isSelected: settings.fontFamily == 'serif',
                  onTap: () => notifier.updateSettings(settings.copyWith(fontFamily: 'serif')),
                ),
                _FontChip(
                  label: 'Monospace',
                  fontFamily: 'monospace',
                  isSelected: settings.fontFamily == 'monospace',
                  onTap: () => notifier.updateSettings(settings.copyWith(fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Font Size
          Row(
            children: [
              const Icon(Icons.text_fields, size: 16),
              Expanded(
                child: Slider(
                  value: settings.fontSize,
                  min: 12,
                  max: 32,
                  divisions: 10,
                  label: settings.fontSize.round().toString(),
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(fontSize: val)),
                ),
              ),
              const Icon(Icons.text_fields, size: 24),
            ],
          ),
          
          // Line Height
          Row(
            children: [
              const Icon(Icons.format_line_spacing),
              const SizedBox(width: 16),
              Expanded(
                child: Slider(
                  value: settings.lineHeight,
                  min: 1.0,
                  max: 2.5,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(lineHeight: val)),
                ),
              ),
            ],
          ),

          // Horizontal Padding
          Row(
            children: [
              const Icon(Icons.unfold_more_rounded, size: 20), // Placeholder for padding icon
              const SizedBox(width: 16),
              Expanded(
                child: Slider(
                  value: settings.horizontalPadding,
                  min: 8,
                  max: 64,
                  onChanged: (val) => notifier.updateSettings(settings.copyWith(horizontalPadding: val)),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Background Color
          Text('Background', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ColorCircle(
                color: const Color(0xFF121212),
                isSelected: settings.backgroundColor == 0xFF121212,
                onTap: () => notifier.updateSettings(settings.copyWith(backgroundColor: 0xFF121212)),
              ),
              _ColorCircle(
                color: const Color(0xFF1E1E1E),
                isSelected: settings.backgroundColor == 0xFF1E1E1E,
                onTap: () => notifier.updateSettings(settings.copyWith(backgroundColor: 0xFF1E1E1E)),
              ),
              _ColorCircle(
                color: const Color(0xFF2C2C2C),
                isSelected: settings.backgroundColor == 0xFF2C2C2C,
                onTap: () => notifier.updateSettings(settings.copyWith(backgroundColor: 0xFF2C2C2C)),
              ),
              _ColorCircle(
                color: const Color(0xFFF5F5F5),
                isSelected: settings.backgroundColor == 0xFFF5F5F5,
                borderColor: Colors.grey,
                onTap: () => notifier.updateSettings(settings.copyWith(backgroundColor: 0xFFF5F5F5)),
              ),
              _ColorCircle(
                color: const Color(0xFFFFF8E1),
                isSelected: settings.backgroundColor == 0xFFFFF8E1,
                onTap: () => notifier.updateSettings(settings.copyWith(backgroundColor: 0xFFFFF8E1)),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FontChip extends StatelessWidget {
  final String label;
  final String fontFamily;
  final bool isSelected;
  final VoidCallback onTap;

  const _FontChip({
    required this.label,
    required this.fontFamily,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontFamily: fontFamily)),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? borderColor;

  const _ColorCircle({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : (borderColor ?? Colors.transparent),
            width: 3,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withAlpha(80),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }
}
