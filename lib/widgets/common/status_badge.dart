import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum BadgeType {
  active,
  exited,
  advancePaid,
  warning,
  danger,
  info,
}

/// A compact pill badge for showing status (e.g. Parked, Exited, Advance, Valid, Expired)
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType type;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = BadgeType.active,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (type) {
      case BadgeType.active:
        bg = AppColors.successLight;
        fg = AppColors.successDark;
        border = AppColors.success.withValues(alpha: 0.3);
        break;
      case BadgeType.advancePaid:
      case BadgeType.warning:
        bg = AppColors.warningLight;
        fg = AppColors.warningDark;
        border = AppColors.warning.withValues(alpha: 0.3);
        break;
      case BadgeType.danger:
        bg = AppColors.dangerLight;
        fg = AppColors.dangerDark;
        border = AppColors.danger.withValues(alpha: 0.3);
        break;
      case BadgeType.exited:
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
        border = AppColors.border;
        break;
      case BadgeType.info:
        bg = AppColors.primarySurface;
        fg = AppColors.primary;
        border = AppColors.primaryLight.withValues(alpha: 0.3);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
