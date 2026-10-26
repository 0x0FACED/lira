import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart' show Animation;
import 'package:flutter/rendering.dart' show CustomPainter;

/// Paints a captured source viewport over a live destination page.
///
/// Images and [progress] remain owned by the caller. No image is captured,
/// decoded, or disposed here. A value of zero draws the original image exactly;
/// a value of one draws nothing, including shadows. The same geometry therefore
/// works for dragging, settling, and cancelling a turn. In [dualPage] mode,
/// [destinationPage] supplies the printed underside of a center-spine leaf.
class PageCurlPainter extends CustomPainter {
  PageCurlPainter({
    required this.page,
    this.destinationPage,
    required this.progress,
    required this.forward,
    required this.paperColor,
    this.dualPage = false,
    this.verticalBias = 0.65,
  }) : _backPaper = _backPaperColor(paperColor),
       _darkPaper = paperColor.computeLuminance() < 0.35,
       _castShadowPaint = _shadowPaint(paperColor, false),
       _creaseShadowPaint = _shadowPaint(paperColor, true),
       super(repaint: progress);

  final ui.Image page;
  final ui.Image? destinationPage;
  final Animation<double> progress;
  final bool forward;
  final ui.Color paperColor;
  final bool dualPage;
  final double verticalBias;

  final ui.Color _backPaper;
  final bool _darkPaper;
  final ui.Paint _castShadowPaint;
  final ui.Paint _creaseShadowPaint;
  final ui.Paint _texturePaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.low
    ..isAntiAlias = false;
  final ui.Paint _paperPaint = ui.Paint()..isAntiAlias = false;
  final ui.Paint _shadePaint = ui.Paint()..isAntiAlias = false;
  final ui.Paint _backShadowPaint = ui.Paint()..maskFilter = _contactBlur;
  final ui.Paint _rimPaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 0.7;
  final ui.Path _backShadowPath = ui.Path();

  // Reuse blur filters rather than creating layers, shaders, or filter
  // resources for each animation frame. No custom GPU program is needed.
  static final ui.MaskFilter _contactBlur = ui.MaskFilter.blur(
    ui.BlurStyle.normal,
    7,
  );
  static final ui.MaskFilter _castBlur = ui.MaskFilter.blur(
    ui.BlurStyle.normal,
    0.24,
  );
  static final ui.MaskFilter _creaseBlur = ui.MaskFilter.blur(
    ui.BlurStyle.normal,
    0.18,
  );

  static ui.Color _backPaperColor(ui.Color paper) {
    final opaque = paper.withAlpha(255);
    final dark = paper.computeLuminance() < 0.35;
    // A dark reader has dark paper, not a white physical-page flash. Only a
    // modest lift distinguishes its underside from the content beneath it.
    return ui.Color.lerp(
      opaque,
      dark ? const ui.Color(0xFFFFFFFF) : const ui.Color(0xFF000000),
      dark ? 0.055 : 0.025,
    )!;
  }

