import 'package:flutter/material.dart';
import '../../core/constants/app_dimensions.dart';

/// Reusable card component adhering to the Pukaar design system.
/// Supports tapping, custom padding, custom borders, and background color.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? elevation;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppDimensions.paddingMd,
    this.backgroundColor,
    this.borderColor,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveRadius = borderRadius ?? AppDimensions.borderRadiusMd;

    Widget cardContent = Padding(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      cardContent = InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        child: cardContent,
      );
    }

    return Card(
      elevation: elevation ?? AppDimensions.elevationLow,
      color: backgroundColor ?? theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: effectiveRadius,
        side: borderColor != null
            ? BorderSide(color: borderColor!, width: 1)
            : (theme.cardTheme.shape as RoundedRectangleBorder?)?.side ?? BorderSide.none,
      ),
      child: cardContent,
    );
  }
}
