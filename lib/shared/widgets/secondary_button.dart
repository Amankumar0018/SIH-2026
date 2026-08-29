import 'package:flutter/material.dart';
import '../../core/constants/app_dimensions.dart';

/// Standard secondary / outlined button for lower-priority actions.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? borderColor;
  final Color? textColor;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveFg = textColor ?? theme.colorScheme.onSurface;
    final effectiveBorder = borderColor ?? theme.dividerColor;

    final Widget child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
            ),
          )
        : Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppDimensions.iconSm, color: effectiveFg),
                const SizedBox(width: AppDimensions.spaceSm),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: effectiveFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: AppDimensions.buttonHeightMd,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: effectiveFg,
          side: BorderSide(color: effectiveBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: AppDimensions.borderRadiusSm,
          ),
          padding: AppDimensions.paddingHorizontalMd,
        ),
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
    );
  }
}
