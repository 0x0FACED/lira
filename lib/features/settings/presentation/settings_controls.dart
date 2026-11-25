import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_components.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      color: colors.surfaceContainerLow,
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      child: ListTileTheme.merge(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        // The card clips the outer corners; interior rows meet the divider.
        shape: const Border(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                  color: colors.outlineVariant,
                ),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.contentPadding,
    this.selected = false,
    required this.onTap,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? contentPadding;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _SettingsRowTheme(
    child: ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      contentPadding: contentPadding,
      selected: selected,
      enabled: onTap != null,
      onTap: onTap,
    ),
  );
}

class SettingsSwitchRow extends StatefulWidget {
  const SettingsSwitchRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<SettingsSwitchRow> createState() => _SettingsSwitchRowState();
}

class _SettingsSwitchRowState extends State<SettingsSwitchRow> {
  int? _pointer;
  double _downY = 0;

  void _handleDown(PointerDownEvent event) {
    if (widget.onChanged == null ||
        event.buttons != kPrimaryButton ||
        _pointer != null) {
      return;
    }
    setState(() {
      _pointer = event.pointer;
      _downY = event.position.dy;
    });
  }

  void _handleEnd(PointerEvent event) {
    if (event.pointer == _pointer) setState(() => _pointer = null);
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    final switchPressed = onChanged != null && _pointer != null;
    return _SettingsRowTheme(
      switchPressed: switchPressed,
      child: MergeSemantics(
        child: ListTile(
          leading: widget.leading,
          title: widget.title,
          subtitle: widget.subtitle,
          enabled: onChanged != null,
          internalAddSemanticForOnTap: false,
          onTap: onChanged == null ? null : () => onChanged(!widget.value),
          tileColor: switchPressed ? _pressedColor(Theme.of(context)) : null,
          trailing: Listener(
            // The switch can win the gesture arena before ListTile sees a tap.
            // Mirror its pointer press without competing with native dragging.
            onPointerDown: _handleDown,
            onPointerMove: (event) {
              if ((event.position.dy - _downY).abs() > kTouchSlop) {
                _handleEnd(event);
              }
            },
            onPointerUp: _handleEnd,
            onPointerCancel: _handleEnd,
            child: ExcludeFocus(
              child: Switch(
                value: widget.value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _pressedColor(ThemeData theme) =>
    theme.colorScheme.onSurface.withValues(alpha: 0.12);

class _SettingsRowTheme extends StatelessWidget {
  const _SettingsRowTheme({required this.child, this.switchPressed = false});

  final Widget child;
  final bool switchPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    return Theme(
      data: theme.copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: switchPressed
            ? Colors.transparent
            : _pressedColor(theme),
        hoverColor: switchPressed
            ? Colors.transparent
            : ink.withValues(alpha: 0.07),
        focusColor: ink.withValues(alpha: 0.18),
      ),
      child: child,
    );
  }
}
