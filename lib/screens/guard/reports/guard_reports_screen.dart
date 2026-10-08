import 'package:flutter/material.dart';
import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/handover_model.dart';
import '../../../models/payment_transaction_model.dart';
import '../../../models/withdrawal_model.dart';
import '../../../services/financial_responsibility_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/payment_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/notifications/notification_dialog.dart';

/// GuardReportsScreen provides dedicated Guard-side reporting and transaction history.
/// Strictly scoped to the authenticated guard's UID:
/// - Reports: Today, Last 7 Days, Last 30 Days, This Year, Custom Date Range (From <= To)
/// - Daily & Monthly breakdowns with totals at the bottom
/// - Separate Cash & UPI Reports: Collection = Advance + Final - Refund, Outstanding
/// - Guard-wise Transactions with Search, Filter, Sort
/// - Handover & Withdrawal histories
class GuardReportsScreen extends StatefulWidget {
  final GuardModel currentGuard;
  final Stream<PaymentReportData>? customReportStream;
  final Stream<GuardFinancialResponsibility>? customResponsibilityStream;

  const GuardReportsScreen({
    super.key,
    required this.currentGuard,
    this.customReportStream,
    this.customResponsibilityStream,
  });

  @override
  State<GuardReportsScreen> createState() => _GuardReportsScreenState();
}

enum _ReportPeriod {
  today,
  last7Days,
  last30Days,
  thisYear,
  custom,
}

enum _TxnSort {
  newestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount,
}