  static ui.Paint _shadowPaint(ui.Color paper, bool near) {
    final dark = paper.computeLuminance() < 0.35;
    final alpha = near ? (dark ? 110 : 62) : (dark ? 80 : 44);
    return ui.Paint()
      ..isAntiAlias = false
      ..color = ui.Color.fromARGB(alpha, 0, 0, 0)
      ..maskFilter = near ? _creaseBlur : _castBlur;
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (size.isEmpty) return;
    final p = progress.value.clamp(0.0, 1.0).toDouble();
    if (p >= 1) return;
    if (p <= 0 || (dualPage && destinationPage == null)) {
      _texturePaint.color = const ui.Color(0xFFFFFFFF);
      canvas.drawImageRect(
        page,
        ui.Rect.fromLTWH(0, 0, page.width.toDouble(), page.height.toDouble()),
        ui.Offset.zero & size,
        _texturePaint,
      );
      return;
    }

    if (dualPage) {
      _paintSpread(canvas, size, p);
      return;
    }

    final envelope = math.sin(math.pi * p);
    final bias = verticalBias.clamp(0.0, 1.0).toDouble();
    final anchor = size.height * bias;
    // Limit tilt by both angle and viewport width: portrait pages must not
    // develop a wildly diagonal fold. At the finger's Y the silhouette is
    // exactly width * (1 - progress), independent of this tilt.
    final shear =
        (bias - 0.5) *
        2 *
        math.min(0.075, size.width * 0.10 / size.height) *
        envelope;

    // A broad cylinder keeps real source text visibly bending before it rolls
    // onto the back. The comfortable single-page width is 800 logical pixels.
    final leafWidth = math.min(size.width, 800.0);
    final radius = leafWidth * 0.36 * envelope;
    final fold = size.width * (1 - p) - radius;
    final minShift = math.min(-shear * anchor, shear * (size.height - anchor));
    final maxShift = math.max(-shear * anchor, shear * (size.height - anchor));
    final minSource = -maxShift;
    final maxSource = size.width - minShift;

    canvas.save();
    canvas.clipRect(ui.Offset.zero & size);
    if (!forward) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    // Work in fold coordinates u = x - shear * (y - anchor). Each source
    // strip undoes this shear before sampling, so the unbent image stays
    // upright and stationary rather than rotating the whole screenshot.
    canvas.translate(-shear * anchor, 0);
    canvas.skew(shear, 0);

    _paintShadowBand(
      canvas,
      size.height,
      fold + radius - 0.25 * envelope,
      radius * 0.32 + 1.5 * envelope,
      _castShadowPaint,
    );
    _paintShadowBand(
      canvas,
      size.height,
      fold + radius - 0.25 * envelope,
      radius * 0.035 + envelope,
      _creaseShadowPaint,
    );

    if (fold > minSource) {
      final end = math.min(fold, maxSource);
      _paintStrip(
        canvas,
        size,
        shear,
        anchor,
        minSource,
        end,
        minSource,
        end,
        back: false,
        shade: 0,
      );
    }

    // A material coordinate u beyond the flat fold follows a cylinder:
    // theta = (u - fold) / radius,
    // X = fold + radius * sin(theta), Z = radius * (1 - cos(theta)).
    // After pi it continues as a reversed flat underside at height 2*radius.
    // Front first, then the nearer back: no arbitrary cross-fade of content.
    _paintArc(canvas, size, shear, anchor, fold, radius, back: false);
    _paintBackShadow(canvas, size, shear, anchor, fold, radius, envelope);
    _paintArc(canvas, size, shear, anchor, fold, radius, back: true);
    final backStart = fold + math.pi * radius;
    if (maxSource > backStart) {
      _paintStrip(
        canvas,
        size,
        shear,
        anchor,
        backStart,
        maxSource,
        fold,
        2 * fold + math.pi * radius - maxSource,
        back: true,
        shade: 0.025,
      );
    }

    // A restrained, paper-colored glint supplies the thickness cue without
    // introducing a white edge in dark mode. Its alpha also vanishes at rest.
    _rimPaint.color = ui.Color.lerp(
      paperColor,
      const ui.Color(0xFFFFFFFF),
      0.25,
    )!.withAlpha((65 * envelope).round());
    canvas.drawLine(
      ui.Offset(fold + radius, 0),
      ui.Offset(fold + radius, size.height),
      _rimPaint,
    );
    canvas.restore();
  }

