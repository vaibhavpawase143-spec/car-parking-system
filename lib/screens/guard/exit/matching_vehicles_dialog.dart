import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/vehicle_type.dart';

enum MatchingSort { newestEntry, oldestEntry, vehicleAZ }

/// Modal dialog shown when partial numeric search returns matching active vehicles.
/// Displays:
/// - Vehicle Number
/// - Vehicle Type
/// - Ticket Number
/// - Entry Time
/// - Entry Guard
/// - Entry Shift
/// - Advance Paid
/// - Photo
/// And allows Filtering by Vehicle Type and Sorting, requiring Guard to explicitly press [ Select Vehicle ].
class MatchingVehiclesDialog extends StatefulWidget {
  final List<ParkingRecord> matchingRecords;
  final String searchQuery;

  const MatchingVehiclesDialog({
    super.key,
    required this.matchingRecords,
    required this.searchQuery,
  });

  static Future<ParkingRecord?> show(
    BuildContext context, {
    required List<ParkingRecord> matchingRecords,
    required String searchQuery,
  }) {
    return showDialog<ParkingRecord>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MatchingVehiclesDialog(
        matchingRecords: matchingRecords,
        searchQuery: searchQuery,
      ),
    );
  }

  @override
  State<MatchingVehiclesDialog> createState() => _MatchingVehiclesDialogState();
}

class _MatchingVehiclesDialogState extends State<MatchingVehiclesDialog> {
  String _typeFilter = 'all'; // 'all', 'FOUR_WHEELER', 'TWO_WHEELER'
  MatchingSort _sortMode = MatchingSort.newestEntry;

  @override
  Widget build(BuildContext context) {
    // Pipeline: Filter -> Sort (actual DateTime / String)
    var records = List<ParkingRecord>.from(widget.matchingRecords);
    if (_typeFilter == 'FOUR_WHEELER') {
      records = records.where((r) => r.vehicleType == VehicleType.fourWheeler).toList();
    } else if (_typeFilter == 'TWO_WHEELER') {
      records = records.where((r) => r.vehicleType == VehicleType.twoWheeler).toList();
    }

    switch (_sortMode) {
      case MatchingSort.newestEntry:
        records.sort((a, b) => b.entryTime.compareTo(a.entryTime));
        break;
      case MatchingSort.oldestEntry:
        records.sort((a, b) => a.entryTime.compareTo(b.entryTime));
        break;
      case MatchingSort.vehicleAZ:
        records.sort((a, b) => a.vehicleNumber.compareTo(b.vehicleNumber));
        break;
    }

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.pin, color: AppColors.primary, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Matching Active Tickets (SEARCH: ${widget.searchQuery})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Found ${widget.matchingRecords.length} active vehicle(s) matching "${widget.searchQuery}". Please select one to proceed with exit:',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),

              // Filter & Sort bar
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final vt in [
                            ('all', AppStrings.all),
                            ('FOUR_WHEELER', AppStrings.fourWheeler),
                            ('TWO_WHEELER', AppStrings.twoWheeler),
                          ]) ...[
                            FilterChip(
                              label: Text(vt.$2, style: const TextStyle(fontSize: 11)),
                              selected: _typeFilter == vt.$1,
                              onSelected: (_) => setState(() => _typeFilter = vt.$1),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<MatchingSort>(
                    initialValue: _sortMode,
                    tooltip: AppStrings.sort,
                    onSelected: (s) => setState(() => _sortMode = s),
                    itemBuilder: (ctx) => [
                      _sortItem(MatchingSort.newestEntry, AppStrings.sortNewest),
                      _sortItem(MatchingSort.oldestEntry, AppStrings.sortOldest),
                      _sortItem(MatchingSort.vehicleAZ, AppStrings.guardNameSort),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sort, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(AppStrings.sort, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Matching List
              Flexible(
                child: records.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No vehicles match the selected filter.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final r = records[index];
                          final isCar = r.vehicleType == VehicleType.fourWheeler;
                          final entryDateTimeStr = AppFormatters.formatDateTime(r.entryTime);
                          final stayDurationStr = AppFormatters.formatDuration(DateTime.now().difference(r.entryTime));
                          final advanceStr = r.advanceAmount > 0
                              ? '${AppFormatters.formatCurrency(r.advanceAmount)} (${r.advancePaymentMethod.toUpperCase()})'
                              : 'None';

                          return Card(
                            key: ValueKey('matching_ticket_card_${r.id}'),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Photo
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: r.photoUrl != null && r.photoUrl!.isNotEmpty
                                        ? Image.network(
                                            r.photoUrl!,
                                            width: 64,
                                            height: 64,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => _fallbackPhoto(isCar),
                                          )
                                        : _fallbackPhoto(isCar),
                                  ),
                                  const SizedBox(width: 12),

                                  // Vehicle & Ticket Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                r.vehicleNumber,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primarySurface,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Ticket: ${r.ticketNumber}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${r.vehicleType.displayName} • Entry: $entryDateTimeStr',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Stay Duration: $stayDurationStr • Guard: ${r.entryGuardName} (${r.entryShift})',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Advance: $advanceStr',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                        const SizedBox(height: 8),

                                        // Required Explicit [ Select Vehicle ] Button
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ElevatedButton.icon(
                                            key: ValueKey('select_vehicle_button_${r.ticketNumber}'),
                                            icon: const Icon(Icons.check_circle_outline, size: 16),
                                            label: Text(
                                              AppStrings.select,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => Navigator.pop(context, r),
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
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<MatchingSort> _sortItem(MatchingSort value, String label) {
    return PopupMenuItem<MatchingSort>(
      value: value,
      child: Row(
        children: [
          Icon(
            value == _sortMode ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 16,
            color: value == _sortMode ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _fallbackPhoto(bool isCar) {
    return Container(
      width: 64,
      height: 64,
      color: isCar ? AppColors.primarySurface : AppColors.secondaryLight,
      child: Icon(
        isCar ? Icons.directions_car : Icons.two_wheeler,
        color: isCar ? AppColors.primary : AppColors.secondary,
        size: 28,
      ),
    );
  }
}