class _GuardReportsScreenState extends State<GuardReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _paymentService = PaymentService();
  final _financialService = FinancialResponsibilityService.instance;

  late Stream<PaymentReportData> _reportStream;
  late Stream<GuardFinancialResponsibility> _responsibilityStream;

  _ReportPeriod _selectedPeriod = _ReportPeriod.today;
  DateTime _customFromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _customToDate = DateTime.now();
  bool _isCustomRangeValid = true;

  // Search & Filter & Sort state for transactions
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterMethod = 'all'; // 'all', 'cash', 'upi'
  String _filterType = 'all'; // 'all', 'advance', 'final', 'refund'
  _TxnSort _sortMode = _TxnSort.newestFirst;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initStreams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initStreams() {
    if (widget.customReportStream != null) {
      _reportStream = widget.customReportStream!;
    } else {
      final now = DateTime.now();
      DateTime? start;
      DateTime? end;

      switch (_selectedPeriod) {
        case _ReportPeriod.today:
          start = DateTime(now.year, now.month, now.day);
          break;
        case _ReportPeriod.last7Days:
          start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
          break;
        case _ReportPeriod.last30Days:
          start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
          break;
        case _ReportPeriod.thisYear:
          start = DateTime(now.year, 1, 1);
          break;
        case _ReportPeriod.custom:
          start = DateTime(_customFromDate.year, _customFromDate.month, _customFromDate.day);
          end = DateTime(_customToDate.year, _customToDate.month, _customToDate.day, 23, 59, 59);
          break;
      }

      _reportStream = _paymentService.watchPaymentReport(
        guardUid: widget.currentGuard.uid,
        startDate: start,
        endDate: end,
      );
    }

    if (widget.customResponsibilityStream != null) {
      _responsibilityStream = widget.customResponsibilityStream!;
    } else {
      _responsibilityStream = _financialService.watchGuardResponsibility(
        widget.currentGuard.uid,
        widget.currentGuard.name,
      );
    }
  }

  void _onPeriodChanged(_ReportPeriod period) {
    setState(() {
      _selectedPeriod = period;
      _initStreams();
    });
  }

  Future<void> _selectCustomDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _customFromDate : _customToDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _customFromDate = picked;
        } else {
          _customToDate = picked;
        }
        // Validation: From Date <= To Date
        _isCustomRangeValid = !_customFromDate.isAfter(_customToDate);
        if (_isCustomRangeValid) {
          _selectedPeriod = _ReportPeriod.custom;
          _initStreams();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLanguageController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              AppStrings.guardReports,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              StreamBuilder<int>(
                stream: NotificationService().watchUnreadCount(widget.currentGuard.uid),
                builder: (context, notifSnap) {
                  final unread = notifSnap.data ?? 0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        color: AppColors.textSecondary,
                        tooltip: AppStrings.notifications,
                        onPressed: () => NotificationDialog.show(context, userId: widget.currentGuard.uid),
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: AppColors.textSecondary),
                tooltip: AppStrings.handoverHistory,
                onPressed: _showHandoverHistoryModal,
              ),
              IconButton(
                icon: const Icon(Icons.account_balance_outlined, color: AppColors.textSecondary),
                tooltip: AppStrings.withdrawalHistory,
                onPressed: _showWithdrawalHistoryModal,
              ),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(text: AppStrings.reports),
                Tab(text: AppStrings.cashReport),
                Tab(text: AppStrings.upiReport),
                Tab(text: AppStrings.transactionHistory),
              ],
            ),
          ),
          body: StreamBuilder<PaymentReportData>(
            stream: _reportStream,
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
                        Text('${AppStrings.error}: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        AppButton(
                          label: AppStrings.retry,
                          icon: Icons.refresh,
                          isFullWidth: false,
                          onPressed: () => setState(() => _initStreams()),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final report = snapshot.data ?? PaymentReportData.zero;

              return StreamBuilder<GuardFinancialResponsibility>(
                stream: _responsibilityStream,
                initialData: GuardFinancialResponsibility(
                  guardUid: widget.currentGuard.uid,
                  guardName: widget.currentGuard.name,
                ),
                builder: (context, respSnap) {
                  final resp = respSnap.data ??
                      GuardFinancialResponsibility(
                        guardUid: widget.currentGuard.uid,
                        guardName: widget.currentGuard.name,
                      );

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(report, resp),
                      _buildCashTab(report, resp),
                      _buildUpiTab(report, resp),
                      _buildTransactionsTab(report),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: OVERVIEW & BREAKDOWN (Today, 7D, 30D, Year, Custom)
  // ---------------------------------------------------------------------------
  Widget _buildOverviewTab(PaymentReportData report, GuardFinancialResponsibility resp) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip(AppStrings.todayPeriod, _ReportPeriod.today),
                const SizedBox(width: 6),
                _buildPeriodChip(AppStrings.last7DaysPeriod, _ReportPeriod.last7Days),
                const SizedBox(width: 6),
                _buildPeriodChip(AppStrings.last30DaysPeriod, _ReportPeriod.last30Days),
                const SizedBox(width: 6),
                _buildPeriodChip(AppStrings.thisYearPeriod, _ReportPeriod.thisYear),
                const SizedBox(width: 6),
                _buildPeriodChip(AppStrings.customDateRangePeriod, _ReportPeriod.custom),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Custom Date Range Selector (From Date, To Date with validation)
          if (_selectedPeriod == _ReportPeriod.custom) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _isCustomRangeValid ? AppColors.border : AppColors.danger),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectCustomDate(true),
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text(
                            '${AppStrings.fromDate}: ${AppFormatters.formatDate(_customFromDate)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectCustomDate(false),
                          icon: const Icon(Icons.event, size: 14),
                          label: Text(
                            '${AppStrings.toDate}: ${AppFormatters.formatDate(_customToDate)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_isCustomRangeValid) ...[
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.invalidDateRange,
                      style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Conditional View based on Period
          if (_selectedPeriod == _ReportPeriod.today)
            _buildTodayView(report)
          else if (_selectedPeriod == _ReportPeriod.last7Days)
            _buildLast7DaysView(report)
          else if (_selectedPeriod == _ReportPeriod.last30Days)
            _buildLast30DaysView(report)
          else if (_selectedPeriod == _ReportPeriod.thisYear)
            _buildThisYearView(report)
          else
            _buildCustomRangeView(report),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, _ReportPeriod period) {
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => _onPeriodChanged(period),
    );
  }

  // --- Today View ---
  Widget _buildTodayView(PaymentReportData report) {
    final entriesCount = report.transactions.where((t) => t.isAdvance).length;
    final exitsCount = report.transactions.where((t) => t.isFinal || t.isRefund).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total Collection Big Banner
        _buildSummaryHeaderCard(
          title: AppStrings.todayTotalCollection,
          total: report.todayTotalCollection,
          cash: report.collectedCash,
          upi: report.collectedUpi,
        ),
        const SizedBox(height: 12),

        // Metrics Grid (Total Txns, Entries, Exits)
        Row(
          children: [
            Expanded(child: _buildMetricMiniCard('Total Txns', '${report.transactions.length}', Icons.receipt_long, AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricMiniCard(AppStrings.entriesCount, '$entriesCount', Icons.login, AppColors.success)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricMiniCard(AppStrings.exitsCount, '$exitsCount', Icons.logout, AppColors.secondary)),
          ],
        ),
        const SizedBox(height: 16),

        // Activity / Transactions Details
        Text(
          AppStrings.transactions,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        if (report.transactions.isEmpty)
          _buildEmptyCard('No transactions recorded today.')
        else
          ...report.transactions.map((txn) => _buildTxnRow(txn)),
      ],
    );
  }

  // --- Last 7 Days View (Daily Breakdown) ---
  Widget _buildLast7DaysView(PaymentReportData report) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    double totalCash = 0.0;
    double totalUpi = 0.0;

    final rows = days.map((day) {
      final nextDay = day.add(const Duration(days: 1));
      final dayTxns = report.transactions.where((t) => t.createdAt.isAfter(day) && t.createdAt.isBefore(nextDay)).toList();

      double cNet = 0.0;
      double uNet = 0.0;
      for (final t in dayTxns) {
        if (t.isCash) {
          cNet += t.isRefund ? -t.amount : t.amount;
        } else if (t.isUpi) {
          uNet += t.isRefund ? -t.amount : t.amount;
        }
      }
      cNet = cNet < 0 ? 0.0 : cNet;
      uNet = uNet < 0 ? 0.0 : uNet;
      totalCash += cNet;
      totalUpi += uNet;

      return {
        'date': day,
        'cash': cNet,
        'upi': uNet,
        'total': cNet + uNet,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTableContainer(
          headers: ['Date', AppStrings.cash, AppStrings.upi, 'Total'],
          rows: rows.map((r) {
            return [
              AppFormatters.formatDate(r['date'] as DateTime),
              AppFormatters.formatCurrency(r['cash'] as double),
              AppFormatters.formatCurrency(r['upi'] as double),
              AppFormatters.formatCurrency(r['total'] as double),
            ];
          }).toList(),
        ),
        const SizedBox(height: 14),
        // Bottom Total
        _buildTotalSummaryFooter(
          title: AppStrings.sevenDaysTotal,
          cash: totalCash,
          upi: totalUpi,
          total: totalCash + totalUpi,
        ),
      ],
    );
  }

  // --- Last 30 Days View (Daily Breakdown) ---
  Widget _buildLast30DaysView(PaymentReportData report) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));

    double totalCash = 0.0;
    double totalUpi = 0.0;
    int totalTxns = 0;
    int totalEntries = 0;
    int totalExits = 0;

    final rows = days.map((day) {
      final nextDay = day.add(const Duration(days: 1));
      final dayTxns = report.transactions.where((t) => t.createdAt.isAfter(day) && t.createdAt.isBefore(nextDay)).toList();

      double cNet = 0.0;
      double uNet = 0.0;
      int entries = 0;
      int exits = 0;

      for (final t in dayTxns) {
        if (t.isAdvance) entries++;
        if (t.isFinal || t.isRefund) exits++;
        if (t.isCash) {
          cNet += t.isRefund ? -t.amount : t.amount;
        } else if (t.isUpi) {
          uNet += t.isRefund ? -t.amount : t.amount;
        }
      }
      cNet = cNet < 0 ? 0.0 : cNet;
      uNet = uNet < 0 ? 0.0 : uNet;

      totalCash += cNet;
      totalUpi += uNet;
      totalTxns += dayTxns.length;
      totalEntries += entries;
      totalExits += exits;

      return {
        'date': day,
        'cash': cNet,
        'upi': uNet,
        'total': cNet + uNet,
        'txns': dayTxns.length,
        'entries': entries,
        'exits': exits,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTableContainer(
          headers: ['Date', AppStrings.cash, AppStrings.upi, 'Total', 'Txns', 'In', 'Out'],
          rows: rows.map((r) {
            return [
              AppFormatters.formatDate(r['date'] as DateTime),
              AppFormatters.formatCurrency(r['cash'] as double),
              AppFormatters.formatCurrency(r['upi'] as double),
              AppFormatters.formatCurrency(r['total'] as double),
              '${r['txns']}',
              '${r['entries']}',
              '${r['exits']}',
            ];
          }).toList(),
        ),
        const SizedBox(height: 14),
        // Bottom Total
        _buildTotalSummaryFooter(
          title: AppStrings.thirtyDaysTotal,
          cash: totalCash,
          upi: totalUpi,
          total: totalCash + totalUpi,
          extraSubtitle: 'Txns: $totalTxns • In: $totalEntries • Out: $totalExits',
        ),
      ],
    );
  }

  // --- This Year View (Monthly Breakdown: Jan - Dec) ---
  Widget _buildThisYearView(PaymentReportData report) {
    final now = DateTime.now();
    final year = now.year;
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    double totalCash = 0.0;
    double totalUpi = 0.0;

    final rows = List.generate(now.month, (i) {
      final monthIndex = i + 1;
      final start = DateTime(year, monthIndex, 1);
      final end = monthIndex == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, monthIndex + 1, 1);

      final monthTxns = report.transactions.where((t) => t.createdAt.isAfter(start) && t.createdAt.isBefore(end)).toList();

      double cNet = 0.0;
      double uNet = 0.0;
      for (final t in monthTxns) {
        if (t.isCash) {
          cNet += t.isRefund ? -t.amount : t.amount;
        } else if (t.isUpi) {
          uNet += t.isRefund ? -t.amount : t.amount;
        }
      }
      cNet = cNet < 0 ? 0.0 : cNet;
      uNet = uNet < 0 ? 0.0 : uNet;

      totalCash += cNet;
      totalUpi += uNet;

      return {
        'month': months[i],
        'cash': cNet,
        'upi': uNet,
        'total': cNet + uNet,
      };
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTableContainer(
          headers: ['Month', AppStrings.cash, AppStrings.upi, 'Total'],
          rows: rows.map((r) {
            return [
              r['month'] as String,
              AppFormatters.formatCurrency(r['cash'] as double),
              AppFormatters.formatCurrency(r['upi'] as double),
              AppFormatters.formatCurrency(r['total'] as double),
            ];
          }).toList(),
        ),
        const SizedBox(height: 14),
        _buildTotalSummaryFooter(
          title: '$year ${AppStrings.yearTotal}',
          cash: totalCash,
          upi: totalUpi,
          total: totalCash + totalUpi,
        ),
      ],
    );
  }

  // --- Custom Range View (Daily Breakdown) ---
  Widget _buildCustomRangeView(PaymentReportData report) {
    if (!_isCustomRangeValid) {
      return _buildEmptyCard(AppStrings.invalidDateRange);
    }

    final daysDiff = _customToDate.difference(_customFromDate).inDays;
    final totalDays = (daysDiff < 0 ? 0 : daysDiff) + 1;
    final startDay = DateTime(_customFromDate.year, _customFromDate.month, _customFromDate.day);
    final days = List.generate(totalDays, (i) => startDay.add(Duration(days: i)));

    double totalCash = 0.0;
    double totalUpi = 0.0;
    int totalTxns = 0;
    int totalEntries = 0;
    int totalExits = 0;

    final rows = days.map((day) {
      final nextDay = day.add(const Duration(days: 1));
      final dayTxns = report.transactions.where((t) => t.createdAt.isAfter(day) && t.createdAt.isBefore(nextDay)).toList();

      double cNet = 0.0;
      double uNet = 0.0;
      int entries = 0;
      int exits = 0;

      for (final t in dayTxns) {
        if (t.isAdvance) entries++;
        if (t.isFinal || t.isRefund) exits++;
        if (t.isCash) {
          cNet += t.isRefund ? -t.amount : t.amount;
        } else if (t.isUpi) {
          uNet += t.isRefund ? -t.amount : t.amount;
        }
      }
      cNet = cNet < 0 ? 0.0 : cNet;
      uNet = uNet < 0 ? 0.0 : uNet;

      totalCash += cNet;
      totalUpi += uNet;
      totalTxns += dayTxns.length;
      totalEntries += entries;
      totalExits += exits;

      return {
        'date': day,
        'cash': cNet,
        'upi': uNet,
        'total': cNet + uNet,
        'txns': dayTxns.length,
        'entries': entries,
        'exits': exits,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTableContainer(
          headers: ['Date', AppStrings.cash, AppStrings.upi, 'Total', 'Txns', 'In', 'Out'],
          rows: rows.map((r) {
            return [
              AppFormatters.formatDate(r['date'] as DateTime),
              AppFormatters.formatCurrency(r['cash'] as double),
              AppFormatters.formatCurrency(r['upi'] as double),
              AppFormatters.formatCurrency(r['total'] as double),
              '${r['txns']}',
              '${r['entries']}',
              '${r['exits']}',
            ];
          }).toList(),
        ),
        const SizedBox(height: 14),
        _buildTotalSummaryFooter(
          title: AppStrings.customPeriodTotal,
          cash: totalCash,
          upi: totalUpi,
          total: totalCash + totalUpi,
          extraSubtitle: 'Txns: $totalTxns • In: $totalEntries • Out: $totalExits',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: CASH REPORT
  // ---------------------------------------------------------------------------
  Widget _buildCashTab(PaymentReportData report, GuardFinancialResponsibility resp) {
    final cashTxns = report.transactions.where((t) => t.isCash).toList();

    double advance = 0.0;
    double finals = 0.0;
    double refund = 0.0;

    for (final t in cashTxns) {
      if (t.isAdvance) advance += t.amount;
      if (t.isFinal) finals += t.amount;
      if (t.isRefund) refund += t.amount;
    }

    final collection = (advance + finals - refund).clamp(0.0, double.infinity);
    final outstanding = resp.outstandingCash;

    // Filter cash transactions
    final filteredCash = _filterTransactions(cashTxns);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cash Summary Big Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cashColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.cashReport.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.cashColor),
                    ),
                    StatusBadge(label: '${cashTxns.length} Txns', type: BadgeType.active),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  AppFormatters.formatCurrency(collection),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.cashColor),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                _buildRow(AppStrings.cashAdvance, AppFormatters.formatCurrency(advance)),
                const SizedBox(height: 6),
                _buildRow(AppStrings.cashFinal, AppFormatters.formatCurrency(finals)),
                const SizedBox(height: 6),
                _buildRow(AppStrings.cashRefund, '- ${AppFormatters.formatCurrency(refund)}', color: AppColors.danger),
                const SizedBox(height: 6),
                _buildRow(
                  AppStrings.cashOutstanding,
                  AppFormatters.formatCurrency(outstanding),
                  isBold: true,
                  color: outstanding > 0 ? AppColors.danger : AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search, Filter, Sort Controls
          _buildSearchAndSortBar(showMethodFilter: false),
          const SizedBox(height: 12),

          // Cash Transactions List
          if (filteredCash.isEmpty)
            _buildEmptyCard('No cash transactions match the criteria.')
          else
            ...filteredCash.map((txn) => _buildTxnRow(txn)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: UPI REPORT
  // ---------------------------------------------------------------------------
  Widget _buildUpiTab(PaymentReportData report, GuardFinancialResponsibility resp) {
    final upiTxns = report.transactions.where((t) => t.isUpi).toList();

    double advance = 0.0;
    double finals = 0.0;
    double refund = 0.0;

    for (final t in upiTxns) {
      if (t.isAdvance) advance += t.amount;
      if (t.isFinal) finals += t.amount;
      if (t.isRefund) refund += t.amount;
    }

    final collection = (advance + finals - refund).clamp(0.0, double.infinity);
    final outstanding = resp.outstandingUpi;

    // Filter UPI transactions
    final filteredUpi = _filterTransactions(upiTxns);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // UPI Summary Big Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.upiColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.upiReport.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.upiColor),
                    ),
                    StatusBadge(label: '${upiTxns.length} Txns', type: BadgeType.info),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  AppFormatters.formatCurrency(collection),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.upiColor),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                _buildRow(AppStrings.upiAdvance, AppFormatters.formatCurrency(advance)),
                const SizedBox(height: 6),
                _buildRow(AppStrings.upiFinal, AppFormatters.formatCurrency(finals)),
                const SizedBox(height: 6),
                _buildRow(AppStrings.upiRefund, '- ${AppFormatters.formatCurrency(refund)}', color: AppColors.danger),
                const SizedBox(height: 6),
                _buildRow(
                  AppStrings.upiOutstanding,
                  AppFormatters.formatCurrency(outstanding),
                  isBold: true,
                  color: outstanding > 0 ? AppColors.danger : AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search, Filter, Sort Controls
          _buildSearchAndSortBar(showMethodFilter: false),
          const SizedBox(height: 12),

          // UPI Transactions List
          if (filteredUpi.isEmpty)
            _buildEmptyCard('No UPI transactions match the criteria.')
          else
            ...filteredUpi.map((txn) => _buildTxnRow(txn)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: GUARD-WISE TRANSACTIONS
  // ---------------------------------------------------------------------------
  Widget _buildTransactionsTab(PaymentReportData report) {
    final filtered = _filterTransactions(report.transactions);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip(AppStrings.todayPeriod, _ReportPeriod.today),
                const SizedBox(width: 6),
                _buildPeriodChip(AppStrings.last7DaysPeriod, _ReportPeriod.last7Days),
                const SizedBox(width: 6),
                _buildPeriodChip(AppStrings.last30DaysPeriod, _ReportPeriod.last30Days),
                const SizedBox(width: 6),
                _buildPeriodChip(AppStrings.thisYearPeriod, _ReportPeriod.thisYear),
                const SizedBox(width: 6),
                _buildPeriodChip(AppStrings.customDateRangePeriod, _ReportPeriod.custom),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search, Method + Type Filter, and Sort Controls
          _buildSearchAndSortBar(showMethodFilter: true),
          const SizedBox(height: 12),

          // Transactions Count Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppStrings.transactions} (${filtered.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Transactions List
          if (filtered.isEmpty)
            _buildEmptyCard(AppStrings.noTransactionsFound)
          else
            ...filtered.map((txn) => _buildTxnRow(txn)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER & SORT PIPELINE (Uses actual typed values: DateTime, double)
  // ---------------------------------------------------------------------------
  List<PaymentTransactionModel> _filterTransactions(List<PaymentTransactionModel> input) {
    var list = input.where((txn) {
      if (_filterMethod == 'cash' && !txn.isCash) return false;
      if (_filterMethod == 'upi' && !txn.isUpi) return false;

      if (_filterType == 'advance' && !txn.isAdvance) return false;
      if (_filterType == 'final' && !txn.isFinal) return false;
      if (_filterType == 'refund' && !txn.isRefund) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTxn = txn.transactionId.toLowerCase().contains(q);
        final matchTicket = txn.ticketId.toLowerCase().contains(q);
        final matchVeh = txn.vehicleNumber.toLowerCase().contains(q);
        if (!matchTxn && !matchTicket && !matchVeh) return false;
      }

      return true;
    }).toList();

    // Sort using actual typed DateTime or numeric amount
    switch (_sortMode) {
      case _TxnSort.newestFirst:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _TxnSort.oldestFirst:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case _TxnSort.highestAmount:
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case _TxnSort.lowestAmount:
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    return list;
  }

  Widget _buildSearchAndSortBar({required bool showMethodFilter}) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search Ticket, Vehicle, Txn ID...',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    }),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (showMethodFilter) ...[
                      _buildChipFilter('All', 'all', _filterMethod, (v) => setState(() => _filterMethod = v)),
                      const SizedBox(width: 4),
                      _buildChipFilter('Cash', 'cash', _filterMethod, (v) => setState(() => _filterMethod = v)),
                      const SizedBox(width: 4),
                      _buildChipFilter('UPI', 'upi', _filterMethod, (v) => setState(() => _filterMethod = v)),
                      const SizedBox(width: 8),
                    ],
                    _buildChipFilter('All Types', 'all', _filterType, (v) => setState(() => _filterType = v)),
                    const SizedBox(width: 4),
                    _buildChipFilter(AppStrings.advance, 'advance', _filterType, (v) => setState(() => _filterType = v)),
                    const SizedBox(width: 4),
                    _buildChipFilter(AppStrings.finalPayment, 'final', _filterType, (v) => setState(() => _filterType = v)),
                    const SizedBox(width: 4),
                    _buildChipFilter(AppStrings.refund, 'refund', _filterType, (v) => setState(() => _filterType = v)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_TxnSort>(
              initialValue: _sortMode,
              tooltip: AppStrings.sortBy,
              onSelected: (m) => setState(() => _sortMode = m),
              itemBuilder: (ctx) => [
                _sortItem(_TxnSort.newestFirst, AppStrings.newestFirst),
                _sortItem(_TxnSort.oldestFirst, AppStrings.oldestFirst),
                _sortItem(_TxnSort.highestAmount, AppStrings.highestAmount),
                _sortItem(_TxnSort.lowestAmount, AppStrings.lowestAmount),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sort, size: 16, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChipFilter(String label, String value, String current, ValueChanged<String> onSelect) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => onSelect(value),
    );
  }

  PopupMenuItem<_TxnSort> _sortItem(_TxnSort value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortMode == value)
            const Icon(Icons.check, size: 16, color: AppColors.primary)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGET HELPERS
  // ---------------------------------------------------------------------------
  Widget _buildSummaryHeaderCard({
    required String title,
    required double total,
    required double cash,
    required double upi,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            AppFormatters.formatCurrency(total),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cashLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CASH',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.cashColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppFormatters.formatCurrency(cash),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.cashColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.upiLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'UPI',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.upiColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppFormatters.formatCurrency(upi),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.upiColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMiniCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTableContainer({required List<String> headers, required List<List<String>> rows}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.primarySurface),
          columnSpacing: 20,
          horizontalMargin: 12,
          headingRowHeight: 38,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 44,
          columns: headers
              .map((h) => DataColumn(
                    label: Text(
                      h,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ))
              .toList(),
          rows: rows.map((r) {
            return DataRow(
              cells: r.map((c) => DataCell(Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTotalSummaryFooter({
    required String title,
    required double cash,
    required double upi,
    required double total,
    String? extraSubtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              Text(
                AppFormatters.formatCurrency(total),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${AppStrings.cash}: ${AppFormatters.formatCurrency(cash)}  •  ${AppStrings.upi}: ${AppFormatters.formatCurrency(upi)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          if (extraSubtitle != null) ...[
            const SizedBox(height: 4),
            Text(extraSubtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _buildTxnRow(PaymentTransactionModel txn) {
    Color color = AppColors.success;
    String label = AppStrings.finalPayment;
    IconData icon = Icons.check_circle_outline;

    if (txn.isRefund) {
      color = AppColors.danger;
      label = AppStrings.refund;
      icon = Icons.remove_circle_outline;
    } else if (txn.isAdvance) {
      color = AppColors.primary;
      label = AppStrings.advance;
      icon = Icons.arrow_downward;
    }

    final isUpi = txn.isUpi;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                    ),
                    const SizedBox(width: 6),
                    StatusBadge(
                      label: isUpi ? 'UPI' : 'CASH',
                      type: isUpi ? BadgeType.info : BadgeType.active,
                    ),
                    if (txn.shift.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(txn.shift, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${txn.ticketId.isNotEmpty ? "${AppStrings.ticketLabel} ${txn.ticketId}" : ""} ${txn.vehicleNumber.isNotEmpty ? "• ${txn.vehicleNumber}" : ""}'.trim(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppFormatters.formatDate(txn.createdAt)} ${AppFormatters.formatTime(txn.createdAt)}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            '${txn.isRefund ? "-" : "+"}${AppFormatters.formatCurrency(txn.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: txn.isRefund ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(msg, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HANDOVER & WITHDRAWAL HISTORY MODALS
  // ---------------------------------------------------------------------------
  void _showHandoverHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.handoverHistory, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<HandoverModel>>(
                  stream: _financialService.watchGuardHandovers(widget.currentGuard.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load handover history: ${snapshot.error}',
                          style: const TextStyle(fontSize: 12, color: AppColors.danger),
                        ),
                      );
                    }
                    final handovers = snapshot.data ?? [];
                    if (handovers.isEmpty) {
                      return const Center(child: Text('No handover history recorded.'));
                    }
                    return ListView.separated(
                      itemCount: handovers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final h = handovers[i];
                        final isOutgoing = h.fromGuardId == widget.currentGuard.uid;
                        return ListTile(
                          leading: Icon(
                            isOutgoing ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isOutgoing ? AppColors.warningDark : AppColors.success,
                          ),
                          title: Text(
                            '${isOutgoing ? "To ${h.toGuardName}" : "From ${h.fromGuardName}"} (${h.type})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${AppFormatters.formatDate(h.createdAt)} ${AppFormatters.formatTime(h.createdAt)} • ${h.status}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            AppFormatters.formatCurrency(h.amount),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWithdrawalHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.withdrawalHistory, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<WithdrawalModel>>(
                  stream: _financialService.watchGuardWithdrawals(widget.currentGuard.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final withdrawals = snapshot.data ?? [];
                    if (withdrawals.isEmpty) {
                      return const Center(child: Text('No withdrawal records found.'));
                    }
                    return ListView.separated(
                      itemCount: withdrawals.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final w = withdrawals[i];
                        return ListTile(
                          leading: const Icon(Icons.account_balance, color: AppColors.secondary),
                          title: Text(
                            '${w.type} Withdrawal by Admin (${w.adminName})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${AppFormatters.formatDate(w.createdAt)} ${AppFormatters.formatTime(w.createdAt)} • ${w.status}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            AppFormatters.formatCurrency(w.amount),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.danger),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
