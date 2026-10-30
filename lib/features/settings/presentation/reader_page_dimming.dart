import 'package:flutter/material.dart';

/// Extra software dimming, independent of palette contrast and system brightness.
class ReaderPageDimming extends StatelessWidget {
  const ReaderPageDimming({
    super.key,
    required this.brightness,
    required this.child,
  });

  final double brightness;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(child: child),
      if (brightness < 1)
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withAlpha(
                ((1 - brightness.clamp(0.2, 1.0)) * 200).round(),
              ),
            ),
          ),
        ),
    ],
  );
}
