import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable Glassmorphism Container with blur, translucent white surface,
/// subtle frosted border, and ambient drop shadow.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double blurSigma;
  final Color? surfaceColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20,
    this.blurSigma = 12,
    this.surfaceColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Default crisp white glassmorphism for light mode, frosted dark for dark mode
    final defaultBg = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.78);

    final defaultBorder = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.9);

    final defaultShadows = shadows ?? [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : const Color(0xFF64748B).withValues(alpha: 0.08),
        blurRadius: 18,
        spreadRadius: 1,
        offset: const Offset(0, 6),
      ),
    ];

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: surfaceColor ?? defaultBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? defaultBorder,
              width: borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: defaultShadows,
      ),
      child: content,
    );
  }
}

/// Reusable Glass Card with subtle elevation and micro-interaction
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? accentColor;

  const GlassCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final borderColor = accentColor != null
        ? accentColor!.withValues(alpha: 0.35)
        : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.95));

    final surfaceColor = isDark
        ? (accentColor != null ? accentColor!.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.35))
        : (accentColor != null ? accentColor!.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.82));

    return GlassContainer(
      margin: margin,
      padding: padding,
      borderRadius: borderRadius,
      surfaceColor: surfaceColor,
      borderColor: borderColor,
      onTap: onTap,
      child: child,
    );
  }
}

/// Reusable Glass Pill Badge for categories, status, priorities
class GlassPillBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  const GlassPillBadge({
    super.key,
    required this.label,
    this.icon,
    this.color = const Color(0xFF6366F1),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? color.withValues(alpha: 0.95) : color,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: pill,
      );
    }
    return pill;
  }
}

/// Frosted Glass Action Button with micro-interactions
class GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final Widget label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final bg = backgroundColor ?? (isDark ? primary.withValues(alpha: 0.3) : primary);
    final fg = foregroundColor ?? (isDark ? Colors.white : Colors.white);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(borderRadius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconTheme(
                  data: IconThemeData(color: fg, size: 18),
                  child: icon,
                ),
                const SizedBox(width: 8),
                DefaultTextStyle(
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  child: label,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphic Shimmer / Skeleton Loader for smooth asynchronous transitions
class GlassShimmerCard extends StatefulWidget {
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  const GlassShimmerCard({
    super.key,
    this.height = 80,
    this.borderRadius = 20,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  State<GlassShimmerCard> createState() => _GlassShimmerCardState();
}

class _GlassShimmerCardState extends State<GlassShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerValue = _controller.value;
        return Container(
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (shimmerValue * 2), -0.3),
              end: Alignment(1.0 + (shimmerValue * 2), 0.3),
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.05),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.6),
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.6),
                    ],
            ),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 140,
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Glassmorphic Circular Spinner Loader
class GlassLoader extends StatelessWidget {
  final String? statusText;
  final double size;

  const GlassLoader({
    super.key,
    this.statusText,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            ),
            if (statusText != null) ...[
              const SizedBox(height: 16),
              Text(
                statusText!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
