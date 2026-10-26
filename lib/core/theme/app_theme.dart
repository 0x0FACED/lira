import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  static const paperColor = Color(0xFFFAF9F5);
  static final ThemeData lightTheme = _build(Brightness.light);
  static final ThemeData darkTheme = _build(Brightness.dark);

  static const _clickCursor = WidgetStatePropertyAll(SystemMouseCursors.click);

  static const _lightColors = ColorScheme.light(
    primary: Color(0xFFAD5036),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF5E1D7),
    onPrimaryContainer: Color(0xFF71321F),
    secondary: Color(0xFF5D704A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE8EDDF),
    onSecondaryContainer: Color(0xFF35442C),
    tertiary: Color(0xFF456E91),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE5EDF4),
    onTertiaryContainer: Color(0xFF284861),
    error: Color(0xFFAA3934),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9E3DF),
    onErrorContainer: Color(0xFF69221E),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF141413),
    onSurfaceVariant: Color(0xFF6B695F),
    outline: Color(0xFF969184),
    outlineVariant: Color(0xFFE5E2D9),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF6F4EE),
    surfaceContainer: Color(0xFFEFEDE5),
    surfaceContainerHigh: Color(0xFFE8E6DC),
    surfaceContainerHighest: Color(0xFFE2DFD5),
    inverseSurface: Color(0xFF2B2925),
    onInverseSurface: Color(0xFFFAF9F5),
    inversePrimary: Color(0xFFE9A087),
    shadow: Color(0xFF141413),
    scrim: Color(0xFF141413),
  );

  static const _darkColors = ColorScheme.dark(
    primary: Color(0xFFE29A7E),
    onPrimary: Color(0xFF351D15),
    primaryContainer: Color(0xFF4C3127),
    onPrimaryContainer: Color(0xFFF0B99E),
    secondary: Color(0xFFA6B88F),
    onSecondary: Color(0xFF26321D),
    secondaryContainer: Color(0xFF35412B),
    onSecondaryContainer: Color(0xFFDCE6CE),
    tertiary: Color(0xFF9CBBD5),
    onTertiary: Color(0xFF193347),
    tertiaryContainer: Color(0xFF2C4253),
    onTertiaryContainer: Color(0xFFD5E8F7),
    error: Color(0xFFEBA19A),
    onError: Color(0xFF541D19),
    errorContainer: Color(0xFF602A25),
    onErrorContainer: Color(0xFFFFDAD4),
    surface: Color(0xFF252320),
    onSurface: Color(0xFFF2F0E8),
    onSurfaceVariant: Color(0xFFB9B5A9),
    outline: Color(0xFF827D71),
    outlineVariant: Color(0xFF403C35),
    surfaceContainerLowest: Color(0xFF171614),
    surfaceContainerLow: Color(0xFF211F1C),
    surfaceContainer: Color(0xFF2B2824),
    surfaceContainerHigh: Color(0xFF33302B),
    surfaceContainerHighest: Color(0xFF3C3831),
    inverseSurface: Color(0xFFEAE7DE),
    onInverseSurface: Color(0xFF252320),
    inversePrimary: Color(0xFFAD5036),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static ThemeData _build(Brightness brightness) {
    final colors = brightness == Brightness.light ? _lightColors : _darkColors;
    final canvas = brightness == Brightness.light
        ? paperColor
        : const Color(0xFF191817);
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Inter',
    );
    final text = base.textTheme.copyWith(
      displayLarge: _editorial(colors, 48),
      displayMedium: _editorial(colors, 40),
      displaySmall: _editorial(colors, 36),
      headlineLarge: _editorial(colors, 32),
      headlineMedium: _editorial(colors, 28),
      headlineSmall: _editorial(colors, 24),
      titleLarge: _editorial(colors, 22),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        height: 1.5,
        color: colors.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 1.5,
        color: colors.onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        height: 1.5,
        color: colors.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: colors.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: colors.onSurfaceVariant,
      ),
    );
    const controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
    );
    final outlinedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: colors.outlineVariant),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    final inputTheme = InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.compact,
        vertical: AppSpacing.compact,
      ),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
      hintStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      labelStyle: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      prefixIconColor: colors.onSurfaceVariant,
      suffixIconColor: colors.onSurfaceVariant,
    );
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      shape: const WidgetStatePropertyAll(controlShape),
      mouseCursor: _clickCursor,
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      animationDuration: AppMotion.fast,
    );

    return base.copyWith(
      textTheme: text,
      canvasColor: canvas,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
        titleTextStyle: text.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: outlinedShape,
      ),
      inputDecorationTheme: inputTheme,
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: buttonStyle.copyWith(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(colors.primary),
          foregroundColor: WidgetStatePropertyAll(colors.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle.copyWith(
          foregroundColor: WidgetStatePropertyAll(colors.onSurface),
          side: WidgetStatePropertyAll(BorderSide(color: colors.outline)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: buttonStyle.copyWith(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.compact),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          mouseCursor: _clickCursor,
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: const WidgetStatePropertyAll(controlShape),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? colors.onSurface.withValues(alpha: 0.35)
                : colors.onSurfaceVariant;
          }),
          animationDuration: AppMotion.fast,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: _clickCursor,
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: const WidgetStatePropertyAll(controlShape),
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.outlineVariant),
          ),
          animationDuration: AppMotion.fast,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.primaryContainer,
        disabledColor: colors.surfaceContainerHigh,
        side: BorderSide(color: colors.outlineVariant),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
        labelStyle: text.labelMedium?.copyWith(color: colors.onSurface),
        secondaryLabelStyle: text.labelMedium?.copyWith(
          color: colors.onPrimaryContainer,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        pressElevation: 0,
        checkmarkColor: colors.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppLayout.bottomNavHeight,
        elevation: 0,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        useIndicator: true,
        indicatorColor: colors.primaryContainer,
        selectedIconTheme: IconThemeData(color: colors.primary, size: 22),
        unselectedIconTheme: IconThemeData(
          color: colors.onSurfaceVariant,
          size: 22,
        ),
        selectedLabelTextStyle: text.labelLarge?.copyWith(
          color: colors.primary,
        ),
        unselectedLabelTextStyle: text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      listTileTheme: ListTileThemeData(
        mouseCursor: _clickCursor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
        ),
        minLeadingWidth: 24,
        minVerticalPadding: AppSpacing.sm,
        minTileHeight: AppLayout.minTouchTarget,
        iconColor: colors.onSurfaceVariant,
        textColor: colors.onSurface,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        shape: controlShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: outlinedShape,
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
        insetPadding: const EdgeInsets.all(AppSpacing.compact),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colors.outline,
        dragHandleSize: const Size(40, 4),
        constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: outlinedShape,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 1,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceContainerHigh,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHigh,
        circularTrackColor: colors.surfaceContainerHigh,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        actionTextColor: colors.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: controlShape,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: outlinedShape,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.22),
        selectionHandleColor: colors.primary,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(colors.outline),
        radius: const Radius.circular(AppRadius.sm),
        thickness: const WidgetStatePropertyAll(6),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: _LiraPageTransitionsBuilder(),
          TargetPlatform.windows: _LiraPageTransitionsBuilder(),
          TargetPlatform.linux: _LiraPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _LiraPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextStyle _editorial(ColorScheme colors, double size) => TextStyle(
    fontFamily: 'Lora',
    fontSize: size,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
    color: colors.onSurface,
  );
}

class _LiraPageTransitionsBuilder extends PageTransitionsBuilder {
  const _LiraPageTransitionsBuilder();

  static final _fade = CurveTween(curve: AppMotion.curve);
  static final _slide = Tween<Offset>(
    begin: const Offset(0, 0.025),
    end: Offset.zero,
  ).chain(_fade);

  @override
  Duration get transitionDuration => AppMotion.normal;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return FadeTransition(
      opacity: animation.drive(_fade),
      child: SlideTransition(position: animation.drive(_slide), child: child),
    );
  }
}
