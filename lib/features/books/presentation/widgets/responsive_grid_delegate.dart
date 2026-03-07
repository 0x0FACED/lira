import 'package:flutter/rendering.dart';

/// A grid delegate that smoothly adjusts column count based on available width.
///
/// Unlike [SliverGridDelegateWithMaxCrossAxisExtent], this delegate:
/// - Respects both [minCrossAxisExtent] and [maxCrossAxisExtent]
/// - Smoothly interpolates cell size between min and max
/// - Only changes column count when there's enough space for all cells at max width
/// - Centers the grid when cells are at max width (leaves equal space on both sides)
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

    // Calculate how many columns fit at minimum width
    final maxColumns = ((availableWidth + crossAxisSpacing) /
                        (minCrossAxisExtent + crossAxisSpacing)).floor();

    if (maxColumns <= 0) {
      // Fallback to at least 1 column
      return _createLayout(availableWidth, 1, constraints);
    }

    // If column width is less than minimum, reduce column count
    int actualColumns = maxColumns;
    while (actualColumns > 1) {
      final testWidth = (availableWidth - crossAxisSpacing * (actualColumns - 1)) / actualColumns;
      if (testWidth >= minCrossAxisExtent) {
        break;
      }
      actualColumns--;
    }

    return _createLayout(availableWidth, actualColumns, constraints);
  }

  SliverGridLayout _createLayout(double availableWidth, int crossAxisCount, SliverConstraints constraints) {
    // Calculate actual cell width based on column count
    final cellWidth = (availableWidth - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;

    // Clamp cell width between min and max
    final clampedCellWidth = cellWidth.clamp(minCrossAxisExtent, maxCrossAxisExtent);
    
    // Calculate total width used by cells and spacing
    final totalContentWidth = clampedCellWidth * crossAxisCount + crossAxisSpacing * (crossAxisCount - 1);
    
    // Calculate centering offset (equal space on both sides)
    final centeringOffset = (availableWidth - totalContentWidth) / 2;

    final cellHeight = clampedCellWidth / childAspectRatio;

    return _CenteredSliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: cellHeight + mainAxisSpacing,
      crossAxisStride: clampedCellWidth + crossAxisSpacing,
      childMainAxisExtent: cellHeight,
      childCrossAxisExtent: clampedCellWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
      centeringOffset: centeringOffset,
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

/// Custom layout that supports centering offset
class _CenteredSliverGridRegularTileLayout extends SliverGridLayout {
  final int crossAxisCount;
  final double mainAxisStride;
  final double crossAxisStride;
  final double childMainAxisExtent;
  final double childCrossAxisExtent;
  final bool reverseCrossAxis;
  final double centeringOffset;

  const _CenteredSliverGridRegularTileLayout({
    required this.crossAxisCount,
    required this.mainAxisStride,
    required this.crossAxisStride,
    required this.childMainAxisExtent,
    required this.childCrossAxisExtent,
    required this.reverseCrossAxis,
    required this.centeringOffset,
  });

  @override
  SliverGridGeometry geometryForIndex(int index) {
    final row = index ~/ crossAxisCount;
    final column = index % crossAxisCount;

    // Calculate position with centering offset
    final scrollOffset = row * mainAxisStride;
    final crossAxisOffset = centeringOffset + column * crossAxisStride;

    return SliverGridGeometry(
      scrollOffset: scrollOffset,
      crossAxisOffset: crossAxisOffset,
      mainAxisExtent: childMainAxisExtent,
      crossAxisExtent: childCrossAxisExtent,
    );
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    return geometryForIndex(index);
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    if (childCount == 0) return 0.0;
    final rowCount = (childCount / crossAxisCount).ceil();
    return rowCount * mainAxisStride - mainAxisStride;
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    final row = (scrollOffset / mainAxisStride).ceil();
    return row * crossAxisCount;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    final row = (scrollOffset / mainAxisStride).ceil();
    return row * crossAxisCount + crossAxisCount - 1;
  }

  @override
  bool shouldRelayout(covariant _CenteredSliverGridRegularTileLayout old) {
    return old.crossAxisCount != crossAxisCount ||
        old.mainAxisStride != mainAxisStride ||
        old.crossAxisStride != crossAxisStride ||
        old.childMainAxisExtent != childMainAxisExtent ||
        old.childCrossAxisExtent != childCrossAxisExtent ||
        old.reverseCrossAxis != reverseCrossAxis ||
        old.centeringOffset != centeringOffset;
  }
}
