import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../domain/discover_item.dart';
import '../domain/discover_source.dart';
import 'discover_widgets.dart';

class DiscoverCarousel extends StatefulWidget {
  const DiscoverCarousel({
    super.key,
    required this.source,
    required this.items,
    required this.cardWidth,
    required this.height,
    required this.onOpen,
  });

  final DiscoverSource source;
  final List<DiscoverItem> items;
  final double cardWidth;
  final double height;
  final ValueChanged<DiscoverItem> onOpen;

  @override
  State<DiscoverCarousel> createState() => _DiscoverCarouselState();
}

class _DiscoverCarouselState extends State<DiscoverCarousel> {
  final _scrollController = ScrollController();
  final _cardFocusNodes = <FocusNode>[];
  bool _canScrollBack = false;
  bool _canScrollForward = false;

  int get _itemCount =>
      math.min(widget.items.length, AppLayout.discoverShelfItemLimit);
  double get _stride => widget.cardWidth + AppSpacing.sm;

  @override
  void initState() {
    super.initState();
    _syncFocusNodes();
    _scrollController.addListener(_updateControls);
  }

  @override
  void didUpdateWidget(covariant DiscoverCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocusNodes();
  }

  void _syncFocusNodes() {
    while (_cardFocusNodes.length > _itemCount) {
      _cardFocusNodes.removeLast().dispose();
    }
    while (_cardFocusNodes.length < _itemCount) {
      _cardFocusNodes.add(FocusNode(skipTraversal: true));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _cardFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _updateControls() {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions)
      return;
    final position = _scrollController.position;
    final back = position.pixels > position.minScrollExtent;
    final forward = position.pixels < position.maxScrollExtent;
    if (back == _canScrollBack && forward == _canScrollForward) return;
    setState(() {
      _canScrollBack = back;
      _canScrollForward = forward;
    });
  }

  bool _onMetricsChanged(ScrollMetricsNotification notification) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateControls();
    });
    return false;
  }

  Future<void> _scrollTo(double offset) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = offset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final duration = AppMotion.duration(context);
    if (duration == Duration.zero) {
      _scrollController.jumpTo(target);
    } else {
      await _scrollController.animateTo(
        target,
        duration: duration,
        curve: AppMotion.curve,
      );
    }
  }

  void _scrollPage(int direction) {
    if (!_scrollController.hasClients) return;
    final distance = math.max(
      _stride,
      _scrollController.position.viewportDimension - _stride,
    );
    _scrollTo(_scrollController.offset + distance * direction);
  }

  void _focusRelative(int direction) {
    if (_itemCount == 0 || !_scrollController.hasClients) return;
    final focused = _cardFocusNodes.indexWhere((node) => node.hasFocus);
    final current = focused >= 0
        ? focused
        : (_scrollController.offset / _stride).floor();
    _focusIndex((current + direction).clamp(0, _itemCount - 1).toInt());
  }

  void _focusPage(int direction) {
    if (!_scrollController.hasClients) return;
    final count = math.max(
      1,
      (_scrollController.position.viewportDimension / _stride).floor(),
    );
    _focusRelative(direction * count);
  }

  Future<void> _focusIndex(int index) async {
    if (index < 0 || index >= _itemCount) return;
    final node = _cardFocusNodes[index];
    if (node.context != null) node.requestFocus();
    await _scrollTo(index * _stride);
    if (mounted &&
        index < _cardFocusNodes.length &&
        identical(_cardFocusNodes[index], node)) {
      node.requestFocus();
    }
  }

  void _jumpBy(double delta) {
    if (!_scrollController.hasClients || delta == 0) return;
    final position = _scrollController.position;
    _scrollController.jumpTo(
      (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
    );
  }

  Widget _edgeControl({required bool previous}) {
    final l10n = MaterialLocalizations.of(context);
    // These controls overlay the viewport, rather than shrinking it. Forward
    // horizontal pointer signals here too, so trackpad scrolling works on them.
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && event.scrollDelta.dx != 0) {
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {
            _jumpBy(event.scrollDelta.dx);
          });
        }
      },
      onPointerPanZoomUpdate: (event) => _jumpBy(-event.panDelta.dx),
      child: IconButton.filledTonal(
        tooltip: previous ? l10n.previousPageTooltip : l10n.nextPageTooltip,
        onPressed: (previous ? _canScrollBack : _canScrollForward)
            ? () => _scrollPage(previous ? -1 : 1)
            : null,
        icon: Icon(
          previous ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = switch (Theme.of(context).platform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => MediaQuery.sizeOf(context).width >= AppLayout.desktopBreakpoint,
    };
    return SizedBox(
      height: widget.height,
      child: FocusTraversalGroup(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _focusRelative(-1),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _focusRelative(1),
            const SingleActivator(LogicalKeyboardKey.home): () =>
                _focusIndex(0),
            const SingleActivator(LogicalKeyboardKey.end): () =>
                _focusIndex(_itemCount - 1),
            const SingleActivator(LogicalKeyboardKey.pageUp): () =>
                _focusPage(-1),
            const SingleActivator(LogicalKeyboardKey.pageDown): () =>
                _focusPage(1),
          },
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _onMetricsChanged,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ListView.separated(
                    key: PageStorageKey('discover-shelf-${widget.source.id}'),
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.compact,
                    ),
                    itemCount: _itemCount,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      return Focus(
                        key: ValueKey(item.id),
                        focusNode: _cardFocusNodes[index],
                        onFocusChange: (_) => setState(() {}),
                        onKeyEvent: (node, event) {
                          if (node.hasPrimaryFocus &&
                              event is KeyDownEvent &&
                              (event.logicalKey == LogicalKeyboardKey.enter ||
                                  event.logicalKey ==
                                      LogicalKeyboardKey.space)) {
                            widget.onOpen(item);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Container(
                          width: widget.cardWidth,
                          foregroundDecoration: _cardFocusNodes[index].hasFocus
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                )
                              : null,
                          child: DiscoverItemCard(
                            item: item,
                            source: widget.source,
                            onTap: () => widget.onOpen(item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (desktop && _canScrollBack)
                  PositionedDirectional(
                    start: 0,
                    top: AppSpacing.sm,
                    width: AppLayout.minTouchTarget,
                    child: _edgeControl(previous: true),
                  ),
                if (desktop && _canScrollForward)
                  PositionedDirectional(
                    end: 0,
                    top: AppSpacing.sm,
                    width: AppLayout.minTouchTarget,
                    child: _edgeControl(previous: false),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
