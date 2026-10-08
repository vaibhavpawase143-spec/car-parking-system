import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum AppButtonType {
  primary,
  secondary,
  danger,
  outline,
}

/// A touch-friendly button with large tap target (min height 50px),
/// loading indicator support, and distinct visual styles.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.height = 50.0,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (type) {
      case AppButtonType.primary:
        backgroundColor = AppColors.primaryOrange;
        foregroundColor = Colors.white;
        borderSide = null;
        break;
      case AppButtonType.secondary:
        backgroundColor = AppColors.primaryNavy;
        foregroundColor = Colors.white;
        borderSide = null;
        break;
      case AppButtonType.danger:
        backgroundColor = AppColors.error;
        foregroundColor = Colors.white;
        borderSide = null;
        break;
      case AppButtonType.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = AppColors.primaryNavy;
        borderSide = const BorderSide(color: AppColors.border, width: 1.5);
        break;
    }

    Widget content;
    if (isLoading) {
      content = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: foregroundColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      content = Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    final buttonWidget = ElevatedButton(
      onPressed: effectiveOnPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        minimumSize: Size(isFullWidth ? double.infinity : 120, height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: borderSide ?? BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: content,
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: buttonWidget) : buttonWidget;
  }
}
