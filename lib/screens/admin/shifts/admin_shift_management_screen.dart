import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/shift_model.dart';
import '../../../models/shift_schedule_model.dart';
import '../../../services/settings_service.dart';
import '../../../services/shift_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/status_badge.dart';

/// Sort modes for Shift Management — always compare actual DateTime / string values.
enum ShiftSort {
  startTimeNewest,
  startTimeOldest,
  endTime,
  guardNameAZ,
  guardNameZA,
  durationDesc,
}

/// Admin Shift Management Screen.
/// Admin controls and assigns One-Day and Recurring shift schedules.
class AdminShiftManagementScreen extends StatefulWidget {
  const AdminShiftManagementScreen({super.key});

  @override
  State<AdminShiftManagementScreen> createState() => _AdminShiftManagementScreenState();
}

class _AdminShiftManagementScreenState extends State<AdminShiftManagementScreen>
    with SingleTickerProviderStateMixin {
  final _shiftService = ShiftService();
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ShiftSort _shiftSort = ShiftSort.startTimeNewest;

  // Schedule filtering & sorting states
  String _scheduleFilter = 'ALL';
  String _scheduleSort = 'startDate';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateShiftSheet([ShiftModel? shiftToEdit]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ShiftFormSheet(
        shiftToEdit: shiftToEdit,
        shiftService: _shiftService,
      ),
    );
  }

  Future<void> _handleCancelShift(ShiftModel shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.cancelShift),
        content: Text('Are you sure you want to cancel the shift assigned to ${shift.guardName} on ${AppFormatters.formatDate(shift.shiftDate)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.cancelShift, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _shiftService.cancelUpcomingShift(shift.shiftId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.shiftCancelledSuccess)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppStrings.error}: $e')),
          );
        }
      }
    }
  }

  Future<void> _openReassignGuardDialog(ShiftModel shift) async {
    GuardModel? selectedGuard;
    try {
      final snap = await FirebaseFirestore.instance.collection('guards').get();
      final guardsList = snap.docs
          .map((d) => GuardModel.fromFirestore(d))
          .where((g) => g.isActive && g.uid != shift.guardId)
          .toList();

      if (!mounted) return;
      if (guardsList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other active guards available to reassign.')),
        );
        return;
      }

      final confirmed = await showDialog<GuardModel>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDlgState) {
              return AlertDialog(
                title: Text(AppStrings.reassignGuard),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reassign shift on ${AppFormatters.formatDate(shift.shiftDate)} (${AppFormatters.formatTime(shift.startTime)} - ${AppFormatters.formatTime(shift.endTime)}) from ${shift.guardName} to another guard:',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<GuardModel>(
                      hint: Text(AppStrings.selectGuard),
                      items: guardsList.map((g) {
                        return DropdownMenuItem(value: g, child: Text('${g.name} (${g.email})'));
                      }).toList(),
                      onChanged: (val) {
                        setDlgState(() => selectedGuard = val);
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: Text(AppStrings.cancel),
                  ),
                  ElevatedButton(
                    onPressed: selectedGuard == null ? null : () => Navigator.pop(ctx, selectedGuard),
                    child: Text(AppStrings.reassignGuard),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != null && mounted) {
        try {
          await _shiftService.reassignShiftGuard(
            shiftId: shift.shiftId,
            newGuardId: confirmed.uid,
            newGuardUid: confirmed.uid,
            newGuardEmail: confirmed.email,
            newGuardName: confirmed.name,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppStrings.guardReassignedSuccess)),
            );
          }
        } on OverlappingShiftException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppStrings.shiftOverlapError),
                backgroundColor: AppColors.danger,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${AppStrings.error}: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.error}: $e')),
        );
      }
    }
  }

  Future<void> _openSkipDateDialog(ShiftScheduleModel schedule) async {
    DateTime selectedDate = schedule.startDate.isAfter(DateTime.now())
        ? schedule.startDate
        : DateTime.now();
    final reasonController = TextEditingController(text: 'Holiday');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(AppStrings.skipDate),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Skip a shift date for ${schedule.guardName} (${schedule.weekdaysFormatted}):',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: schedule.startDate.isAfter(DateTime.now())
                        ? schedule.startDate
                        : DateTime.now(),
                    lastDate: schedule.endDate,
                  );
                  if (picked != null) {
                    setDlgState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppFormatters.formatDate(selectedDate)),
                      const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for skipping',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.skipDate, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _shiftService.skipScheduleDate(
          scheduleId: schedule.scheduleId,
          date: selectedDate,
          reason: reasonController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.skipDateSuccess)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppStrings.error}: $e')),
          );
        }
      }
    }
  }

  Future<void> _handlePauseResumeSchedule(ShiftScheduleModel schedule) async {
    try {
      if (schedule.isActive) {
        await _shiftService.pauseSchedule(schedule.scheduleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.schedulePausedSuccess)),
          );
        }
      } else {
        await _shiftService.resumeSchedule(schedule.scheduleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.scheduleResumedSuccess)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.error}: $e')),
        );
      }
    }
  }

  Future<void> _handleCancelSchedule(ShiftScheduleModel schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.cancel),
        content: Text(
          'Are you sure you want to cancel the recurring schedule for ${schedule.guardName} (${schedule.weekdaysFormatted})? Future unstarted shifts will be cancelled. Past and active shifts remain untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.cancel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _shiftService.cancelSchedule(schedule.scheduleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.scheduleCancelledSuccess)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppStrings.error}: $e')),
          );
        }
      }
    }
  }

  void _openScheduleDetailsDialog(ShiftScheduleModel schedule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.event_repeat, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(AppStrings.shiftSchedules, style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Guard Name', schedule.guardName),
                if (schedule.guardEmail != null) _buildDetailRow('Guard Email', schedule.guardEmail!),
                _buildDetailRow('Schedule ID', schedule.scheduleId),
                _buildDetailRow('Status', schedule.status),
                _buildDetailRow('Duration', '${schedule.durationHours} Hours'),
                _buildDetailRow('Start Time', schedule.timeFormatted),
                _buildDetailRow('Repeat Days', schedule.weekdaysFormatted),
                _buildDetailRow('Date Range', '${AppFormatters.formatDate(schedule.startDate)} - ${AppFormatters.formatDate(schedule.endDate)}'),
                _buildDetailRow('Created By', schedule.createdBy),
                _buildDetailRow('Created At', AppFormatters.formatDate(schedule.createdAt)),
                const SizedBox(height: 12),
                const Divider(),
                const Text('Exceptions & Overrides', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                StreamBuilder<List<ScheduleExceptionModel>>(
                  stream: _shiftService.watchScheduleExceptions(schedule.scheduleId),
                  builder: (context, snap) {
                    final exceptions = snap.data ?? [];
                    if (exceptions.isEmpty) {
                      return const Text('No exceptions recorded.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
                    }
                    return Column(
                      children: exceptions.map((e) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${AppFormatters.formatDate(e.date)} (${e.type})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text(e.reason ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateShiftSheet(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          AppStrings.assignShift,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // Search + Sort header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '${AppStrings.search} guard name, email, shift ID...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              }),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<ShiftSort>(
                  initialValue: _shiftSort,
                  onSelected: (s) => setState(() => _shiftSort = s),
                  itemBuilder: (ctx) => [
                    _shiftSortItem(ShiftSort.startTimeNewest, AppStrings.startTimeNewest),
                    _shiftSortItem(ShiftSort.startTimeOldest, AppStrings.startTimeOldest),
                    _shiftSortItem(ShiftSort.endTime, AppStrings.endTimeSort),
                    _shiftSortItem(ShiftSort.guardNameAZ, AppStrings.guardAZ),
                    _shiftSortItem(ShiftSort.guardNameZA, AppStrings.guardZA),
                    _shiftSortItem(ShiftSort.durationDesc, AppStrings.durationLongestFirst),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sort, size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: AppStrings.todaysShifts),
                Tab(text: AppStrings.activeShifts),
                Tab(text: AppStrings.upcomingShifts),
                Tab(text: AppStrings.completedState),
                Tab(text: AppStrings.allShifts),
                Tab(text: AppStrings.shiftSchedules),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<ShiftModel>>(
              stream: _shiftService.watchAllShifts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                          const SizedBox(height: 12),
                          Text('${AppStrings.error}: ${snapshot.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: Text(AppStrings.retry),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allShifts = _filterAndSort(snapshot.data ?? []);
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final todayEnd = todayStart.add(const Duration(days: 1));

                final todaysShifts = allShifts.where((s) {
                  final isSameDate = s.shiftDate.year == now.year &&
                      s.shiftDate.month == now.month &&
                      s.shiftDate.day == now.day;
                  final isStartTimeToday = (s.startTime.isAfter(todayStart) || s.startTime.isAtSameMomentAs(todayStart)) &&
                      s.startTime.isBefore(todayEnd);
                  return isSameDate || isStartTimeToday || s.isActive;
                }).toList();

                final activeShifts = allShifts.where((s) => s.isActive).toList();
                final upcomingShifts = allShifts.where((s) => s.isUpcoming && !s.isCancelled).toList();
                final completedShifts = allShifts.where((s) => s.isCompleted && !s.isCancelled).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildShiftsList(todaysShifts, 'No shifts scheduled for today.'),
                    _buildShiftsList(activeShifts, 'No active shifts at this moment.'),
                    _buildShiftsList(upcomingShifts, 'No upcoming shifts assigned.'),
                    _buildShiftsList(completedShifts, 'No completed shifts yet.'),
                    _buildShiftsList(allShifts, 'No shift records found.'),
                    _buildSchedulesTab(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Shift Schedules Tab View with search, filter pills, sorting, and action cards.
  Widget _buildSchedulesTab() {
    return StreamBuilder<List<ShiftScheduleModel>>(
      stream: _shiftService.watchAllSchedules(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                  const SizedBox(height: 12),
                  Text('${AppStrings.error}: ${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text(AppStrings.retry),
                  ),
                ],
              ),
            ),
          );
        }

        var schedules = snapshot.data ?? [];

        // 1. Search query (guard name, schedule ID)
        if (_searchQuery.isNotEmpty) {
          schedules = schedules.where((s) {
            return s.guardName.toLowerCase().contains(_searchQuery) ||
                (s.guardEmail?.toLowerCase().contains(_searchQuery) ?? false) ||
                s.scheduleId.toLowerCase().contains(_searchQuery);
          }).toList();
        }

        // 2. Status filter
        if (_scheduleFilter != 'ALL') {
          schedules = schedules.where((s) => s.status.toUpperCase() == _scheduleFilter).toList();
        }

        // 3. Sort
        switch (_scheduleSort) {
          case 'startDate':
            schedules.sort((a, b) => b.startDate.compareTo(a.startDate));
            break;
          case 'endDate':
            schedules.sort((a, b) => b.endDate.compareTo(a.endDate));
            break;
          case 'guardName':
            schedules.sort((a, b) => a.guardName.toLowerCase().compareTo(b.guardName.toLowerCase()));
            break;
          case 'createdAt':
            schedules.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
        }

        return Column(
          children: [
            // Filter Pills & Sort Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildScheduleFilterChip('ALL', 'All'),
                          const SizedBox(width: 6),
                          _buildScheduleFilterChip('ACTIVE', AppStrings.activeState),
                          const SizedBox(width: 6),
                          _buildScheduleFilterChip('PAUSED', AppStrings.pause),
                          const SizedBox(width: 6),
                          _buildScheduleFilterChip('COMPLETED', AppStrings.completedState),
                          const SizedBox(width: 6),
                          _buildScheduleFilterChip('CANCELLED', AppStrings.cancelledState),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    initialValue: _scheduleSort,
                    onSelected: (val) => setState(() => _scheduleSort = val),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'startDate', child: Text('Start Date')),
                      const PopupMenuItem(value: 'endDate', child: Text('End Date')),
                      const PopupMenuItem(value: 'guardName', child: Text('Guard Name (A-Z)')),
                      const PopupMenuItem(value: 'createdAt', child: Text('Created Date')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.swap_vert, size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: schedules.isEmpty
                  ? Center(
                      child: Text(
                        AppStrings.noSchedulesFound,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                      itemCount: schedules.length,
                      itemBuilder: (ctx, idx) {
                        return _buildScheduleCard(schedules[idx]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScheduleFilterChip(String value, String label) {
    final isSelected = _scheduleFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      )),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      visualDensity: VisualDensity.compact,
      onSelected: (selected) {
        if (selected) setState(() => _scheduleFilter = value);
      },
    );
  }

  Widget _buildScheduleCard(ShiftScheduleModel schedule) {
    BadgeType badgeType;
    switch (schedule.status.toUpperCase()) {
      case 'ACTIVE':
        badgeType = BadgeType.active;
        break;
      case 'PAUSED':
        badgeType = BadgeType.warning;
        break;
      case 'COMPLETED':
        badgeType = BadgeType.info;
        break;
      case 'CANCELLED':
      default:
        badgeType = BadgeType.danger;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primarySurface,
                      child: const Icon(Icons.event_repeat, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.guardName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${AppFormatters.formatDate(schedule.startDate)} - ${AppFormatters.formatDate(schedule.endDate)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                StatusBadge(label: schedule.status, type: badgeType),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildTimeItem(
                    label: AppStrings.startTime,
                    value: schedule.timeFormatted,
                  ),
                ),
                Expanded(
                  child: _buildTimeItem(
                    label: AppStrings.duration,
                    value: AppStrings.formatShiftDuration(schedule.durationHours),
                  ),
                ),
                Expanded(
                  child: _buildTimeItem(
                    label: AppStrings.repeatOn,
                    value: schedule.weekdaysFormatted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _openScheduleDetailsDialog(schedule),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: Text(AppStrings.viewDetails, style: const TextStyle(fontSize: 12)),
                ),
                if (schedule.isActive) ...[
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.warning),
                    onPressed: () => _handlePauseResumeSchedule(schedule),
                    icon: const Icon(Icons.pause_circle_outline, size: 16),
                    label: Text(AppStrings.pause, style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    onPressed: () => _openSkipDateDialog(schedule),
                    icon: const Icon(Icons.event_busy, size: 16),
                    label: Text(AppStrings.skipDate, style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => _handleCancelSchedule(schedule),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(AppStrings.cancel, style: const TextStyle(fontSize: 12)),
                  ),
                ] else if (schedule.isPaused) ...[
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.success),
                    onPressed: () => _handlePauseResumeSchedule(schedule),
                    icon: const Icon(Icons.play_circle_outline, size: 16),
                    label: Text(AppStrings.resume, style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => _handleCancelSchedule(schedule),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(AppStrings.cancel, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Applies search filter + sort. Uses actual DateTime and string values — never formatted strings.
  List<ShiftModel> _filterAndSort(List<ShiftModel> raw) {
    var list = raw;
    if (_searchQuery.isNotEmpty) {
      list = list.where((s) {
        return s.guardName.toLowerCase().contains(_searchQuery) ||
            (s.guardEmail?.toLowerCase().contains(_searchQuery) ?? false) ||
            s.shiftId.toLowerCase().contains(_searchQuery);
      }).toList();
    }
    switch (_shiftSort) {
      case ShiftSort.startTimeNewest:
        list.sort((a, b) => b.startTime.compareTo(a.startTime));
        break;
      case ShiftSort.startTimeOldest:
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
        break;
      case ShiftSort.endTime:
        list.sort((a, b) => b.endTime.compareTo(a.endTime));
        break;
      case ShiftSort.guardNameAZ:
        list.sort((a, b) => a.guardName.toLowerCase().compareTo(b.guardName.toLowerCase()));
        break;
      case ShiftSort.guardNameZA:
        list.sort((a, b) => b.guardName.toLowerCase().compareTo(a.guardName.toLowerCase()));
        break;
      case ShiftSort.durationDesc:
        list.sort((a, b) => b.durationHours.compareTo(a.durationHours));
        break;
    }
    return list;
  }

  PopupMenuItem<ShiftSort> _shiftSortItem(ShiftSort value, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            _shiftSort == value ? Icons.check : Icons.circle_outlined,
            size: 16,
            color: _shiftSort == value ? AppColors.primary : Colors.transparent,
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildShiftsList(List<ShiftModel> list, String emptyMessage) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? AppStrings.noMatchingRecords : emptyMessage,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final shift = list[index];
        return _buildShiftAdminCard(shift);
      },
    );
  }

  Widget _buildShiftAdminCard(ShiftModel shift) {
    BadgeType badgeType;
    String statusStr = shift.effectiveStatus.displayName;

    switch (shift.effectiveStatus) {
      case ShiftStatus.active:
        badgeType = BadgeType.active;
        statusStr = AppStrings.activeState;
        break;
      case ShiftStatus.assigned:
        badgeType = BadgeType.info;
        statusStr = AppStrings.assigned;
        break;
      case ShiftStatus.completed:
        badgeType = BadgeType.active;
        statusStr = AppStrings.completedState;
        break;
      case ShiftStatus.cancelled:
        badgeType = BadgeType.danger;
        statusStr = AppStrings.cancelledState;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primarySurface,
                      child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.guardName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          AppFormatters.formatDate(shift.shiftDate),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                StatusBadge(label: statusStr.toUpperCase(), type: badgeType),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildTimeItem(
                    label: AppStrings.startTime,
                    value: AppFormatters.formatTime(shift.startTime),
                  ),
                ),
                Expanded(
                  child: _buildTimeItem(
                    label: AppStrings.endTime,
                    value: AppFormatters.formatTime(shift.endTime),
                  ),
                ),
                Expanded(
                  child: _buildTimeItem(
                    label: AppStrings.duration,
                    value: AppStrings.formatShiftDuration(shift.durationHours),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Live metrics
            StreamBuilder<ShiftStats>(
              stream: _shiftService.watchShiftStats(shift),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? ShiftStats.zero;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        '${AppStrings.entry}: ${stats.entriesCount}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        '${AppStrings.exit}: ${stats.exitsCount}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        '${AppStrings.collection}: ${AppFormatters.formatCurrency(stats.totalCollection)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.cashColor),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Admin edit/reassign/cancel actions for upcoming shifts only
            if (shift.isUpcoming && !shift.isCancelled) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openReassignGuardDialog(shift),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: Text(AppStrings.reassignGuard, style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _openCreateShiftSheet(shift),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(AppStrings.editShift, style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => _handleCancelShift(shift),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(AppStrings.cancelShift, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

enum _AssignmentType { oneDay, recurringSchedule }

/// Bottom Sheet Form for creating One-Day shifts or Recurring Shift Schedules.
class _ShiftFormSheet extends StatefulWidget {
  final ShiftModel? shiftToEdit;
  final ShiftService shiftService;

  const _ShiftFormSheet({this.shiftToEdit, required this.shiftService});

  @override
  State<_ShiftFormSheet> createState() => _ShiftFormSheetState();
}

class _ShiftFormSheetState extends State<_ShiftFormSheet> {
  final _firestore = FirebaseFirestore.instance;
  _AssignmentType _assignmentType = _AssignmentType.oneDay;

  GuardModel? _selectedGuard;
  DateTime _selectedDate = DateTime.now();
  DateTime _recurringStartDate = DateTime.now();
  DateTime _recurringEndDate = DateTime.now().add(const Duration(days: 30));
  TimeOfDay _selectedStartTime = const TimeOfDay(hour: 6, minute: 0);
  late int _durationHours;
  late List<int> _allowedDurations;

  List<int> _selectedWeekdays = [1, 2, 3, 4, 5]; // Mon - Fri default

  bool _isLoading = false;
  String? _errorMessage;
  List<GuardModel> _guards = [];

  @override
  void initState() {
    super.initState();
    final settings = SettingsService.instance.currentSettings;
    _allowedDurations = List<int>.from(ShiftModel.allowedShiftDurations);
    if (widget.shiftToEdit != null) {
      final s = widget.shiftToEdit!;
      _selectedDate = s.shiftDate;
      _selectedStartTime = TimeOfDay(hour: s.startTime.hour, minute: s.startTime.minute);
      _durationHours = s.durationHours;
      if (!_allowedDurations.contains(_durationHours)) {
        _allowedDurations = List<int>.from(_allowedDurations)..add(_durationHours);
        _allowedDurations.sort();
      }
    } else {
      _durationHours = settings.defaultShiftDurationHours;
      if (!_allowedDurations.contains(_durationHours)) {
        _durationHours = _allowedDurations.first;
      }
    }
    _loadGuards();
  }

  Future<void> _loadGuards() async {
    try {
      final snap = await _firestore.collection('guards').get();
      final guardsList = snap.docs.map((d) => GuardModel.fromFirestore(d)).where((g) => g.isActive).toList();
      if (mounted) {
        setState(() {
          _guards = guardsList;
          if (widget.shiftToEdit != null) {
            _selectedGuard = _guards.cast<GuardModel?>().firstWhere(
                  (g) => g?.uid == widget.shiftToEdit!.guardId,
                  orElse: () => null,
                );
          } else if (_guards.isNotEmpty) {
            _selectedGuard = _guards.first;
          }
        });
      }
    } catch (_) {}
  }

  DateTime _computeStartDateTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedStartTime.hour,
      _selectedStartTime.minute,
    );
  }

  DateTime _computeEndDateTime() {
    return _computeStartDateTime().add(Duration(hours: _durationHours));
  }

  Future<void> _handleSave() async {
    if (_selectedGuard == null) {
      setState(() {
        _errorMessage = 'Please select a guard.';
      });
      return;
    }

    if (_assignmentType == _AssignmentType.recurringSchedule && widget.shiftToEdit == null) {
      final cleanStart = DateTime(_recurringStartDate.year, _recurringStartDate.month, _recurringStartDate.day);
      final cleanEnd = DateTime(_recurringEndDate.year, _recurringEndDate.month, _recurringEndDate.day);
      if (cleanEnd.isBefore(cleanStart)) {
        setState(() {
          _errorMessage = AppStrings.endDateBeforeStartDateError;
        });
        return;
      }
      if (_selectedWeekdays.isEmpty) {
        setState(() {
          _errorMessage = AppStrings.atLeastOneWeekdayRequired;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        await widget.shiftService.createRecurringSchedule(
          guardId: _selectedGuard!.uid,
          guardUid: _selectedGuard!.uid,
          guardEmail: _selectedGuard!.email,
          guardName: _selectedGuard!.name,
          startDate: cleanStart,
          endDate: cleanEnd,
          startHour: _selectedStartTime.hour,
          startMinute: _selectedStartTime.minute,
          durationHours: _durationHours,
          weekdays: _selectedWeekdays,
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.scheduleCreatedSuccess)),
          );
        }
      } on OverlappingShiftException {
        if (mounted) {
          setState(() {
            _errorMessage = AppStrings.shiftOverlapError;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = '${AppStrings.error}: $e';
          });
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    // One Day Shift Flow
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final startDateTime = _computeStartDateTime();

    try {
      if (widget.shiftToEdit != null) {
        await widget.shiftService.updateUpcomingShift(
          widget.shiftToEdit!.shiftId,
          guardId: _selectedGuard!.uid,
          guardUid: _selectedGuard!.uid,
          guardEmail: _selectedGuard!.email,
          guardName: _selectedGuard!.name,
          shiftDate: _selectedDate,
          startDateTime: startDateTime,
          durationHours: _durationHours,
        );
      } else {
        await widget.shiftService.createShift(
          guardId: _selectedGuard!.uid,
          guardUid: _selectedGuard!.uid,
          guardEmail: _selectedGuard!.email,
          guardName: _selectedGuard!.name,
          shiftDate: _selectedDate,
          startDateTime: startDateTime,
          durationHours: _durationHours,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.shiftToEdit != null ? AppStrings.shiftUpdatedSuccess : AppStrings.shiftAssignedSuccess)),
        );
      }
    } on OverlappingShiftException {
      if (mounted) {
        setState(() {
          _errorMessage = AppStrings.shiftOverlapError;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${AppStrings.error}: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final startDt = _computeStartDateTime();
    final endDt = _computeEndDateTime();
    final isMidnightCrossing = endDt.day != startDt.day;

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                  widget.shiftToEdit != null ? AppStrings.editShift : AppStrings.createShift,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 14),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: AppColors.dangerDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Assignment Type Selector (Only when creating new shift)
            if (widget.shiftToEdit == null) ...[
              Text(AppStrings.assignmentType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _assignmentType = _AssignmentType.oneDay),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _assignmentType == _AssignmentType.oneDay ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _assignmentType == _AssignmentType.oneDay ? AppColors.primary : AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            AppStrings.oneDay,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _assignmentType == _AssignmentType.oneDay ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _assignmentType = _AssignmentType.recurringSchedule),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _assignmentType == _AssignmentType.recurringSchedule ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _assignmentType == _AssignmentType.recurringSchedule ? AppColors.primary : AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            AppStrings.recurringSchedule,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _assignmentType == _AssignmentType.recurringSchedule ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Guard Selection
            Text(AppStrings.selectGuard, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<GuardModel>(
              initialValue: _selectedGuard,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _guards.map((g) {
                return DropdownMenuItem(value: g, child: Text('${g.name} (${g.email})'));
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedGuard = val;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 14),

            // Date Fields: One Day Date vs Recurring Date Range
            if (_assignmentType == _AssignmentType.oneDay || widget.shiftToEdit != null) ...[
              Text(AppStrings.selectDate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _errorMessage = null;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppFormatters.formatDate(_selectedDate), style: const TextStyle(fontSize: 14)),
                      const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Recurring: Start Date & End Date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.startDate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _recurringStartDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _recurringStartDate = picked;
                                if (_recurringEndDate.isBefore(picked)) {
                                  _recurringEndDate = picked.add(const Duration(days: 30));
                                }
                                _errorMessage = null;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(AppFormatters.formatDate(_recurringStartDate), style: const TextStyle(fontSize: 13)),
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.endDate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _recurringEndDate,
                              firstDate: _recurringStartDate,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _recurringEndDate = picked;
                                _errorMessage = null;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(AppFormatters.formatDate(_recurringEndDate), style: const TextStyle(fontSize: 13)),
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),

            // Start Time Selection
            Text(AppStrings.selectStartTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _selectedStartTime,
                );
                if (picked != null) {
                  setState(() {
                    _selectedStartTime = picked;
                    _errorMessage = null;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppFormatters.formatTime(startDt), style: const TextStyle(fontSize: 14)),
                    const Icon(Icons.access_time, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Shift Duration Selection
            Text(AppStrings.shiftDuration, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 500;
                final durations = _allowedDurations;
                if (isMobile && durations.length == 4) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildDurationButton(durations[0])),
                          const SizedBox(width: 10),
                          Expanded(child: _buildDurationButton(durations[1])),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildDurationButton(durations[2])),
                          const SizedBox(width: 10),
                          Expanded(child: _buildDurationButton(durations[3])),
                        ],
                      ),
                    ],
                  );
                } else if (isMobile) {
                  final rows = <Widget>[];
                  for (var i = 0; i < durations.length; i += 2) {
                    final hasNext = i + 1 < durations.length;
                    rows.add(
                      Row(
                        children: [
                          Expanded(child: _buildDurationButton(durations[i])),
                          const SizedBox(width: 10),
                          if (hasNext)
                            Expanded(child: _buildDurationButton(durations[i + 1]))
                          else
                            const Spacer(),
                        ],
                      ),
                    );
                    if (i + 2 < durations.length) {
                      rows.add(const SizedBox(height: 10));
                    }
                  }
                  return Column(children: rows);
                } else {
                  return Row(
                    children: [
                      for (int i = 0; i < durations.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: _buildDurationButton(durations[i])),
                      ],
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 14),

            // Repeat On Weekday Checkboxes (For Recurring Schedule)
            if (_assignmentType == _AssignmentType.recurringSchedule && widget.shiftToEdit == null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.repeatOn, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _selectedWeekdays = [1, 2, 3, 4, 5]),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: const Text('Mon-Fri', style: TextStyle(fontSize: 11)),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selectedWeekdays = [1, 2, 3, 4, 5, 6, 7]),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: const Text('All 7 Days', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildWeekdayChip(1, 'Mon', AppStrings.dayMonday),
                  _buildWeekdayChip(2, 'Tue', AppStrings.dayTuesday),
                  _buildWeekdayChip(3, 'Wed', AppStrings.dayWednesday),
                  _buildWeekdayChip(4, 'Thu', AppStrings.dayThursday),
                  _buildWeekdayChip(5, 'Fri', AppStrings.dayFriday),
                  _buildWeekdayChip(6, 'Sat', AppStrings.daySaturday),
                  _buildWeekdayChip(7, 'Sun', AppStrings.daySunday),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Automatic End Time & Duration Banner (Supports midnight crossing display)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.duration,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        AppStrings.formatShiftDuration(_durationHours),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.endTime,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Text(
                        '${AppFormatters.formatTime(endDt)}${isMidnightCrossing ? " (Next Day)" : ""}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            AppButton(
              label: widget.shiftToEdit != null
                  ? AppStrings.save
                  : (_assignmentType == _AssignmentType.recurringSchedule ? AppStrings.createSchedule : AppStrings.assignShift),
              isLoading: _isLoading,
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationButton(int hrs) {
    final isSelected = _durationHours == hrs;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _durationHours = hrs;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46, minWidth: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            AppStrings.formatShiftDuration(hrs),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayChip(int dayInt, String shortName, String localizedName) {
    final isSelected = _selectedWeekdays.contains(dayInt);
    return FilterChip(
      label: Text(shortName, style: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      )),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      visualDensity: VisualDensity.compact,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedWeekdays.add(dayInt);
          } else {
            _selectedWeekdays.remove(dayInt);
          }
          _selectedWeekdays.sort();
        });
      },
    );
  }
}
