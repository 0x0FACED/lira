import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/providers/book_organization_provider.dart'
    show normalizeBookLabels;

/// Edits a mount-time snapshot and publishes drafts without persisting them.
class InlineBookLabels extends StatefulWidget {
  const InlineBookLabels({
    super.key,
    required this.title,
    required this.addLabelTooltip,
    required this.initialLabels,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String addLabelTooltip;
  final List<String> initialLabels;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  @override
  State<InlineBookLabels> createState() => _InlineBookLabelsState();
}

class _InlineBookLabelsState extends State<InlineBookLabels> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _editorTextPainter = TextPainter(maxLines: 1);
  late final List<String> _labels;
  bool _editing = false;
  int? _editingIndex;

  @override
  void initState() {
    super.initState();
    _labels = normalizeBookLabels(widget.initialLabels).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _editorTextPainter.dispose();
    super.dispose();
  }

  void _publish() {
    final value = _controller.text;
    widget.onChanged(
      normalizeBookLabels([
        for (var index = 0; index < _labels.length; index++)
          if (_editing && index == _editingIndex && value.trim().isNotEmpty)
            value
          else
            _labels[index],
        if (_editing && _editingIndex == null) value,
      ]),
    );
  }

  void _startEditing([int? index]) {
    if (!widget.enabled) return;
    final label = index == null ? null : _labels[index];
    _finishEditing();
    // Committing the previous draft may have merged a duplicate chip.
    final nextIndex = label == null
        ? null
        : _labels.indexWhere(
            (value) => value.toLowerCase() == label.toLowerCase(),
          );
    setState(() {
      _editing = true;
      _editingIndex = nextIndex;
      final text = nextIndex == null ? '' : _labels[nextIndex];
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled && _editing) _focusNode.requestFocus();
    });
  }

