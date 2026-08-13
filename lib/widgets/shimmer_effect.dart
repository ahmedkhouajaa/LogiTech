import 'package:flutter/material.dart';
import '../utils/constants.dart';

// ─── Shimmer Gradient Inherited Widget ──────────────────────────
// Carries the animation value + gradient down the tree so all
// ShimmerBox children share a single AnimationController.

class _ShimmerData extends InheritedWidget {
  final Animation<double> animation;

  const _ShimmerData({
    required this.animation,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ShimmerData old) => animation != old.animation;

  static _ShimmerData? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerData>();
}

/// Master shimmer container. Wrap your skeleton widgets with this.
/// All [ShimmerBox] descendants automatically pick up the animation.
class AppShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const AppShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.duration)..repeat();
    _animation = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerData(
      animation: _animation,
      child: widget.child,
    );
  }
}

/// Skeleton bone — a rounded rectangle that animates a bright highlight
/// sweep from left to right, using the parent [AppShimmer] controller.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 6.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final shimmerData = _ShimmerData.of(context);
    final isDark = AppColors.isDarkMode;

    // Colors for the shimmer gradient
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFDDE3EA);
    final shimmerColor =
        isDark ? const Color(0xFF475569) : const Color(0xFFF1F5F9);

    if (shimmerData == null) {
      // Fallback: static box when used outside AppShimmer
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: shimmerData.animation,
      builder: (context, _) {
        final t = shimmerData.animation.value;
        // Sweep the bright band from -1 → 2 across the bone
        final start = Alignment(-1.5 + t * 3.5, 0);
        final end = Alignment(-0.5 + t * 3.5, 0);

        return Container(
          width: width,
          height: height,
          margin: margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              colors: [baseColor, shimmerColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              begin: start,
              end: end,
            ),
          ),
        );
      },
    );
  }
}
