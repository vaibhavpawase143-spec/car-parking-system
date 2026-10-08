import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../services/parking_service.dart';

/// Modal dialog for searching active parking records when Guard lacks the physical QR slip.
/// Accepts either Vehicle Number or Ticket Number.
/// Distinguishes between ticket query (preserving hyphens) and vehicle query (normalizing spaces/hyphens).
class ActiveParkingSearchDialog extends StatefulWidget {
  final ParkingService parkingService;

  const ActiveParkingSearchDialog({
    super.key,
    required this.parkingService,
  });

  static Future<ParkingRecord?> show(BuildContext context, {ParkingService? parkingService}) {
    return showDialog<ParkingRecord>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ActiveParkingSearchDialog(
        parkingService: parkingService ?? ParkingService(),
      ),
    );
  }

  @override
  State<ActiveParkingSearchDialog> createState() => _ActiveParkingSearchDialogState();
}

class _ActiveParkingSearchDialogState extends State<ActiveParkingSearchDialog> {
  final _searchController = TextEditingController();

  bool _isSearching = false;
  String? _errorMessage;
  List<ParkingRecord>? _results;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final rawQuery = _searchController.text.trim();
    if (rawQuery.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a vehicle number or ticket number.';
        _results = null;
      });
      return;
    }

    final normalizedQuery = AppFormatters.normalizeActiveSearchQuery(rawQuery);

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final records = await widget.parkingService.searchActiveVehicles(normalizedQuery);

      if (!mounted) return;

      if (records.isEmpty) {
        setState(() {
          _isSearching = false;
          _results = [];
          _errorMessage = 'No active vehicles found matching "$normalizedQuery".';
        });
      } else if (records.length == 1) {
        // Exactly one result -> Return directly for verification
        Navigator.pop(context, records.first);
      } else {
        // Multiple matches -> Display list for Guard selection
        setState(() {
          _isSearching = false;
          _results = records;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Error searching active parking: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
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
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.search, color: AppColors.primary, size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Search Active Parking',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
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
              const SizedBox(height: 4),
              const Text(
                'Enter customer vehicle number or ticket number:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),

              // Search Input Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]')),
                        UpperCaseTextFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: 'e.g. MH20AS8471, 1004, or TKT-2026...',
                        prefixIcon: const Icon(Icons.directions_car, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const ValueKey('active_search_submit_button'),
                    onPressed: _isSearching ? null : _performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(80, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(AppStrings.search, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Error or Empty Banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.dangerDark, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.dangerDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Multiple Matches List
              if (_results != null && _results!.isNotEmpty) ...[
                Text(
                  'Found ${_results!.length} matching active vehicle(s). Please select one:',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results!.length,
                    itemBuilder: (context, index) {
                      final r = _results![index];
                      final isCar = r.vehicleType == VehicleType.fourWheeler;
                      final entryTimeStr = AppFormatters.formatTime(r.entryTime);
                      final advanceStr = r.advanceAmount > 0
                          ? AppFormatters.formatCurrency(r.advanceAmount)
                          : 'None';

                      return Card(
                        key: ValueKey('active_search_result_${r.id}'),
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: ListTile(
                          onTap: () => Navigator.pop(context, r),
                          leading: r.photoUrl != null && r.photoUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    r.photoUrl!,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 44,
                                      height: 44,
                                      color: isCar ? AppColors.primarySurface : AppColors.secondaryLight,
                                      child: Icon(
                                        isCar ? Icons.directions_car : Icons.two_wheeler,
                                        color: isCar ? AppColors.primary : AppColors.secondary,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isCar ? AppColors.primarySurface : AppColors.secondaryLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    isCar ? Icons.directions_car : Icons.two_wheeler,
                                    color: isCar ? AppColors.primary : AppColors.secondary,
                                    size: 20,
                                  ),
                                ),
                          title: Text(
                            r.vehicleNumber,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${r.vehicleType.displayName} • Entry: $entryTimeStr • Advance: $advanceStr\nGuard: ${r.entryGuardName} (${r.entryShift}) • Ticket: ${r.ticketNumber}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                          ),
                          trailing: ElevatedButton(
                            key: ValueKey('active_select_vehicle_button_${r.ticketNumber}'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(0, 32),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => Navigator.pop(context, r),
                            child: Text(AppStrings.select, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
