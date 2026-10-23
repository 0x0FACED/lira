import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.color,
    this.radius = AppRadius.lg,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Padding(padding: padding, child: child);
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null && onLongPress == null
            ? content
            : InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            ...actions,
          ],
        ],
      ),
    );
  }
}

class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.compact,
            ),
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.compact),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          AppSurface(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Icon(icon, size: 32, color: iconColor ?? colors.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.compact),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color:
            color?.withValues(alpha: 0.1) ?? theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onSearch,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value.text.isNotEmpty)
                IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                    onClear?.call();
                  },
                ),
              if (onSearch != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).searchFieldLabel,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  onPressed: value.text.trim().isEmpty ? null : onSearch,
                ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}

class AppStateTransition extends StatelessWidget {
  const AppStateTransition({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context),
    reverseDuration: AppMotion.duration(context, AppMotion.fast),
    switchInCurve: AppMotion.curve,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: _layout,
    child: child,
  );

  static Widget _layout(Widget? current, List<Widget> previous) => Stack(
    alignment: Alignment.center,
    children: [
      for (final child in previous)
        ExcludeFocus(child: IgnorePointer(child: child)),
      if (current != null) current,
    ],
  );
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  animationStyle: AppMotion.dialogStyle(context),
  builder: builder,
);

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: isScrollControlled,
  showDragHandle: true,
  sheetAnimationStyle: AppMotion.sheetStyle(context),
  builder: builder,
);