  void _paintSpread(ui.Canvas canvas, ui.Size size, double p) {
    final target = destinationPage!;
    final leaf = size.width * 0.5;
    final envelope = math.sin(math.pi * p);
    final baseAngle = math.pi * p;
    // Integrate a constant-curvature leaf whose spine is fixed at width/2.
    // Its tangent varies from baseAngle-bend to baseAngle+bend. Thus it is
    // genuinely flexible, not a perspective-rotated card. At either endpoint
    // bend is zero and the leaf lies exactly on the appropriate book half.
    final bend = 0.9 * envelope;
    final firstAngle = baseAngle - bend;
    final tangent = ((math.pi * 0.5 - firstAngle) * leaf / (2 * bend))
        .clamp(0.0, leaf)
        .toDouble();
    final bias = verticalBias.clamp(0.0, 1.0).toDouble();
    final anchor = size.height * bias;
    final tilt =
        (bias - 0.5) *
        2 *
        math.min(0.045, leaf * 0.06 / size.height) *
        envelope;

    canvas.save();
    canvas.clipRect(ui.Offset.zero & size);
    if (!forward) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    // Keep the old opposite page stationary. The live destination is already
    // underneath the turning half; the incoming printed backside progressively
    // covers this stationary old page as it crosses the center spine.
    canvas.save();
    canvas.clipRect(ui.Rect.fromLTWH(0, 0, leaf, size.height));
    _texturePaint.color = const ui.Color(0xFFFFFFFF);
    _paintTexture(canvas, size, 0, leaf);
    canvas.restore();

    final freeEdge = _leafProjection(leaf, leaf, baseAngle, bend);
    final ridge = _leafProjection(tangent, leaf, baseAngle, bend);
    final left = math.min(0.0, freeEdge);
    final right = math.max(0.0, ridge);
    final offset = 9 * envelope;
    _backShadowPath
      ..reset()
      ..moveTo(leaf + left + offset - tilt * anchor, 0)
      ..lineTo(leaf + right + offset, 0)
      ..lineTo(leaf + right + offset, size.height)
      ..lineTo(
        leaf + left + offset + tilt * (size.height - anchor),
        size.height,
      )
      ..close();
    final shadowAlpha = paperColor.computeLuminance() < 0.35 ? 85 : 49;
    _backShadowPaint.color = ui.Color.fromARGB(
      (shadowAlpha * envelope).round(),
      0,
      0,
      0,
    );
    canvas.drawPath(_backShadowPath, _backShadowPaint);
    _paintShadowBand(
      canvas,
      size.height,
      leaf + right,
      leaf * 0.07 * envelope,
      _castShadowPaint,
    );

    // Ascending material coordinates also ascend in height. Draw the front
    // first, then the nearer back, splitting exactly at the vertical tangent.
    for (var side = 0; side < 2; side++) {
      final back = side == 1;
      final start = back ? tangent : 0.0;
      final end = back ? leaf : tangent;
      if (end <= start) continue;
      final count = ((end - start) / 2.4).ceil().clamp(1, 144);
      var u0 = start;
      var x0 = _leafProjection(u0, leaf, baseAngle, bend);
      for (var i = 1; i <= count; i++) {
        final u1 = start + (end - start) * i / count;
        final x1 = _leafProjection(u1, leaf, baseAngle, bend);
        final middle = (u0 + u1) * 0.5;
        final angle = firstAngle + 2 * bend * middle / leaf;
        // Both faces return to the unmodified captured colors when flat.
        // This is important on the final spread: unlike a departing single
        // page, its underside fills an entire half of the viewport at settle.
        final shade = 0.20 * (back ? 1 + math.cos(angle) : 1 - math.cos(angle));
        _paintSpineStrip(
          canvas,
          size,
          u0,
          u1,
          x0,
          x1,
          tilt * middle / leaf,
          anchor,
          shade,
          back: back,
          texture: back ? target : page,
        );
        u0 = u1;
        x0 = x1;
      }
    }
    _rimPaint.color = ui.Color.lerp(
      paperColor,
      const ui.Color(0xFFFFFFFF),
      0.25,
    )!.withAlpha((65 * envelope).round());
    canvas.drawLine(
      ui.Offset(leaf + freeEdge - tilt * anchor, 0),
      ui.Offset(leaf + freeEdge + tilt * (size.height - anchor), size.height),
      _rimPaint,
    );
    canvas.restore();
  }

  static double _leafProjection(
    double u,
    double leaf,
    double angle,
    double bend,
  ) {
    // Integral of cos(angle-bend + 2*bend*u/leaf). The midpoint/sinc form
    // avoids subtracting nearly equal sines near progress zero or one.
    final halfArc = bend * u / leaf;
    final sinc = halfArc.abs() < 0.00001
        ? 1 - halfArc * halfArc / 6
        : math.sin(halfArc) / halfArc;
    return u * math.cos(angle - bend + halfArc) * sinc;
  }

