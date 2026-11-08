import 'package:flutter/material.dart';

/// Circular progress ring with the percentage in the middle. Animates smoothly when it fills.
class ProgressRing extends StatelessWidget {
  final int done;
  final int total;
  final double size;
  final double strokeWidth;

  const ProgressRing({super.key, required this.done, required this.total, this.size = 44, this.strokeWidth = 5});

  static const _accent = Color(0xFF6366F1);
  static const _complete = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final target = total == 0 ? 0.0 : done / total;
    final isComplete = total > 0 && done == total;
    final color = isComplete ? _complete : _accent;

    return Tooltip(
      message: '$done of $total done',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: strokeWidth,
                    strokeCap: StrokeCap.round,
                    backgroundColor: color.withValues(alpha: 0.15),
                    color: color,
                  ),
                ),
                isComplete
                    ? Icon(Icons.check_rounded, color: color, size: size * 0.45)
                    : Text(
                        '${(value * 100).round()}%',
                        style: TextStyle(fontSize: size * 0.26, fontWeight: FontWeight.w800, color: color),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}
