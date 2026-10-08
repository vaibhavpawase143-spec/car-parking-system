import 'package:flutter/material.dart';
import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/parking_record_model.dart';
import '../../../models/payment_transaction_model.dart';
import '../../../models/shift_model.dart';
import '../../../models/vehicle_type.dart';
import '../../../services/admin_service.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/report_export_service.dart';
import '../../../services/shift_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/status_badge.dart';

enum ReportPeriod { today, last7Days, last30Days, thisYear, custom }

/// Admin Reports Hub Screen:
/// Simplified to focus purely on "What happened in the parking operation during the selected period?"
/// 1. Parking Summary (Total Entries, Total Exits, Currently Parked, Total Collection + Vehicle Type Breakdown)
/// 2. Guard-wise Report (Dropdown, Default to active shift guard, auto-rotation reactive, high-level summary)
/// 3. Parking Capacity (Four-Wheeler, Two-Wheeler, Total Occupied / Available)
/// 4. Vehicle Report (Search, Filter Type/Status, Sort, Simple Vehicle Cards, Detail Dialog)
/// 5. Export / PDF / Thermal Print actions
class AdminReportsHubScreen extends StatefulWidget {
  const AdminReportsHubScreen({super.key});

  @override
  State<AdminReportsHubScreen> createState() => _AdminReportsHubScreenState();
}

class _AdminReportsHubScreenState extends State<AdminReportsHubScreen> {
  final _adminService = AdminService();
  final _dashboardService = DashboardService();
  final _exportService = ReportExportService.instance;
  final _shiftService = ShiftService.instance;

  // Period state
  ReportPeriod _selectedPeriod = ReportPeriod.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  DateTime? _appliedCustomStartDate;
  DateTime? _appliedCustomEndDate;

  // Guard-wise Report State
  String? _selectedGuardUid;
  String? _lastActiveShiftId;
  bool _isManualGuardSelection = false;

  // Vehicle Report Search, Filter, Sort
  final _vehicleSearchController = TextEditingController();
  String _vehicleSearch = '';
  String _vehicleTypeFilter = 'all'; // 'all', 'FOUR_WHEELER', 'TWO_WHEELER'
  String _vehicleStatusFilter = 'all'; // 'all', 'ACTIVE', 'EXITED'
  String _vehicleSort = 'newest'; // 'newest', 'oldest'

  @override
  void dispose() {
    _vehicleSearchController.dispose();
    super.dispose();
  }