  void _paintSpineStrip(
    ui.Canvas canvas,
    ui.Size size,
    double u0,
    double u1,
    double x0,
    double x1,
    double shear,
    double anchor,
    double shade, {
    required bool back,
    required ui.Image texture,
  }) {
    if (x0 == x1) return;
    final leaf = size.width * 0.5;
    // Front material u reads the outgoing right half. Back material u reads
    // the incoming left half in reverse material order, becoming upright as
    // that leaf lands to the left. The outer reflection handles previous turns.
    final source0 = back ? leaf - u0 : leaf + u0;
    final source1 = back ? leaf - u1 : leaf + u1;
    final scale = (x1 - x0) / (source1 - source0);
    const overlap = 0.45;
    final padding = overlap / scale.abs() + size.width / texture.width;
    final sampleLeft = math.max(
      back ? 0.0 : leaf,
      math.min(source0, source1) - padding,
    );
    final sampleRight = math.min(
      back ? leaf : size.width,
      math.max(source0, source1) + padding,
    );

    canvas.save();
    // Each narrow strip has its own very small affine tilt. The tilt grows
    // with distance from the spine, keeping that hinge stationary. Adjacent
    // edge displacement is below the subpixel overdraw allowance.
    canvas.translate(-shear * anchor, 0);
    canvas.skew(shear, 0);
    canvas.clipRect(
      ui.Rect.fromLTRB(
        leaf + math.min(x0, x1) - overlap,
        0,
        leaf + math.max(x0, x1) + overlap,
        size.height,
      ),
      doAntiAlias: false,
    );
    canvas.translate(leaf + x0 - scale * source0, 0);
    canvas.scale(scale, 1);
    _texturePaint.color = const ui.Color(0xFFFFFFFF);
    _paintTexture(canvas, size, sampleLeft, sampleRight, image: texture);
    if (shade > 0) {
      _shadePaint.color = ui.Color.fromARGB((shade * 255).round(), 0, 0, 0);
      canvas.drawRect(
        ui.Rect.fromLTWH(back ? 0 : leaf, 0, leaf, size.height),
        _shadePaint,
      );
    }
    canvas.restore();
  }

  void _paintShadowBand(
    ui.Canvas canvas,
    double height,
    double x,
    double width,
    ui.Paint paint,
  ) {
    canvas.save();
    canvas.translate(x, 0);
    canvas.scale(width, 1);
    // Most of the blurred band is beneath the sheet. Its exposed right tail
    // is a smooth cast shadow, with sigma scaling alongside the band width.
    canvas.drawRect(ui.Rect.fromLTWH(-0.34, 0, 0.52, height), paint);
    canvas.restore();
  }

  void _paintArc(
    ui.Canvas canvas,
    ui.Size size,
    double shear,
    double anchor,
    double fold,
    double radius, {
    required bool back,
  }) {
    // Sample uniformly in projected pixels, not in angle. Near the tangent
    // that avoids dozens of subpixel slivers and visible pinching/seams.
    // 144 segments per side bounds work on large desktop viewports.
    final count = (radius / 1.6).ceil().clamp(1, 144);
    var t0 = back ? 1.0 : 0.0;
    var angle0 = back ? math.pi * 0.5 : 0.0;
    for (var i = 1; i <= count; i++) {
      final t1 = back ? 1 - i / count : i / count;
      final angle1 = back ? math.pi - math.asin(t1) : math.asin(t1);
      final angle = (angle0 + angle1) * 0.5;
      final shade = back
          ? 0.20 * (1 - (0.35 * math.sin(angle) - 0.936 * math.cos(angle)))
          : 0.22 * (1 - math.cos(angle));
      _paintStrip(
        canvas,
        size,
        shear,
        anchor,
        fold + radius * angle0,
        fold + radius * angle1,
        fold + radius * t0,
        fold + radius * t1,
        back: back,
        shade: shade,
      );
      t0 = t1;
      angle0 = angle1;
    }
  }

