import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double compact = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 28;
}

abstract final class AppLayout {
  static const double contentMaxWidth = 1120;
  static const double formMaxWidth = 640;
  static const double desktopBreakpoint = 900;
  static const double bottomNavHeight = 72;
  static const double minTouchTarget = 48;
  static const double bookCardMinWidthDesktop = 180;
  static const double bookCardMinWidth = 148;
  static const double bookCardMaxWidth = 240;
  static const double bookCardAspectRatio = 0.40;
  static const double discoverCardWidth = 272;
  static const double discoverImageAspectRatio = 16 / 9;
  static const double discoverDetailImageHeight = 280;
  static const double discoverProgressSize = 20;
  static const double discoverProgressStroke = 2;
  static const int discoverShelfItemLimit = 12;
  static const int discoverTitleLines = 3;
  static const int discoverSummaryLines = 4;
  static const double discoverMaxCardTextScale = 1.5;
  static const double discoverSearchControlsFraction = 0.5;
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve curve = Curves.easeOutCubic;
  static const Duration searchDebounce = Duration(milliseconds: 350);

  static Duration duration(BuildContext context, [Duration value = normal]) {
    return MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : value;
  }

  static AnimationStyle sheetStyle(BuildContext context) => AnimationStyle(
    duration: duration(context, slow),
    reverseDuration: duration(context),
    curve: curve,
    reverseCurve: Curves.easeInCubic,
  );

  static AnimationStyle dialogStyle(BuildContext context) => AnimationStyle(
    duration: duration(context),
    reverseDuration: duration(context, fast),
    curve: curve,
    reverseCurve: Curves.easeInCubic,
  );
}