  void _finishEditing() {
    if (!_editing) return;
    final value = _controller.text;
    setState(() {
      final index = _editingIndex;
      if (value.trim().isNotEmpty) {
        if (index == null) {
          _labels.add(value);
        } else {
          _labels[index] = value;
        }
      }
      // An empty existing draft is cancelled, not an implicit deletion.
      final normalized = normalizeBookLabels(_labels);
      _labels
        ..clear()
        ..addAll(normalized);
      _editing = false;
      _editingIndex = null;
    });
    _focusNode.unfocus();
    _publish();
  }

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _editingIndex = null;
    });
    _focusNode.unfocus();
    _publish();
  }

  void _removeLabel(int index) {
    setState(() {
      _labels.removeAt(index);
      final editingIndex = _editingIndex;
      if (editingIndex != null && index < editingIndex) {
        _editingIndex = editingIndex - 1;
      }
    });
    _publish();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(widget.title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              key: const ValueKey('inline-label-add'),
              tooltip: widget.addLabelTooltip,
              onPressed: widget.enabled ? _startEditing : null,
              icon: Icon(
                Icons.add,
                size: 20,
                semanticLabel: widget.addLabelTooltip,
              ),
              constraints: const BoxConstraints(
                minWidth: AppLayout.minTouchTarget,
                minHeight: AppLayout.minTouchTarget,
              ),
            ),
          ],
        ),
        if (_labels.isNotEmpty || _editing) ...[
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var index = 0; index < _labels.length; index++)
                  if (_editing && _editingIndex == index)
                    _buildEditor(context, constraints.maxWidth)
                  else
                    _buildLabel(context, index, constraints.maxWidth),
                if (_editing && _editingIndex == null)
                  _buildEditor(context, constraints.maxWidth),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel(BuildContext context, int index, double maxWidth) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.sm);
    final label = _labels[index];
    final removeLabel =
        '${MaterialLocalizations.of(context).deleteButtonTooltip}: $label';
    return ConstrainedBox(
      key: ValueKey('inline-label-$index'),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InkWell(
                onTap: widget.enabled ? () => _startEditing(index) : null,
                borderRadius: radius,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: widget.enabled ? AppLayout.minTouchTarget : 0,
                    minHeight: widget.enabled ? AppLayout.minTouchTarget : 0,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: widget.enabled ? AppSpacing.sm : AppSpacing.xs,
                    ),
                    child: Align(
                      widthFactor: 1,
                      heightFactor: 1,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.enabled)
              IconButton(
                key: ValueKey('inline-label-remove-$index'),
                tooltip: removeLabel,
                onPressed: () => _removeLabel(index),
                icon: Icon(Icons.close, size: 18, semanticLabel: removeLabel),
                constraints: const BoxConstraints(
                  minWidth: AppLayout.minTouchTarget,
                  minHeight: AppLayout.minTouchTarget,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context, double maxWidth) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final textStyle =
        (theme.useMaterial3
                ? theme.textTheme.bodyLarge
                : theme.textTheme.titleMedium)!
            .merge(theme.textTheme.bodyMedium);
    final measuredText = _editorTextPainter.text;
    if (measuredText is! TextSpan ||
        measuredText.text != _controller.text ||
        measuredText.style != textStyle) {
      _editorTextPainter.text = TextSpan(
        text: _controller.text,
        style: textStyle,
      );
    }
    // TextPainter reuses its layout until text or inherited typography changes.
    _editorTextPainter
      ..textScaler = MediaQuery.textScalerOf(context)
      ..locale = Localizations.maybeLocaleOf(context)
      ..textDirection = Directionality.of(context)
      ..layout();
    const actionWidth = AppLayout.minTouchTarget;
    const minimumInlineWidth = AppLayout.minTouchTarget + actionWidth * 2;
    final availableWidth = maxWidth.clamp(0, 280).toDouble();
    final stackedActions = availableWidth < minimumInlineWidth;
    // Leave room for the caret as well as the field's horizontal padding.
    final fieldWidth =
        (_editorTextPainter.width.ceilToDouble() +
                AppSpacing.sm * 2 +
                AppSpacing.xs)
            .clamp(AppLayout.minTouchTarget, double.infinity)
            .toDouble();
    final editorWidth =
        (stackedActions
                ? fieldWidth.clamp(actionWidth * 2, double.infinity)
                : fieldWidth + actionWidth * 2)
            .clamp(0, availableWidth)
            .toDouble();
    final fieldHeight = (_editorTextPainter.height + AppSpacing.sm * 2)
        .clamp(AppLayout.minTouchTarget, double.infinity)
        .toDouble();
    final field = Semantics(
      label: widget.title,
      child: SizedBox(
        height: fieldHeight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.enabled ? _focusNode.requestFocus : null,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: TextField(
                key: const ValueKey('inline-label-editor'),
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: true,
                style: textStyle,
                textAlign: TextAlign.center,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                // The chip supplies the surface. Center the bare editable line
                // instead of inheriting the form decorator's baseline layout.
                decoration: null,
                onChanged: (_) {
                  setState(() {});
                  _publish();
                },
                onSubmitted: (_) => _finishEditing(),
              ),
            ),
          ),
        ),
      ),
    );
    final actions = [
      IconButton(
        key: const ValueKey('inline-label-confirm'),
        tooltip: l10n.save,
        onPressed: widget.enabled ? _finishEditing : null,
        icon: Icon(Icons.check, size: 18, semanticLabel: l10n.save),
        visualDensity: VisualDensity.standard,
        constraints: const BoxConstraints.tightFor(
          width: actionWidth,
          height: AppLayout.minTouchTarget,
        ),
      ),
      IconButton(
        key: const ValueKey('inline-label-cancel'),
        tooltip: l10n.cancel,
        onPressed: widget.enabled ? _cancelEditing : null,
        icon: Icon(Icons.close, size: 18, semanticLabel: l10n.cancel),
        visualDensity: VisualDensity.standard,
        constraints: const BoxConstraints.tightFor(
          width: actionWidth,
          height: AppLayout.minTouchTarget,
        ),
      ),
    ];
    return SizedBox(
      key: const ValueKey('inline-label-editor-chip'),
      width: editorWidth,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) {
          if (widget.enabled &&
              event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _cancelEditing();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: BorderSide(color: theme.colorScheme.outline),
          ),
          child: stackedActions
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field,
                    Wrap(alignment: WrapAlignment.end, children: actions),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: field),
                    ...actions,
                  ],
                ),
        ),
      ),
    );
  }
}