  void _paintStrip(
    ui.Canvas canvas,
    ui.Size size,
    double shear,
    double anchor,
    double u0,
    double u1,
    double x0,
    double x1, {
    required bool back,
    required double shade,
  }) {
    if (u1 <= u0 || x0 == x1) return;
    final scale = (x1 - x0) / (u1 - u0);
    final minShift = math.min(-shear * anchor, shear * (size.height - anchor));
    final maxShift = math.max(-shear * anchor, shear * (size.height - anchor));
    final left = math.min(x0, x1);
    final right = math.max(x0, x1);
    if (right + maxShift < 0 || left + minShift > size.width) return;

    // A little overdraw makes neighboring rasterized strips watertight even
    // at fractional device pixels. Repainting an opaque texture/paper base
    // first means the translucent shading does not accumulate at overlaps.
    const overlap = 0.45;
    final sourcePadding = overlap / scale.abs() + size.width / page.width;
    final sampleLeft = math.max(0.0, u0 + minShift - sourcePadding);
    final sampleRight = math.min(size.width, u1 + maxShift + sourcePadding);
    if (sampleRight <= sampleLeft) return;

    canvas.save();
    canvas.clipRect(
      ui.Rect.fromLTRB(left - overlap, 0, right + overlap, size.height),
      doAntiAlias: false,
    );
    canvas.translate(x0 - scale * u0, 0);
    canvas.scale(scale, 1);
    canvas.translate(shear * anchor, 0);
    canvas.skew(-shear, 0);

    if (back) {
      _paperPaint.color = _backPaper;
      canvas.drawRect(ui.Offset.zero & size, _paperPaint);
    }
    // Paper is not an opaque plastic card: faint, reversed ink show-through
    // follows the same bent source coordinates as the front. It is deliberately
    // subtle, and never used as a substitute for the underside paper color.
    _texturePaint.color = back
        ? const ui.Color(0x16FFFFFF)
        : const ui.Color(0xFFFFFFFF);
    _paintTexture(canvas, size, sampleLeft, sampleRight);
    if (shade > 0) {
      _shadePaint.color = ui.Color.fromARGB((shade * 255).round(), 0, 0, 0);
      canvas.drawRect(ui.Offset.zero & size, _shadePaint);
    }
    canvas.restore();
  }

  void _paintTexture(
    ui.Canvas canvas,
    ui.Size size,
    double left,
    double right, {
    ui.Image? image,
  }) {
    final texture = image ?? page;
    if (!forward) {
      // Geometry is mirrored, not the book's lettering. The second reflection
      // cancels the outer one on the front, but retains real backside reversal.
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
      final originalLeft = left;
      left = size.width - right;
      right = size.width - originalLeft;
    }
    final imageScale = texture.width / size.width;
    canvas.drawImageRect(
      texture,
      ui.Rect.fromLTRB(
        left * imageScale,
        0,
        right * imageScale,
        texture.height.toDouble(),
      ),
      ui.Rect.fromLTRB(left, 0, right, size.height),
      _texturePaint,
    );
    if (!forward) canvas.restore();
  }

  void _paintBackShadow(
    ui.Canvas canvas,
    ui.Size size,
    double shear,
    double anchor,
    double fold,
    double radius,
    double envelope,
  ) {
    final ridge = fold + radius;
    double edge(double y) {
      final u = size.width - shear * (y - anchor);
      final angle = (u - fold) / radius;
      if (angle <= math.pi * 0.5) return ridge;
      if (angle < math.pi) return fold + radius * math.sin(angle);
      return 2 * fold + math.pi * radius - u;
    }

    final top = edge(0);
    final bottom = edge(size.height);
    if (top >= ridge && bottom >= ridge) return;
    _backShadowPath
      ..reset()
      ..moveTo(top, 0)
      ..lineTo(ridge, 0)
      ..lineTo(ridge, size.height)
      ..lineTo(bottom, size.height)
      ..close();
    final alpha = _darkPaper ? 80 : 43;
    _backShadowPaint.color = ui.Color.fromARGB(
      (alpha * envelope).round(),
      0,
      0,
      0,
    );
    canvas.drawPath(_backShadowPath, _backShadowPaint);
  }

  @override
  bool shouldRepaint(covariant PageCurlPainter oldDelegate) =>
      page != oldDelegate.page ||
      destinationPage != oldDelegate.destinationPage ||
      progress != oldDelegate.progress ||
      forward != oldDelegate.forward ||
      paperColor != oldDelegate.paperColor ||
      dualPage != oldDelegate.dualPage ||
      verticalBias != oldDelegate.verticalBias;
}
