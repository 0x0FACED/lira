import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/providers/book_organization_provider.dart'
    show normalizeBookLabels;

/// Displays and adds labels inline, either as live drafts or immediate commits.
class InlineBookLabels extends StatefulWidget {
  const InlineBookLabels({
    super.key,
    required this.title,
    required this.addLabelTooltip,
    required this.initialLabels,
    required this.enabled,
    this.readOnlyChips = false,
    this.normalizeLabels = normalizeBookLabels,
    this.onChanged,
    this.onCommit,
  });

  final String title;
  final String addLabelTooltip;
  final List<String> initialLabels;
  final bool enabled;
  final bool readOnlyChips;
  final List<String> Function(Iterable<Object?>) normalizeLabels;
  final ValueChanged<List<String>>? onChanged;
  final ValueChanged<List<String>>? onCommit;

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
    _labels = widget.normalizeLabels(widget.initialLabels).toList();
  }

  @override
  void didUpdateWidget(covariant InlineBookLabels oldWidget) {
    super.didUpdateWidget(oldWidget);
    final normalized = widget.normalizeLabels(widget.initialLabels);
    if (oldWidget.readOnlyChips != widget.readOnlyChips) {
      _editing = false;
      _editingIndex = null;
      _labels
        ..clear()
        ..addAll(normalized);
      return;
    }
    if (!_editing && !listEquals(_labels, normalized)) {
      _labels
        ..clear()
        ..addAll(normalized);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _editorTextPainter.dispose();
    super.dispose();
  }

  List<String> _draftLabels() {
    final value = _controller.text;
    return widget.normalizeLabels([
      for (var index = 0; index < _labels.length; index++)
        if (_editing && index == _editingIndex && value.trim().isNotEmpty)
          value
        else
          _labels[index],
      if (_editing && _editingIndex == null) value,
    ]);
  }

  void _publish() {
    widget.onChanged?.call(_draftLabels());
  }

  void _startEditing([int? index]) {
    if (!widget.enabled) return;
    if (index != null && widget.readOnlyChips) return;
    final label = index == null ? null : _labels[index];
    _finishEditing(commit: false);
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

  void _finishEditing({bool commit = true}) {
    if (!_editing) return;
    final value = _controller.text;
    late final List<String> updated;
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
      updated = widget.normalizeLabels(_labels);
      _labels
        ..clear()
        ..addAll(updated);
      _editing = false;
      _editingIndex = null;
    });
    _focusNode.unfocus();
    _publish();
    if (commit) {
      widget.onCommit?.call(updated);
    }
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
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                Icons.add,
                size: 18,
                semanticLabel: widget.addLabelTooltip,
              ),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        if (_labels.isNotEmpty || _editing) ...[
          const SizedBox(height: AppSpacing.xs),
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
    final editable = widget.enabled && !widget.readOnlyChips;
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
                onTap: editable ? () => _startEditing(index) : null,
                borderRadius: radius,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: editable ? AppLayout.minTouchTarget : 0,
                    minHeight: editable ? AppLayout.minTouchTarget : 0,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: editable ? AppSpacing.sm : AppSpacing.xs,
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
            if (editable)
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