  (DateTime start, DateTime end) get _currentDateRange {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case ReportPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case ReportPeriod.last7Days:
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case ReportPeriod.last30Days:
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case ReportPeriod.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
      case ReportPeriod.custom:
        if (_appliedCustomStartDate != null && _appliedCustomEndDate != null) {
          final start = DateTime(
            _appliedCustomStartDate!.year,
            _appliedCustomStartDate!.month,
            _appliedCustomStartDate!.day,
          );
          final end = DateTime(
            _appliedCustomEndDate!.year,
            _appliedCustomEndDate!.month,
            _appliedCustomEndDate!.day,
            23, 59, 59, 999,
          );
          return (start, end);
        }
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start, end);
    }
  }

  String get _periodLabel {
    final range = _currentDateRange;
    switch (_selectedPeriod) {
      case ReportPeriod.today:
        return '${AppStrings.today} (${AppFormatters.formatDate(range.$1)})';
      case ReportPeriod.last7Days:
        return '${AppStrings.last7Days} (${AppFormatters.formatDate(range.$1)} - ${AppFormatters.formatDate(range.$2)})';
      case ReportPeriod.last30Days:
        return '${AppStrings.last30Days} (${AppFormatters.formatDate(range.$1)} - ${AppFormatters.formatDate(range.$2)})';
      case ReportPeriod.thisYear:
        return '${AppStrings.thisYear} (${AppFormatters.formatDate(range.$1)} - ${AppFormatters.formatDate(range.$2)})';
      case ReportPeriod.custom:
        return '${AppFormatters.formatDate(range.$1)} - ${AppFormatters.formatDate(range.$2)}';
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  double _getRecordAmount(ParkingRecord rec) {
    if (rec.finalCharge != null && rec.finalCharge! > 0) {
      return rec.finalCharge!;
    }
    if (rec.paidAmount != null && rec.paidAmount! > 0) {
      return rec.paidAmount!;
    }
    if (rec.advanceAmount > 0) {
      return rec.advanceAmount;
    }
    if (rec.grossCharge != null && rec.grossCharge! > 0) {
      return rec.grossCharge!;
    }
    return 0.0;
  }

  // --- Export Actions ---

  Future<void> _exportCsv({
    required List<ParkingRecord> records,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final headers = [
        'Ticket #',
        'Vehicle No',
        'Vehicle Type',
        'Entry Time',
        'Exit Time',
        'Duration',
        'Amount (INR)',
        'Status',
        'Entry Guard',
        'Exit Guard',
        'Shift',
      ];
      final rows = records.map((r) {
        final duration = r.isExited && r.exitTime != null
            ? r.exitTime!.difference(r.entryTime)
            : DateTime.now().difference(r.entryTime);
        final amt = _getRecordAmount(r);
        final shift = r.entryShift.isNotEmpty ? r.entryShift : (r.exitShift ?? '');
        return [
          r.ticketNumber,
          r.vehicleNumber,
          r.vehicleType.displayName,
          AppFormatters.formatDateTime(r.entryTime),
          r.exitTime != null ? AppFormatters.formatDateTime(r.exitTime!) : '',
          _formatDuration(duration),
          amt.toStringAsFixed(2),
          r.isExited ? 'Exited' : 'Currently Parked',
          r.entryGuardName,
          r.exitGuardName ?? '',
          shift,
        ];
      }).toList();

      final ok = await _exportService.exportCsv(
        reportTitle: 'Reports_Hub_Vehicle_Report_${_selectedPeriod.name}',
        headers: headers,
        rows: rows,
      );
      if (ok) {
        messenger.showSnackBar(const SnackBar(content: Text('Vehicle report exported to CSV successfully.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to export CSV: $e')));
    }
  }

  Future<void> _exportPdf({
    required List<ParkingRecord> records,
    required int entries,
    required int exits,
    required int currentlyParked,
    required double totalCollection,
    required CapacityData cap,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final range = _currentDateRange;
      final headers = ['Ticket #', 'Vehicle No', 'Type', 'Entry Time', 'Exit Time', 'Duration', 'Amount', 'Status', 'Guard'];
      final rows = records.map((r) {
        final duration = r.isExited && r.exitTime != null
            ? r.exitTime!.difference(r.entryTime)
            : DateTime.now().difference(r.entryTime);
        final amt = _getRecordAmount(r);
        return [
          '#${r.ticketNumber}',
          r.vehicleNumber,
          r.vehicleType.displayName,
          AppFormatters.formatDateTime(r.entryTime),
          r.exitTime != null ? AppFormatters.formatDateTime(r.exitTime!) : '—',
          _formatDuration(duration),
          AppFormatters.formatCurrency(amt),
          r.isExited ? 'Exited' : 'Currently Parked',
          r.entryGuardName,
        ];
      }).toList();

      final ok = await _exportService.printReportPdf(
        reportTitle: 'Parking & Vehicle Report ($_periodLabel)',
        date: range.$1,
        headers: headers,
        rows: rows,
        summaryTotals: {
          'Total Entries': '$entries',
          'Total Exits': '$exits',
          'Currently Parked': '$currentlyParked',
          'Total Collection': AppFormatters.formatCurrency(totalCollection),
          'Four-Wheeler Capacity': '${cap.carOccupied}/${cap.carTotal} (${cap.carAvailable} Available)',
          'Two-Wheeler Capacity': '${cap.twoWheelerOccupied}/${cap.twoWheelerTotal} (${cap.twoWheelerAvailable} Available)',
          'Total Capacity': '${cap.carOccupied + cap.twoWheelerOccupied}/${cap.carTotal + cap.twoWheelerTotal} (${cap.carAvailable + cap.twoWheelerAvailable} Available)',
        },
      );
      if (ok) {
        messenger.showSnackBar(const SnackBar(content: Text('PDF / Print document prepared.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to print PDF: $e')));
    }
  }

  Future<void> _exportThermal({
    required int entries,
    required int exits,
    required double cash,
    required double upi,
    required double totalCollection,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final range = _currentDateRange;
      final ok = await _exportService.printThermalSummary(
        date: range.$1,
        cash: cash,
        upi: upi,
        netTotal: totalCollection,
        entries: entries,
        exits: exits,
      );
      if (ok) {
        messenger.showSnackBar(const SnackBar(content: Text('Thermal summary slip sent to printer.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Thermal printing failed: $e')));
    }
  }

  // --- Main Build ---

  @override
  Widget build(BuildContext context) {
    final range = _currentDateRange;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<CapacityData>(
        stream: _dashboardService.watchCapacity(),
        builder: (context, capSnapshot) {
          final cap = capSnapshot.data ??
              const CapacityData(
                carTotal: 50,
                carOccupied: 0,
                twoWheelerTotal: 100,
                twoWheelerOccupied: 0,
              );

          return StreamBuilder<List<PaymentTransactionModel>>(
            stream: _adminService.watchPaymentTransactions(
              startDate: range.$1,
              endDate: range.$2,
            ),
            builder: (context, txnsSnapshot) {
              final txns = txnsSnapshot.data ?? [];
              double cashColl = 0.0;
              double upiColl = 0.0;
              for (final t in txns) {
                if (t.isAdvance || t.isFinal) {
                  if (t.isUpi) {
                    upiColl += t.amount;
                  } else {
                    cashColl += t.amount;
                  }
                } else if (t.isRefund) {
                  if (t.isUpi) {
                    upiColl -= t.amount;
                  } else {
                    cashColl -= t.amount;
                  }
                }
              }
              final netCash = cashColl < 0 ? 0.0 : cashColl;
              final netUpi = upiColl < 0 ? 0.0 : upiColl;
              final totalCollection = (netCash + netUpi) < 0 ? 0.0 : (netCash + netUpi);

              return StreamBuilder<List<ParkingRecord>>(
                stream: _adminService.watchParkingRecords(
                  startDate: range.$1,
                  endDate: range.$2,
                ),
                builder: (context, recordsSnapshot) {
                  if (recordsSnapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.unableToLoadData,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: Text(AppStrings.tryAgain),
                          ),
                        ],
                      ),
                    );
                  }

                  if (recordsSnapshot.connectionState == ConnectionState.waiting && !recordsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allRecords = recordsSnapshot.data ?? [];

                  // Vehicle Entries during the period
                  final periodEntries = allRecords.where((r) =>
                      !r.entryTime.isBefore(range.$1) && !r.entryTime.isAfter(range.$2)).toList();
                  final entriesCount = periodEntries.length;
                  final twoWheelerEntries = periodEntries.where((r) => r.vehicleType == VehicleType.twoWheeler).length;
                  final fourWheelerEntries = periodEntries.where((r) => r.vehicleType == VehicleType.fourWheeler).length;

                  // Vehicle Exits during the period
                  final periodExits = allRecords.where((r) =>
                      r.exitTime != null && !r.exitTime!.isBefore(range.$1) && !r.exitTime!.isAfter(range.$2)).toList();
                  final exitsCount = periodExits.length;
                  final twoWheelerExits = periodExits.where((r) => r.vehicleType == VehicleType.twoWheeler).length;
                  final fourWheelerExits = periodExits.where((r) => r.vehicleType == VehicleType.fourWheeler).length;

                  // Currently Parked from single authoritative source of truth
                  final currentlyParked = cap.carOccupied + cap.twoWheelerOccupied;

                  // Filtered and sorted records for Vehicle Report
                  final filteredRecords = _filterAndSortVehicles(allRecords);

                  return StreamBuilder<List<GuardModel>>(
                    stream: _adminService.watchAllGuards(),
                    builder: (context, guardsSnapshot) {
                      final guards = guardsSnapshot.data ?? [];

                      return StreamBuilder<List<ShiftModel>>(
                        stream: _shiftService.watchAllShifts(),
                        builder: (context, shiftsSnapshot) {
                          final shifts = shiftsSnapshot.data ?? [];

                          // Determine currently active shifts based on authoritative Shift Management rules:
                          // Status must be ACTIVE, actualEndTime is null, not cancelled/completed,
                          // and current time falls within operational period (respecting overnight shifts).
                          final now = DateTime.now();
                          final activeShifts = shifts.where((s) {
                            if (s.isCancelled || s.isCompleted) return false;
                            if (s.actualEndTime != null) return false;
                            if (s.status.toUpperCase().trim() != 'ACTIVE') return false;

                            final opStart = s.actualStartTime ?? s.startTime;
                            final opEnd = s.endTime;
                            return !now.isBefore(opStart) && !now.isAfter(opEnd);
                          }).toList();

                          final hasMultipleActiveShifts = activeShifts.length > 1;
                          ShiftModel? currentActiveShift;
                          if (activeShifts.length == 1) {
                            currentActiveShift = activeShifts.first;
                          }

                          // When active operational shift changes (e.g. shift rotation),
                          // automatically follow the new active shift guard.
                          final currentActiveShiftId = currentActiveShift?.shiftId;
                          if (currentActiveShiftId != _lastActiveShiftId) {
                            _lastActiveShiftId = currentActiveShiftId;
                            _isManualGuardSelection = false;
                          }

                          if (!_isManualGuardSelection) {
                            if (currentActiveShift != null) {
                              final match = guards.where((g) => ShiftService.matchesGuard(currentActiveShift!, g.uid, g.email, g.name)).firstOrNull;
                              if (match != null) {
                                _selectedGuardUid = match.uid;
                              } else {
                                _selectedGuardUid = currentActiveShift.guardUid?.isNotEmpty == true
                                    ? currentActiveShift.guardUid
                                    : (currentActiveShift.guardId.isNotEmpty ? currentActiveShift.guardId : currentActiveShift.guardName);
                              }
                            } else {
                              _selectedGuardUid = null;
                            }
                          }

                          // Resolve the selected GuardModel
                          GuardModel? selectedGuard = guards.where((g) => g.uid == _selectedGuardUid).firstOrNull;
                          if (selectedGuard == null && _selectedGuardUid != null) {
                            selectedGuard = guards.where((g) => g.name.toLowerCase() == _selectedGuardUid!.toLowerCase()).firstOrNull;
                          }

                          final effectiveGuardUid = selectedGuard?.uid;

                          // Compute Guard-wise summary from the period transactions
                          double guardCash = 0.0;
                          double guardUpi = 0.0;
                          int guardTransactionsCount = 0;
                          if (selectedGuard != null) {
                            final guardTxns = txns.where((t) {
                              final uidMatches = selectedGuard!.uid.isNotEmpty &&
                                  t.guardUid.isNotEmpty &&
                                  (t.guardUid == selectedGuard.uid || t.guardUid.toLowerCase() == selectedGuard.uid.toLowerCase());
                              final nameMatches = selectedGuard.name.isNotEmpty &&
                                  t.guardName.isNotEmpty &&
                                  t.guardName.toLowerCase() == selectedGuard.name.toLowerCase();
                              return uidMatches || nameMatches;
                            }).toList();

                            for (final t in guardTxns) {
                              if (t.isAdvance || t.isFinal) {
                                if (t.isUpi) {
                                  guardUpi += t.amount;
                                } else {
                                  guardCash += t.amount;
                                }
                              } else if (t.isRefund) {
                                if (t.isUpi) {
                                  guardUpi -= t.amount;
                                } else {
                                  guardCash -= t.amount;
                                }
                              }
                            }
                            guardTransactionsCount = guardTxns.length;
                          }

                          final guardNetCash = guardCash < 0 ? 0.0 : guardCash;
                          final guardNetUpi = guardUpi < 0 ? 0.0 : guardUpi;
                          final guardTotalCollection = (guardNetCash + guardNetUpi) < 0 ? 0.0 : (guardNetCash + guardNetUpi);

                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Section 1: Header, Period Selector & Export Actions
                                _buildHeaderAndPeriodSection(
                                  records: filteredRecords,
                                  entries: entriesCount,
                                  exits: exitsCount,
                                  currentlyParked: currentlyParked,
                                  totalCollection: totalCollection,
                                  cash: netCash,
                                  upi: netUpi,
                                  cap: cap,
                                ),
                                const SizedBox(height: 16),

                                // Section 2: Parking Summary (with Vehicle-Type Breakdown)
                                _buildParkingSummarySection(
                                  entries: entriesCount,
                                  exits: exitsCount,
                                  currentlyParked: currentlyParked,
                                  totalCollection: totalCollection,
                                  twoWheelerEntries: twoWheelerEntries,
                                  fourWheelerEntries: fourWheelerEntries,
                                  twoWheelerExits: twoWheelerExits,
                                  fourWheelerExits: fourWheelerExits,
                                ),
                                const SizedBox(height: 16),

                                // Section 3: Guard-wise Report (Dropdown, Active Shift Default, Simple Metrics)
                                _buildGuardWiseReportSection(
                                  guards: guards,
                                  selectedGuard: selectedGuard,
                                  effectiveGuardUid: effectiveGuardUid,
                                  hasMultipleActiveShifts: hasMultipleActiveShifts,
                                  totalCollection: guardTotalCollection,
                                  cash: guardNetCash,
                                  upi: guardNetUpi,
                                  transactions: guardTransactionsCount,
                                  onGuardSelected: (uid) {
                                    setState(() {
                                      _selectedGuardUid = uid;
                                      _isManualGuardSelection = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Section 4: Parking Capacity
                                _buildParkingCapacitySection(cap: cap),
                                const SizedBox(height: 16),

                                // Section 5: Vehicle Report
                                _buildVehicleReportSection(records: filteredRecords),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- Pipeline for Vehicle Report ---

  List<ParkingRecord> _filterAndSortVehicles(List<ParkingRecord> all) {
    var list = List<ParkingRecord>.from(all);

    // 1. Search (Vehicle / Ticket / Guard)
    if (_vehicleSearch.isNotEmpty) {
      final q = _vehicleSearch.toLowerCase();
      final qNorm = _vehicleSearch.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
      list = list.where((r) {
        final vehNorm = r.vehicleNumber.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();
        return vehNorm.contains(qNorm) ||
            r.vehicleNumber.toLowerCase().contains(q) ||
            r.ticketNumber.toLowerCase().contains(q) ||
            r.ticketId.toLowerCase().contains(q) ||
            r.entryGuardName.toLowerCase().contains(q) ||
            (r.exitGuardName != null && r.exitGuardName!.toLowerCase().contains(q));
      }).toList();
    }

    // 2. Vehicle Type Filter
    if (_vehicleTypeFilter == 'FOUR_WHEELER') {
      list = list.where((r) => r.vehicleType == VehicleType.fourWheeler).toList();
    } else if (_vehicleTypeFilter == 'TWO_WHEELER') {
      list = list.where((r) => r.vehicleType == VehicleType.twoWheeler).toList();
    }

    // 3. Status Filter
    if (_vehicleStatusFilter == 'ACTIVE') {
      list = list.where((r) => !r.isExited).toList();
    } else if (_vehicleStatusFilter == 'EXITED') {
      list = list.where((r) => r.isExited).toList();
    }

    // 4. Sort
    if (_vehicleSort == 'oldest') {
      list.sort((a, b) => a.entryTime.compareTo(b.entryTime));
    } else {
      list.sort((a, b) => b.entryTime.compareTo(a.entryTime));
    }

    return list;
  }

  // --- UI Components ---

  Widget _buildHeaderAndPeriodSection({
    required List<ParkingRecord> records,
    required int entries,
    required int exits,
    required int currentlyParked,
    required double totalCollection,
    required double cash,
    required double upi,
    required CapacityData cap,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isWideHeader = headerConstraints.maxWidth > 420;
              final titleCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.reportsHub,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _periodLabel,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              );

              final actionBtns = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.download, size: 20, color: AppColors.primary),
                    tooltip: 'Export CSV',
                    onPressed: () => _exportCsv(records: records),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 20, color: AppColors.primary),
                    tooltip: 'Print / Save PDF',
                    onPressed: () => _exportPdf(
                      records: records,
                      entries: entries,
                      exits: exits,
                      currentlyParked: currentlyParked,
                      totalCollection: totalCollection,
                      cap: cap,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.print, size: 20, color: AppColors.accent),
                    tooltip: 'Print 58mm Thermal Summary',
                    onPressed: () => _exportThermal(
                      entries: entries,
                      exits: exits,
                      cash: cash,
                      upi: upi,
                      totalCollection: totalCollection,
                    ),
                  ),
                ],
              );

              if (isWideHeader) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleCol),
                    actionBtns,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleCol,
                  const SizedBox(height: 8),
                  actionBtns,
                ],
              );
            },
          ),
          const Divider(height: 20),

          // Period Selector Dropdown
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                '${AppStrings.period}:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ReportPeriod>(
                    value: _selectedPeriod,
                    isDense: true,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    items: [
                      DropdownMenuItem(value: ReportPeriod.today, child: Text(AppStrings.today)),
                      DropdownMenuItem(value: ReportPeriod.last7Days, child: Text(AppStrings.last7Days)),
                      DropdownMenuItem(value: ReportPeriod.last30Days, child: Text(AppStrings.last30Days)),
                      DropdownMenuItem(value: ReportPeriod.thisYear, child: Text(AppStrings.thisYear)),
                      DropdownMenuItem(value: ReportPeriod.custom, child: Text(AppStrings.customDateRange)),
                    ],
                    onChanged: (p) {
                      if (p != null) {
                        setState(() {
                          _selectedPeriod = p;
                          if (p == ReportPeriod.custom) {
                            final now = DateTime.now();
                            _customStartDate ??= now.subtract(const Duration(days: 7));
                            _customEndDate ??= now;
                            _appliedCustomStartDate ??= _customStartDate;
                            _appliedCustomEndDate ??= _customEndDate;
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          // Custom Date Range Pickers (shown when Custom Date Range is selected)
          if (_selectedPeriod == ReportPeriod.custom) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(
                      '${AppStrings.from}: ${_customStartDate != null ? AppFormatters.formatDate(_customStartDate!) : ""}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _customStartDate ?? DateTime.now(),
                        firstDate: DateTime(2025, 1, 1),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _customStartDate = picked);
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 14),
                    label: Text(
                      '${AppStrings.to}: ${_customEndDate != null ? AppFormatters.formatDate(_customEndDate!) : ""}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _customEndDate ?? DateTime.now(),
                        firstDate: DateTime(2025, 1, 1),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _customEndDate = picked);
                      }
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_customStartDate != null && _customEndDate != null) {
                        if (_customStartDate!.isAfter(_customEndDate!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('From Date cannot be after To Date')),
                          );
                          return;
                        }
                        setState(() {
                          _appliedCustomStartDate = _customStartDate;
                          _appliedCustomEndDate = _customEndDate;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: Text(AppStrings.apply, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParkingSummarySection({
    required int entries,
    required int exits,
    required int currentlyParked,
    required double totalCollection,
    required int twoWheelerEntries,
    required int fourWheelerEntries,
    required int twoWheelerExits,
    required int fourWheelerExits,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assessment_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                AppStrings.parkingSummary,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const Divider(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              final summaryItems = [
                _buildSummaryItem(AppStrings.totalEntries, '$entries', AppColors.primary),
                _buildSummaryItem(AppStrings.totalExits, '$exits', AppColors.textPrimary),
                _buildSummaryItem(AppStrings.currentlyParked, '$currentlyParked', AppColors.accent),
                _buildSummaryItem(AppStrings.totalCollection, AppFormatters.formatCurrency(totalCollection), AppColors.success),
              ];
              if (isWide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: summaryItems,
                );
              }
              return Wrap(
                spacing: 24,
                runSpacing: 14,
                children: summaryItems,
              );
            },
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 36,
            runSpacing: 14,
            children: [
              // Vehicle Entries Breakdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.login, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.vehicleEntries,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.two_wheeler, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${AppStrings.twoWheeler}: ',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        '$twoWheelerEntries',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_car, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${AppStrings.fourWheeler}: ',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        '$fourWheelerEntries',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),

              // Vehicle Exits Breakdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.logout, size: 16, color: AppColors.textPrimary),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.vehicleExits,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.two_wheeler, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${AppStrings.twoWheeler}: ',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        '$twoWheelerExits',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_car, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${AppStrings.fourWheeler}: ',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        '$fourWheelerExits',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuardWiseReportSection({
    required List<GuardModel> guards,
    required GuardModel? selectedGuard,
    required String? effectiveGuardUid,
    required bool hasMultipleActiveShifts,
    required double totalCollection,
    required double cash,
    required double upi,
    required int transactions,
    required ValueChanged<String?> onGuardSelected,
  }) {
    final seenUids = <String>{};
    final items = <DropdownMenuItem<String?>>[];

    // If no guard is currently selected, add the "No Active Guard" placeholder
    if (selectedGuard == null) {
      items.add(DropdownMenuItem<String?>(
        value: null,
        child: Text(
          AppStrings.noActiveGuard,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13),
        ),
      ));
    }

    for (final g in guards) {
      if (seenUids.add(g.uid)) {
        items.add(DropdownMenuItem<String?>(
          value: g.uid,
          child: Text(
            g.name,
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13),
          ),
        ));
      }
    }

    if (selectedGuard != null && !seenUids.contains(selectedGuard.uid)) {
      items.add(DropdownMenuItem<String?>(
        value: selectedGuard.uid,
        child: Text(
          selectedGuard.name,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13),
        ),
      ));
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;

              final titleRow = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      AppStrings.guardWiseReport,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );

              final dropdownRow = Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${AppStrings.guard}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.background,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: effectiveGuardUid,
                        isDense: true,
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        items: items,
                        onChanged: onGuardSelected,
                      ),
                    ),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleRow),
                    dropdownRow,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleRow,
                  const SizedBox(height: 10),
                  dropdownRow,
                ],
              );
            },
          ),
          const Divider(height: 20),

          // Anomaly Warning if multiple active shifts detected
          if (hasMultipleActiveShifts)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.multipleActiveShiftsWarning,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          if (selectedGuard == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off_outlined, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        AppStrings.noGuardActiveShift,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                final summaryItems = [
                  _buildSummaryItem(AppStrings.totalCollection, AppFormatters.formatCurrency(totalCollection), AppColors.success),
                  _buildSummaryItem(AppStrings.cashLabel, AppFormatters.formatCurrency(cash), AppColors.textPrimary),
                  _buildSummaryItem(AppStrings.upiLabel, AppFormatters.formatCurrency(upi), AppColors.accent),
                  _buildSummaryItem(AppStrings.transactions, '$transactions', AppColors.primary),
                ];

                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: summaryItems,
                  );
                }

                return Wrap(
                  spacing: 24,
                  runSpacing: 14,
                  children: summaryItems,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildParkingCapacitySection({required CapacityData cap}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_parking_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.parkingCapacity,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _buildCapacityItem(
                title: AppStrings.fourWheeler,
                occupied: cap.carOccupied,
                total: cap.carTotal,
                available: cap.carAvailable,
              ),
              _buildCapacityItem(
                title: AppStrings.twoWheeler,
                occupied: cap.twoWheelerOccupied,
                total: cap.twoWheelerTotal,
                available: cap.twoWheelerAvailable,
              ),
              _buildCapacityItem(
                title: AppStrings.occupied,
                occupied: cap.carOccupied + cap.twoWheelerOccupied,
                total: cap.carTotal + cap.twoWheelerTotal,
                available: cap.carAvailable + cap.twoWheelerAvailable,
                isTotal: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityItem({
    required String title,
    required int occupied,
    required int total,
    required int available,
    bool isTotal = false,
  }) {
    final pct = total > 0 ? (occupied / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                    color: isTotal ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$occupied / $total',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 0.9 ? AppColors.danger : (pct >= 0.75 ? AppColors.accent : AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$available ${AppStrings.available}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleReportSection({
    required List<ParkingRecord> records,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car_outlined, color: AppColors.primaryDark, size: 20),
              const SizedBox(width: 8),
              Text(
                AppStrings.vehicleReport,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Box
          TextField(
            controller: _vehicleSearchController,
            decoration: InputDecoration(
              hintText: AppStrings.searchVehicleTicketGuardHint,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _vehicleSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() {
                        _vehicleSearchController.clear();
                        _vehicleSearch = '';
                      }),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => setState(() => _vehicleSearch = v.trim()),
          ),
          const SizedBox(height: 10),

          // Filter & Sort Row
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              // Vehicle Type Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _vehicleTypeFilter,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text(AppStrings.typeAll)),
                      DropdownMenuItem(value: 'FOUR_WHEELER', child: Text(AppStrings.fourWheeler)),
                      DropdownMenuItem(value: 'TWO_WHEELER', child: Text(AppStrings.twoWheeler)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _vehicleTypeFilter = v);
                    },
                  ),
                ),
              ),

              // Status Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _vehicleStatusFilter,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text(AppStrings.statusAll)),
                      DropdownMenuItem(value: 'ACTIVE', child: Text(AppStrings.parkedLive)),
                      DropdownMenuItem(value: 'EXITED', child: Text(AppStrings.exited)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _vehicleStatusFilter = v);
                    },
                  ),
                ),
              ),

              // Sort Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _vehicleSort,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    items: [
                      DropdownMenuItem(value: 'newest', child: Text(AppStrings.sortNewest)),
                      DropdownMenuItem(value: 'oldest', child: Text(AppStrings.sortOldest)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _vehicleSort = v);
                    },
                  ),
                ),
              ),

              Text(
                '(${records.length})',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Divider(height: 20),

          // Vehicle List
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_off, size: 36, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.noVehiclesFound,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final rec = records[index];
                final isExited = rec.isExited;
                final duration = isExited && rec.exitTime != null
                    ? rec.exitTime!.difference(rec.entryTime)
                    : DateTime.now().difference(rec.entryTime);
                final amt = _getRecordAmount(rec);

                return InkWell(
                  onTap: () => _showVehicleDetailDialog(context, rec),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final isNarrow = cardConstraints.maxWidth < 540;

                        final iconWidget = Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isExited ? AppColors.surface : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            rec.vehicleType == VehicleType.twoWheeler
                                ? Icons.two_wheeler
                                : Icons.directions_car,
                            size: 20,
                            color: isExited ? AppColors.textSecondary : AppColors.primary,
                          ),
                        );

                        final statusBadge = StatusBadge(
                          label: isExited ? AppStrings.exited : AppStrings.currentlyParked,
                          type: isExited ? BadgeType.info : BadgeType.active,
                        );

                        final metadataWrap = Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              '${AppStrings.entryTime}: ${AppFormatters.formatTime(rec.entryTime)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            if (isExited && rec.exitTime != null)
                              Text(
                                '${AppStrings.exitTime}: ${AppFormatters.formatTime(rec.exitTime!)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            Text(
                              '${AppStrings.duration}: ${_formatDuration(duration)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            if (amt > 0)
                              Text(
                                '${AppStrings.amount}: ${AppFormatters.formatCurrency(amt)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                              ),
                          ],
                        );

                        if (isNarrow) {
                          // Mobile Layout: Top row with Icon + Vehicle Number + Status Badge, then Type Badge, then Metadata
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  iconWidget,
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      rec.vehicleNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  statusBadge,
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildVehicleTypeBadge(rec.vehicleType),
                              const SizedBox(height: 8),
                              metadataWrap,
                            ],
                          );
                        }

                        // Desktop Layout: Compact horizontal structure
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            iconWidget,
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          rec.vehicleNumber,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildVehicleTypeBadge(rec.vehicleType),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  metadataWrap,
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            statusBadge,
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- Vehicle Detail Dialog ---

  void _showVehicleDetailDialog(BuildContext context, ParkingRecord rec) {
    final isExited = rec.isExited;
    final duration = isExited && rec.exitTime != null
        ? rec.exitTime!.difference(rec.entryTime)
        : DateTime.now().difference(rec.entryTime);
    final amt = _getRecordAmount(rec);
    final paymentMethod = (rec.paymentMethod != null && rec.paymentMethod!.isNotEmpty)
        ? rec.paymentMethod!.toUpperCase()
        : (rec.advancePaymentMethod.isNotEmpty ? rec.advancePaymentMethod.toUpperCase() : '—');
    final shift = rec.entryShift.isNotEmpty ? rec.entryShift : (rec.exitShift ?? '—');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              rec.vehicleType == VehicleType.twoWheeler ? Icons.two_wheeler : Icons.directions_car,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                rec.vehicleNumber,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(AppStrings.ticketNumber, '#${rec.ticketNumber}'),
                _buildDetailRow(AppStrings.vehicleNumber, rec.vehicleNumber),
                _buildDetailRow(AppStrings.vehicleType, rec.vehicleType.displayName),
                _buildDetailRow(AppStrings.status, isExited ? AppStrings.exited : AppStrings.currentlyParked),
                _buildDetailRow(AppStrings.entryDateTime, AppFormatters.formatDateTime(rec.entryTime)),
                _buildDetailRow(AppStrings.exitDateTime, rec.exitTime != null ? AppFormatters.formatDateTime(rec.exitTime!) : '—'),
                _buildDetailRow(AppStrings.duration, _formatDuration(duration)),
                _buildDetailRow(AppStrings.amount, AppFormatters.formatCurrency(amt)),
                _buildDetailRow(AppStrings.paymentMethod, paymentMethod),
                _buildDetailRow(AppStrings.entryGuard, rec.entryGuardName),
                _buildDetailRow(AppStrings.exitGuard, rec.exitGuardName ?? '—'),
                _buildDetailRow(AppStrings.shift, shift),
                const SizedBox(height: 12),
                if (rec.photoUrl != null && rec.photoUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      rec.photoUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.no_photography_outlined, size: 16, color: AppColors.textMuted),
                            const SizedBox(width: 8),
                            Text(
                              AppStrings.photoNoLongerAvailable,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.no_photography_outlined, size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.photoNoLongerAvailable,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.close),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeBadge(VehicleType type) {
    final isTwoWheeler = type == VehicleType.twoWheeler;
    final label = isTwoWheeler
        ? (AppLanguageController.instance.isMarathi ? AppStrings.twoWheeler : 'TWO-WHEELER')
        : (AppLanguageController.instance.isMarathi ? AppStrings.fourWheeler : 'FOUR-WHEELER');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isTwoWheeler
            ? AppColors.secondary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isTwoWheeler
              ? AppColors.secondary.withValues(alpha: 0.5)
              : AppColors.primary.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: isTwoWheeler ? AppColors.secondary : AppColors.primary,
        ),
      ),
    );
  }
}
