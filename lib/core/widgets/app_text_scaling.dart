import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/interface_font_scale_provider.dart';

/// Scales app chrome without changing the reader's explicit content font size.
class AppTextScaling extends ConsumerWidget {
  const AppTextScaling({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percent = ref.watch(interfaceFontScaleProvider);
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: percent == 100
            ? media.textScaler
            : _InterfaceTextScaler(media.textScaler, percent / 100),
      ),
      child: child,
    );
  }
}

/// Compose with the system curve instead of replacing nonlinear accessibility
/// scaling with a single linear factor.
class _InterfaceTextScaler extends TextScaler {
  const _InterfaceTextScaler(this.system, this.factor);

  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is _InterfaceTextScaler &&
      other.system == system &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);
}
