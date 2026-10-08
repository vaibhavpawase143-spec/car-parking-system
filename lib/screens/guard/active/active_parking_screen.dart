import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/fee_calculator.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../services/parking_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/qr_view_widget.dart';
import '../../../widgets/common/status_badge.dart';

/// Sort modes for Active Parking list — uses actual DateTime/fee values, never formatted strings.
enum ActiveParkingSort {
  newestFirst,
  oldestFirst,
  longestParked,
  shortestParked,
  vehicleAZ,
  vehicleZA,
  highestFee,
  lowestFee,
}

/// ActiveParkingScreen streams real-time active parking records from Firestore.
/// Features search by vehicle/ticket number, category filters, sort dropdown,
/// and detailed ticket modal.
class ActiveParkingScreen extends StatefulWidget {
  final VoidCallback onNewEntryTap;

  const ActiveParkingScreen({
    super.key,
    required this.onNewEntryTap,
  });

  @override
  State<ActiveParkingScreen> createState() => _ActiveParkingScreenState();
}

class _ActiveParkingScreenState extends State<ActiveParkingScreen> {
  final _parkingService = ParkingService();
  final _searchController = TextEditingController();
  Timer? _liveTicker;

  VehicleType? _filterType;
  bool _onlyWithAdvance = false;
  String _searchQuery = '';
  ActiveParkingSort _sortMode = ActiveParkingSort.newestFirst;

