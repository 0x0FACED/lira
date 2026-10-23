import 'package:flutter/rendering.dart';

/// A bounded-width book grid that centers its shelf within the available space.
class ResponsiveGridDelegate extends SliverGridDelegate {
  final double minCrossAxisExtent;
  final double maxCrossAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;

  const ResponsiveGridDelegate({
    required this.minCrossAxisExtent,
    required this.maxCrossAxisExtent,
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 16,
    this.childAspectRatio = 0.55,
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final availableWidth = constraints.crossAxisExtent;
    final calculatedColumns =
        ((availableWidth + crossAxisSpacing) /
                (minCrossAxisExtent + crossAxisSpacing))
            .floor();
    final columns = calculatedColumns < 1 ? 1 : calculatedColumns;
    final cellWidth =
        ((availableWidth - crossAxisSpacing * (columns - 1)) / columns)
            .clamp(0.0, maxCrossAxisExtent)
            .toDouble();
    final contentWidth = cellWidth * columns + crossAxisSpacing * (columns - 1);
    final cellHeight = cellWidth / childAspectRatio;

    return _CenteredSliverGridLayout(
      crossAxisCount: columns,
      mainAxisStride: cellHeight + mainAxisSpacing,
      crossAxisStride: cellWidth + crossAxisSpacing,
      childMainAxisExtent: cellHeight,
      childCrossAxisExtent: cellWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
      centeringOffset: (availableWidth - contentWidth) / 2,
    );
  }

  @override
  bool shouldRelayout(ResponsiveGridDelegate oldDelegate) {
    return oldDelegate.minCrossAxisExtent != minCrossAxisExtent ||
        oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.childAspectRatio != childAspectRatio;
  }
}

class _CenteredSliverGridLayout extends SliverGridRegularTileLayout {
  const _CenteredSliverGridLayout({
    required super.crossAxisCount,
    required super.mainAxisStride,
    required super.crossAxisStride,
    required super.childMainAxisExtent,
    required super.childCrossAxisExtent,
    required super.reverseCrossAxis,
    required this.centeringOffset,
  });

  final double centeringOffset;

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final geometry = super.getGeometryForChildIndex(index);
    return SliverGridGeometry(
      scrollOffset: geometry.scrollOffset,
      crossAxisOffset: geometry.crossAxisOffset + centeringOffset,
      mainAxisExtent: geometry.mainAxisExtent,
      crossAxisExtent: geometry.crossAxisExtent,
    );
  }
}
