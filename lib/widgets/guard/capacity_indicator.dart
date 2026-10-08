import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/vehicle_type.dart';

/// Visual indicator for parking slot capacity.
/// Displays Total, Occupied, and Available slots for Cars and Two-Wheelers.
/// Alerts if available capacity reaches 0 (Entry Blocked).
class CapacityIndicator extends StatelessWidget {
  final int carTotal;
  final int carOccupied;
  final int twoWheelerTotal;
  final int twoWheelerOccupied;

  const CapacityIndicator({
    super.key,
    required this.carTotal,
    required this.carOccupied,
    required this.twoWheelerTotal,
    required this.twoWheelerOccupied,
  });

  int get carAvailable => (carTotal - carOccupied).clamp(0, carTotal);
  int get twoWheelerAvailable => (twoWheelerTotal - twoWheelerOccupied).clamp(0, twoWheelerTotal);

  bool isBlocked(VehicleType type) {
    switch (type) {
      case VehicleType.fourWheeler:
        return carAvailable <= 0;
      case VehicleType.twoWheeler:
        return twoWheelerAvailable <= 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.tune,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.liveCapacity,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, size: 8, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.live,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildVehicleCapacityRow(
              context: context,
              type: VehicleType.fourWheeler,
              total: carTotal,
              occupied: carOccupied,
              available: carAvailable,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1),
            ),
            _buildVehicleCapacityRow(
              context: context,
              type: VehicleType.twoWheeler,
              total: twoWheelerTotal,
              occupied: twoWheelerOccupied,
              available: twoWheelerAvailable,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCapacityRow({
    required BuildContext context,
    required VehicleType type,
    required int total,
    required int occupied,
    required int available,
  }) {
    final bool isFull = available <= 0;
    final double fraction = total > 0 ? (occupied / total).clamp(0.0, 1.0) : 0.0;

    Color progressColor;
    if (isFull) {
      progressColor = AppColors.danger;
    } else if (fraction > 0.85) {
      progressColor = AppColors.warning;
    } else {
      progressColor = AppColors.success;
    }

    final typeLabel = type == VehicleType.twoWheeler
        ? AppStrings.twoWheeler
        : AppStrings.fourWheeler;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(type.icon, size: 20, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (isFull)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  AppStrings.fullEntryBlocked,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dangerDark,
                  ),
                ),
              )
            else
              Text(
                '${(fraction * 100).toInt()}% ${AppStrings.occupied}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: progressColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildSlotMetric(label: AppStrings.total, value: total.toString()),
            _buildSlotMetric(label: AppStrings.occupied, value: occupied.toString()),
            _buildSlotMetric(
              label: AppStrings.available,
              value: available.toString(),
              isHighlight: true,
              highlightColor: isFull ? AppColors.danger : AppColors.success,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlotMetric({
    required String label,
    required String value,
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isHighlight
                    ? (highlightColor ?? AppColors.textPrimary)
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