  @override
  void initState() {
    super.initState();
    _liveTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _sortLabel(ActiveParkingSort mode) {
    switch (mode) {
      case ActiveParkingSort.newestFirst:
        return AppStrings.newestFirst;
      case ActiveParkingSort.oldestFirst:
        return AppStrings.oldestFirst;
      case ActiveParkingSort.longestParked:
        return AppStrings.longestParked;
      case ActiveParkingSort.shortestParked:
        return AppStrings.shortestParked;
      case ActiveParkingSort.vehicleAZ:
        return AppStrings.vehicleAZ;
      case ActiveParkingSort.vehicleZA:
        return AppStrings.vehicleZA;
      case ActiveParkingSort.highestFee:
        return AppStrings.highestCurrentFee;
      case ActiveParkingSort.lowestFee:
        return AppStrings.lowestCurrentFee;
    }
  }

  /// Applies the selected sort mode to the record list.
  /// IMPORTANT: Uses actual DateTime/Duration/numeric values — never formatted strings.
  List<ParkingRecord> _applySort(List<ParkingRecord> records) {
    final now = DateTime.now();
    final sorted = List<ParkingRecord>.from(records);

    switch (_sortMode) {
      case ActiveParkingSort.newestFirst:
        sorted.sort((a, b) => b.entryTime.compareTo(a.entryTime));
        break;
      case ActiveParkingSort.oldestFirst:
        sorted.sort((a, b) => a.entryTime.compareTo(b.entryTime));
        break;
      case ActiveParkingSort.longestParked:
        // Compare actual entry times: earlier entry = longer stay
        sorted.sort((a, b) => a.entryTime.compareTo(b.entryTime));
        break;
      case ActiveParkingSort.shortestParked:
        // Later entry = shorter stay
        sorted.sort((a, b) => b.entryTime.compareTo(a.entryTime));
        break;
      case ActiveParkingSort.vehicleAZ:
        sorted.sort((a, b) =>
            a.vehicleNumber.toUpperCase().compareTo(b.vehicleNumber.toUpperCase()));
        break;
      case ActiveParkingSort.vehicleZA:
        sorted.sort((a, b) =>
            b.vehicleNumber.toUpperCase().compareTo(a.vehicleNumber.toUpperCase()));
        break;
      case ActiveParkingSort.highestFee:
        sorted.sort((a, b) {
          final feeA = FeeCalculator.calculate(
            vehicleType: a.vehicleType,
            entryTime: a.entryTime,
            exitTime: now,
            advancePaid: 0,
            isMonthlyPass: a.isMonthlyPass,
          ).grossCharge;
          final feeB = FeeCalculator.calculate(
            vehicleType: b.vehicleType,
            entryTime: b.entryTime,
            exitTime: now,
            advancePaid: 0,
            isMonthlyPass: b.isMonthlyPass,
          ).grossCharge;
          return feeB.compareTo(feeA);
        });
        break;
      case ActiveParkingSort.lowestFee:
        sorted.sort((a, b) {
          final feeA = FeeCalculator.calculate(
            vehicleType: a.vehicleType,
            entryTime: a.entryTime,
            exitTime: now,
            advancePaid: 0,
            isMonthlyPass: a.isMonthlyPass,
          ).grossCharge;
          final feeB = FeeCalculator.calculate(
            vehicleType: b.vehicleType,
            entryTime: b.entryTime,
            exitTime: now,
            advancePaid: 0,
            isMonthlyPass: b.isMonthlyPass,
          ).grossCharge;
          return feeA.compareTo(feeB);
        });
        break;
    }
    return sorted;
  }

  void _showVehicleDetails(ParkingRecord record) {
    final now = DateTime.now();
    final stayDuration = now.difference(record.entryTime);
    final feeResult = FeeCalculator.calculate(
      vehicleType: record.vehicleType,
      entryTime: record.entryTime,
      exitTime: now,
      advancePaid: record.advanceAmount,
      isMonthlyPass: record.isMonthlyPass,
    );
    final vehicleTypeLabel = record.vehicleType == VehicleType.twoWheeler
        ? AppStrings.twoWheeler
        : AppStrings.fourWheeler;

    final advanceMethodLabel = record.advancePaymentMethod.toUpperCase() == 'CASH'
        ? AppStrings.cash
        : record.advancePaymentMethod.toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          top: 20.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    record.vehicleNumber,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: AppColors.primary,
                    ),
                  ),
                  StatusBadge(label: AppStrings.parked, type: BadgeType.active),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 14),

              // Vehicle Photo (if available)
              if (record.photoUrl != null && record.photoUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    record.photoUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      color: AppColors.surfaceVariant,
                      child: Center(
                        child: Text(AppStrings.photoPreviewUnavailable, style: const TextStyle(color: AppColors.textMuted)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              _buildModalRow(AppStrings.ticketNumber, record.ticketNumber),
              _buildModalRow(AppStrings.vehicleType, vehicleTypeLabel),
              _buildModalRow(AppStrings.entryDateTime, AppFormatters.formatDateTime(record.entryTime)),
              _buildModalRow(AppStrings.stayDuration, AppFormatters.formatDuration(stayDuration), isHighlight: true),
              _buildModalRow(AppStrings.currentEstimatedFee, AppFormatters.formatCurrency(feeResult.grossCharge), isHighlight: true),
              _buildModalRow(AppStrings.guard, record.entryGuardName),
              _buildModalRow(AppStrings.shift, record.entryShift),
              if (record.customerMobile.isNotEmpty)
                _buildModalRow(AppStrings.customerMobile, record.customerMobile),
              _buildModalRow(
                AppStrings.advancePaid,
                record.advanceAmount > 0
                    ? '${AppFormatters.formatCurrency(record.advanceAmount)} ($advanceMethodLabel)'
                    : '₹0',
                isBold: record.advanceAmount > 0,
              ),
              if (record.advanceAmount > 0)
                _buildModalRow(
                  feeResult.balanceDue > 0 ? AppStrings.estimatedBalanceDue : AppStrings.estimatedRefund,
                  AppFormatters.formatCurrency(feeResult.balanceDue > 0 ? feeResult.balanceDue : feeResult.refundAmount),
                  isBold: true,
                ),
              const SizedBox(height: 16),

              // QR Code
              Center(
                child: QrViewWidget(
                  data: record.qrReference ?? record.ticketNumber,
                  size: 130,
                  subtitle: record.ticketNumber,
                ),
              ),
              const SizedBox(height: 20),

              AppButton(
                label: AppStrings.close,
                type: AppButtonType.outline,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value, {bool isHighlight = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: (isHighlight || isBold) ? FontWeight.w700 : FontWeight.w600,
              color: isHighlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Filter & Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s\-]')),
                  UpperCaseTextFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: AppStrings.searchByVehicleOrTicket,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
              ),
              const SizedBox(height: 10),
              // Category Filter Chips + Sort Row
              Row(
                children: [
                  // Filter chips (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text(AppStrings.allVehicles),
                            selected: _filterType == null && !_onlyWithAdvance,
                            onSelected: (_) {
                              setState(() {
                                _filterType = null;
                                _onlyWithAdvance = false;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(AppStrings.cars),
                            selected: _filterType == VehicleType.fourWheeler,
                            onSelected: (_) {
                              setState(() {
                                _filterType = _filterType == VehicleType.fourWheeler ? null : VehicleType.fourWheeler;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(AppStrings.bikes),
                            selected: _filterType == VehicleType.twoWheeler,
                            onSelected: (_) {
                              setState(() {
                                _filterType = _filterType == VehicleType.twoWheeler ? null : VehicleType.twoWheeler;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(AppStrings.withAdvance),
                            selected: _onlyWithAdvance,
                            onSelected: (_) {
                              setState(() {
                                _onlyWithAdvance = !_onlyWithAdvance;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort Dropdown
                  PopupMenuButton<ActiveParkingSort>(
                    initialValue: _sortMode,
                    tooltip: AppStrings.sortBy,
                    onSelected: (mode) => setState(() => _sortMode = mode),
                    itemBuilder: (context) => ActiveParkingSort.values
                        .map((mode) => PopupMenuItem(
                              value: mode,
                              child: Row(
                                children: [
                                  if (_sortMode == mode)
                                    const Icon(Icons.check, size: 16, color: AppColors.primary)
                                  else
                                    const SizedBox(width: 16),
                                  const SizedBox(width: 8),
                                  Text(_sortLabel(mode), style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.surface,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            AppStrings.sortBy,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Live Real-Time Stream of Active Vehicles
        Expanded(
          child: StreamBuilder<List<ParkingRecord>>(
            stream: _parkingService.watchActiveVehicles(
              searchQuery: _searchQuery,
              filterType: _filterType,
              onlyWithAdvance: _onlyWithAdvance,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('${AppStrings.error}: ${snapshot.error}'),
                  ),
                );
              }

              final rawRecords = snapshot.data ?? [];

              // Apply sort — uses actual DateTime/numeric values, NOT formatted strings
              final records = _applySort(rawRecords);

              if (records.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 80.0),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  return _buildActiveVehicleCard(records[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.local_parking, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _filterType != null || _onlyWithAdvance
                  ? AppStrings.noMatchingRecords
                  : AppStrings.noActiveVehicles,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            if (_searchQuery.isEmpty && _filterType == null && !_onlyWithAdvance)
              Text(
                AppStrings.noActiveVehiclesDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            if (_searchQuery.isEmpty && _filterType == null && !_onlyWithAdvance) ...[
              const SizedBox(height: 20),
              AppButton(
                label: AppStrings.newVehicleEntry,
                icon: Icons.add_circle,
                isFullWidth: false,
                onPressed: widget.onNewEntryTap,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveVehicleCard(ParkingRecord record) {
    final isCar = record.vehicleType == VehicleType.fourWheeler;
    final now = DateTime.now();
    final duration = now.difference(record.entryTime);
    final shortTypeLabel = isCar ? AppStrings.cars : AppStrings.bikes;
    final feeResult = FeeCalculator.calculate(
      vehicleType: record.vehicleType,
      entryTime: record.entryTime,
      exitTime: now,
      advancePaid: record.advanceAmount,
      isMonthlyPass: record.isMonthlyPass,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _showVehicleDetails(record),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo or Type Icon
              if (record.photoUrl != null && record.photoUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    record.photoUrl!,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildFallbackThumbnail(isCar),
                  ),
                )
              else
                _buildFallbackThumbnail(isCar),
              const SizedBox(width: 12),

              // Details Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          record.vehicleNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        StatusBadge(
                          label: shortTypeLabel,
                          type: BadgeType.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppStrings.ticketNumber}: ${record.ticketNumber}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppStrings.entryDateTime}: ${AppFormatters.formatDateTime(record.entryTime)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppStrings.guard}: ${record.entryGuardName} • ${record.entryShift}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${AppStrings.parkedFor} ${AppFormatters.formatDuration(duration)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Fee: ${AppFormatters.formatCurrency(feeResult.grossCharge)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (record.advanceAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          StatusBadge(
                            label: '${AppStrings.advancePaid}: ${AppFormatters.formatCurrency(record.advanceAmount)}',
                            type: BadgeType.advancePaid,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            feeResult.balanceDue > 0
                                ? 'Due: ${AppFormatters.formatCurrency(feeResult.balanceDue)}'
                                : (feeResult.refundAmount > 0 ? 'Refund: ${AppFormatters.formatCurrency(feeResult.refundAmount)}' : 'Settled'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: feeResult.balanceDue > 0 ? AppColors.danger : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail(bool isCar) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: isCar ? AppColors.primarySurface : AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isCar ? Icons.directions_car : Icons.two_wheeler,
        color: isCar ? AppColors.primary : AppColors.secondary,
        size: 28,
      ),
    );
  }
}
