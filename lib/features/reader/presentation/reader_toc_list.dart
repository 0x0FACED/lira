part of 'reader_screen.dart';

class _ReaderTocList extends StatefulWidget {
  const _ReaderTocList({
    super.key,
    required this.items,
    required this.active,
    required this.onNavigate,
  });

  final List<TOCItem> items;
  final TOCItem? active;
  final ValueChanged<String> onNavigate;

  @override
  State<_ReaderTocList> createState() => _ReaderTocListState();
}

class _ReaderTocListState extends State<_ReaderTocList> {
  final _expanded = <TOCItem>{};
  late List<({TOCItem item, int depth})> _rows;
  late final int _initialIndex;

  @override
  void initState() {
    super.initState();
    if (widget.active != null) _expandAncestors(widget.items);
    _flatten();
    final index = _rows.indexWhere((row) => row.item == widget.active);
    _initialIndex = index < 0 ? 0 : index;
  }

  bool _expandAncestors(List<TOCItem> items) {
    for (final item in items) {
      if (item == widget.active) return true;
      if (_expandAncestors(item.subItems)) {
        _expanded.add(item);
        return true;
      }
    }
    return false;
  }

  void _flatten() {
    final rows = <({TOCItem item, int depth})>[];
    void add(List<TOCItem> items, int depth) {
      for (final item in items) {
        rows.add((item: item, depth: depth));
        if (_expanded.contains(item)) add(item.subItems, depth + 1);
      }
    }

    add(widget.items, 0);
    _rows = rows;
  }

  void _toggle(TOCItem item) {
    setState(() {
      if (!_expanded.remove(item)) _expanded.add(item);
      _flatten();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScrollablePositionedList.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.compact,
        AppSpacing.sm,
        AppSpacing.compact,
        AppSpacing.md,
      ),
      initialScrollIndex: _initialIndex,
      initialAlignment: _initialIndex == 0 ? 0 : 0.15,
      // A new drawer opening follows the current chapter, not a saved scroll offset.
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        final (:item, :depth) = _rows[index];
        final toggle = item.subItems.isEmpty ? null : () => _toggle(item);
        return _ReaderTocRow(
          key: ObjectKey(item),
          item: item,
          depth: depth,
          active: item == widget.active,
          expanded: _expanded.contains(item),
          onNavigate: item.fileName.isEmpty
              ? toggle
              : () => widget.onNavigate(item.fileName),
          onToggle: toggle,
        );
      },
    );
  }
}

class _ReaderTocRow extends StatelessWidget {
  const _ReaderTocRow({
    super.key,
    required this.item,
    required this.depth,
    required this.active,
    required this.expanded,
    required this.onNavigate,
    required this.onToggle,
  });

  final TOCItem item;
  final int depth;
  final bool active;
  final bool expanded;
  final VoidCallback? onNavigate;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final material = MaterialLocalizations.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: depth.clamp(0, 4) * AppSpacing.compact,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              key: active ? const ValueKey('reader-active-toc-item') : null,
              selected: active ? true : null,
              child: Stack(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: WidgetStateProperty.resolveWith(
                      (states) =>
                          _readerInteractionInk(states, colors.onSurface),
                    ),
                    onTap: onNavigate,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppLayout.minTouchTarget,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.compact,
                            vertical: AppSpacing.sm,
                          ),
                          child: Text(
                            item.title,
                            style: active
                                ? theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  )
                                : theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (active)
                    PositionedDirectional(
                      start: 0,
                      top: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      width: 2,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (onToggle != null)
            IconButton(
              tooltip: expanded
                  ? material.expandedIconTapHint
                  : material.collapsedIconTapHint,
              icon: AnimatedRotation(
                turns: expanded ? (rtl ? -0.25 : 0.25) : 0,
                duration: AppMotion.duration(context, AppMotion.fast),
                curve: AppMotion.curve,
                child: const Icon(Icons.chevron_right),
              ),
              onPressed: onToggle,
            ),
        ],
      ),
    );
  }
}
