import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

/// Reusable card with glassmorphism-inspired styling.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final LinearGradient? gradient;
  final Color? color;
  final VoidCallback? onTap;
  final double? borderRadius;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
    this.color,
    this.onTap,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.animFast,
        padding: padding ?? const EdgeInsets.all(AppDimensions.cardPadding),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? (color ?? context.palette.card) : null,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppDimensions.radiusLg,
          ),
          border: border ??
              Border.all(
                color: context.palette.divider.withOpacity(0.5),
                width: 1,
              ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Gradient card variant with icon and text.
class AppFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final LinearGradient gradient;
  final VoidCallback? onTap;

  const AppFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: gradient,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
