import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/handover_model.dart';
import '../../../models/payment_transaction_model.dart';
import '../../../models/responsibility_event_model.dart';
import '../../../models/withdrawal_model.dart';
import '../../../services/admin_service.dart';
import '../../../services/financial_responsibility_service.dart';
import '../../../services/report_export_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/status_badge.dart';

/// Admin Payment Management Screen providing the authoritative financial ledger,
/// dedicated Cash and UPI management, Full Admin Withdrawals, and Handover tracking.
class AdminPaymentManagementScreen extends StatefulWidget {
  const AdminPaymentManagementScreen({super.key});

  @override
  State<AdminPaymentManagementScreen> createState() => _AdminPaymentManagementScreenState();
}

/// Sort modes for Admin Payment — always use raw DateTime/double values.
enum AdminPaymentSort {
  newestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount,
}

/// Sort modes for Financial Responsibility — always compare raw numeric/DateTime values.
enum ResponsibilitySort {
  highestOutstanding,
  lowestOutstanding,
  guardAZ,
  guardZA,
  newestActivity,
  oldestActivity,
}

class _AdminPaymentManagementScreenState extends State<AdminPaymentManagementScreen>
    with SingleTickerProviderStateMixin {
  final _adminService = AdminService();
  final _financialService = FinancialResponsibilityService.instance;
  late TabController _tabController;

  DateTime _selectedDate = DateTime.now();
  String _selectedPaymentMethod = 'all'; // 'all', 'cash', 'upi'
  String _selectedPaymentType = 'ALL'; // 'ALL', 'ADVANCE', 'FINAL', 'REFUND'
  String? _selectedGuardUid;

  // Cash Management search + filter + sort
  final _cashSearchController = TextEditingController();
  String _cashSearch = '';
  String _cashFilter = 'all'; // 'all', 'outstanding', 'handover', 'keep_with_me', 'withdrawn', 'received'
  ResponsibilitySort _cashSort = ResponsibilitySort.highestOutstanding;

  // UPI Management search + filter + sort
  final _upiSearchController = TextEditingController();
  String _upiSearch = '';
  String _upiFilter = 'all'; // 'all', 'outstanding', 'handover', 'keep_with_me', 'withdrawn', 'received'
  ResponsibilitySort _upiSort = ResponsibilitySort.highestOutstanding;

  // Transactions Ledger search + sort
  final _txnSearchController = TextEditingController();
  String _txnSearchQuery = '';
  AdminPaymentSort _txnSortMode = AdminPaymentSort.newestFirst;

  // Keep With Me search + sort + filter
  final _keepWithMeSearchController = TextEditingController();
  String _keepWithMeSearch = '';
  String _keepWithMeTypeFilter = 'all'; // 'all', 'CASH', 'UPI'
  String _keepWithMePeriodFilter = 'all'; // 'all', 'today', '7d', '30d', 'this_year', 'custom'
  DateTimeRange? _keepWithMeCustomRange;
  AdminPaymentSort _keepWithMeSort = AdminPaymentSort.newestFirst;

  // Handovers search + sort + status filter
  final _handoverSearchController = TextEditingController();
  String _handoverSearch = '';
  String _handoverTypeFilter = 'all'; // 'all','CASH','UPI','GUARD_TO_GUARD'
  String _handoverStatusFilter = 'all'; // 'all','PENDING','ACCEPTED','REJECTED','CANCELLED'
  String _handoverPeriodFilter = 'all'; // 'all', 'today', '7d', '30d', 'this_year', 'custom'
  DateTimeRange? _handoverCustomRange;
  AdminPaymentSort _handoverSort = AdminPaymentSort.newestFirst;

  // Withdrawals search + sort + status filter
  final _withdrawalSearchController = TextEditingController();
  String _withdrawalSearch = '';
  String _withdrawalTypeFilter = 'all'; // 'all','CASH','UPI'
  String _withdrawalStatusFilter = 'all'; // 'all','COMPLETED','CANCELLED'
  AdminPaymentSort _withdrawalSort = AdminPaymentSort.newestFirst;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cashSearchController.dispose();
    _upiSearchController.dispose();
    _keepWithMeSearchController.dispose();
    _txnSearchController.dispose();
    _handoverSearchController.dispose();
    _withdrawalSearchController.dispose();
    super.dispose();
  }

  bool _isDateInPeriod(DateTime date, String period, DateTimeRange? customRange) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (period) {
      case 'today':
        return !date.isBefore(startOfToday) && !date.isAfter(endOfToday);
      case '7d':
        final start = startOfToday.subtract(const Duration(days: 6));
        return !date.isBefore(start) && !date.isAfter(endOfToday);
      case '30d':
        final start = startOfToday.subtract(const Duration(days: 29));
        return !date.isBefore(start) && !date.isAfter(endOfToday);
      case 'this_year':
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return !date.isBefore(start) && !date.isAfter(end);
      case 'custom':
        if (customRange == null) return true;
        final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
        final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59, 999);
        return !date.isBefore(start) && !date.isAfter(end);
      case 'all':
      default:
        return true;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _exportTransactionsCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final txns = await _adminService.watchPaymentTransactions(date: _selectedDate).first;
      final headers = ['Txn ID', 'Ticket ID', 'Vehicle', 'Guard', 'Type', 'Method', 'Amount (INR)', 'Time'];
      final rows = txns.map((t) => [
        t.transactionId,
        t.ticketId,
        t.vehicleNumber,
        t.guardName,
        t.paymentType,
        t.paymentMethod.toUpperCase(),
        t.amount.toStringAsFixed(2),
        AppFormatters.formatTime(t.timestamp),
      ]).toList();

      final ok = await ReportExportService.instance.exportCsv(
        reportTitle: 'Payment_Transactions_Ledger',
        headers: headers,
        rows: rows,
      );
      if (ok) {
        messenger.showSnackBar(const SnackBar(content: Text('Transactions CSV exported successfully.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Date & Top Filter Bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    '${AppStrings.date}: ${AppFormatters.formatDate(_selectedDate)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download, size: 20, color: AppColors.primary),
                      tooltip: 'Export CSV Ledger',
                      onPressed: _exportTransactionsCsv,
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _selectedDate = DateTime.now()),
                      child: Text(
                        AppStrings.todaysCollection,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: AppStrings.overview),
              Tab(text: AppStrings.cashManagement),
              Tab(text: AppStrings.upiManagement),
              Tab(text: AppStrings.keepWithMe),
              Tab(text: AppStrings.handovers),
              Tab(text: AppStrings.withdrawals),
              Tab(text: AppStrings.transactionsLedger),
              Tab(text: AppStrings.guardAndShiftReports),
            ],
          ),
          const Divider(height: 1),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildCashManagementTab(),
                _buildUpiManagementTab(),
                _buildKeepWithMeTab(),
                _buildHandoversTab(),
                _buildWithdrawalsTab(),
                _buildTransactionsLedgerTab(),
                _buildGuardAndShiftReportsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('${AppStrings.error}: $error', textAlign: TextAlign.center),
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

  Widget _buildOverviewTab() {
    return StreamBuilder<List<PaymentTransactionModel>>(
      stream: _adminService.watchPaymentTransactions(date: _selectedDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error);
        }

        final txns = snapshot.data ?? [];

        double totalCash = 0.0;
        double totalUpi = 0.0;
        double advanceTotal = 0.0;
        double finalTotal = 0.0;
        double refundTotal = 0.0;
        int cashTxnCount = 0;
        int upiTxnCount = 0;

        for (final t in txns) {
          final amt = t.amount;
          final isUpi = t.isUpi;

          if (isUpi) {
            upiTxnCount++;
          } else {
            cashTxnCount++;
          }

          if (t.isAdvance) {
            advanceTotal += amt;
            if (isUpi) {
              totalUpi += amt;
            } else {
              totalCash += amt;
            }
          } else if (t.isFinal) {
            finalTotal += amt;
            if (isUpi) {
              totalUpi += amt;
            } else {
              totalCash += amt;
            }
          } else if (t.isRefund) {
            refundTotal += amt;
            if (isUpi) {
              totalUpi -= amt;
            } else {
              totalCash -= amt;
            }
          }
        }

        final netCash = totalCash < 0 ? 0.0 : totalCash;
        final netUpi = totalUpi < 0 ? 0.0 : totalUpi;
        final netTotal = (netCash + netUpi) < 0 ? 0.0 : (netCash + netUpi);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Net Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.todayTotalCollection.toUpperCase(),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppFormatters.formatCurrency(netTotal),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${txns.length} ${AppStrings.transactions} • ${AppFormatters.formatDate(_selectedDate)}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Cash & UPI Breakdown
              Row(
                children: [
                  Expanded(
                    child: _buildMetricBreakdownCard(
                      title: AppStrings.cashCollection,
                      collected: netCash,
                      count: cashTxnCount,
                      icon: Icons.payments_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricBreakdownCard(
                      title: AppStrings.upiCollection,
                      collected: netUpi,
                      count: upiTxnCount,
                      icon: Icons.qr_code,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Transaction Type Breakdown
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.transactionType,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Divider(height: 20),
                    _buildRowItem(AppStrings.advance, AppFormatters.formatCurrency(advanceTotal), AppColors.textPrimary),
                    const SizedBox(height: 8),
                    _buildRowItem(AppStrings.finalPayment, AppFormatters.formatCurrency(finalTotal), AppColors.textPrimary),
                    const SizedBox(height: 8),
                    _buildRowItem(AppStrings.refunds, '- ${AppFormatters.formatCurrency(refundTotal)}', AppColors.danger),
                    const Divider(height: 20),
                    _buildRowItem(AppStrings.netTotal, AppFormatters.formatCurrency(netTotal), AppColors.success, isBold: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricBreakdownCard({
    required String title,
    required double collected,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppFormatters.formatCurrency(collected),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            '$count ${AppStrings.transactions}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildRowItem(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildTransactionsLedgerTab() {
    return StreamBuilder<List<PaymentTransactionModel>>(
      stream: _adminService.watchPaymentTransactions(
        date: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
        paymentType: _selectedPaymentType,
        guardUid: _selectedGuardUid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error);
        }

        final txns = snapshot.data ?? [];

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              color: AppColors.surface,
              child: Column(
                children: [
                  // Search
                  TextField(
                    controller: _txnSearchController,
                    decoration: InputDecoration(
                      hintText: AppStrings.searchTransactionsHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _txnSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() {
                                _txnSearchController.clear();
                                _txnSearchQuery = '';
                              }),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _txnSearchQuery = v.trim()),
                  ),
                  const SizedBox(height: 8),
                  // Chips + Sort Row
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildMethodChip('all', AppStrings.all),
                              const SizedBox(width: 8),
                              _buildMethodChip('cash', AppStrings.cash),
                              const SizedBox(width: 8),
                              _buildMethodChip('upi', AppStrings.upi),
                              const SizedBox(width: 16),
                              const Text('|', style: TextStyle(color: AppColors.border)),
                              const SizedBox(width: 16),
                              _buildTypeChip('ALL', AppStrings.all),
                              const SizedBox(width: 8),
                              _buildTypeChip('ADVANCE', AppStrings.advance),
                              const SizedBox(width: 8),
                              _buildTypeChip('FINAL', AppStrings.finalPayment),
                              const SizedBox(width: 8),
                              _buildTypeChip('REFUND', AppStrings.refund),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<AdminPaymentSort>(
                        initialValue: _txnSortMode,
                        tooltip: AppStrings.sortBy,
                        onSelected: (s) => setState(() => _txnSortMode = s),
                        itemBuilder: (ctx) => [
                          _adminSortItem(AdminPaymentSort.newestFirst, AppStrings.newestFirst, _txnSortMode),
                          _adminSortItem(AdminPaymentSort.oldestFirst, AppStrings.oldestFirst, _txnSortMode),
                          _adminSortItem(AdminPaymentSort.highestAmount, AppStrings.highestAmount, _txnSortMode),
                          _adminSortItem(AdminPaymentSort.lowestAmount, AppStrings.lowestAmount, _txnSortMode),
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
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: Builder(
                builder: (context) {
                  // Pipeline: Search → Sort (raw createdAt/amount)
                  var filtered = txns;
                  if (_txnSearchQuery.isNotEmpty) {
                    final q = _txnSearchQuery.toLowerCase();
                    filtered = filtered.where((t) =>
                        t.vehicleNumber.toLowerCase().contains(q) ||
                        t.ticketId.toLowerCase().contains(q) ||
                        t.guardName.toLowerCase().contains(q) ||
                        t.transactionId.toLowerCase().contains(q)).toList();
                  }
                  switch (_txnSortMode) {
                    case AdminPaymentSort.newestFirst:
                      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      break;
                    case AdminPaymentSort.oldestFirst:
                      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                      break;
                    case AdminPaymentSort.highestAmount:
                      filtered.sort((a, b) => b.amount.compareTo(a.amount));
                      break;
                    case AdminPaymentSort.lowestAmount:
                      filtered.sort((a, b) => a.amount.compareTo(b.amount));
                      break;
                  }
                  return filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              AppStrings.noTransactionsFound,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final txn = filtered[index];
                        final isRefund = txn.isRefund;

                        return AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isRefund ? AppColors.dangerLight : (txn.isUpi ? AppColors.accent.withValues(alpha: 0.15) : AppColors.primaryLight.withValues(alpha: 0.2)),
                                child: Icon(
                                  isRefund ? Icons.remove : (txn.isUpi ? Icons.qr_code : Icons.payments),
                                  size: 18,
                                  color: isRefund ? AppColors.danger : (txn.isUpi ? AppColors.accent : AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          txn.vehicleNumber.isNotEmpty ? txn.vehicleNumber : 'Ticket #${txn.ticketId}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        StatusBadge(
                                          label: AppStrings.formatPaymentType(txn.paymentType),
                                          type: isRefund ? BadgeType.danger : BadgeType.info,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${AppStrings.formatPaymentMethod(txn.paymentMethod)} • ${AppStrings.guardLabel} ${txn.guardName} • ${AppFormatters.formatTime(txn.createdAt)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isRefund ? '-' : '+'} ${AppFormatters.formatCurrency(txn.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isRefund ? AppColors.danger : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMethodChip(String method, String label) {
    final isSelected = _selectedPaymentMethod == method;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedPaymentMethod = method),
    );
  }

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _selectedPaymentType == type;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedPaymentType = type),
    );
  }

  PopupMenuItem<AdminPaymentSort> _adminSortItem(
    AdminPaymentSort value,
    String label,
    AdminPaymentSort current,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (current == value)
            const Icon(Icons.check, size: 16, color: AppColors.primary)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  PopupMenuItem<ResponsibilitySort> _respSortItem(
    ResponsibilitySort value,
    String label,
    ResponsibilitySort current,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (current == value)
            const Icon(Icons.check, size: 16, color: AppColors.primary)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildGuardWiseReportTab() {
    return StreamBuilder<List<GuardCollectionSummary>>(
      stream: _adminService.watchGuardWiseCollectionReport(date: _selectedDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error);
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Text(
              AppStrings.noPaymentTransactionsToday,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = reports[index];

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(item.guardName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Text(
                        AppFormatters.formatCurrency(item.netTotal),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${AppStrings.cash}: ${AppFormatters.formatCurrency(item.totalCash)}', style: const TextStyle(fontSize: 12)),
                      Text('${AppStrings.upi}: ${AppFormatters.formatCurrency(item.totalUpi)}', style: const TextStyle(fontSize: 12)),
                      Text('${item.transactionCount} ${AppStrings.transactions}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShiftWiseReportTab() {
    return StreamBuilder<List<ShiftCollectionSummary>>(
      stream: _adminService.watchShiftWiseCollectionReport(date: _selectedDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error);
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Text(
              AppStrings.noPaymentTransactionsToday,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = reports[index];

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Text(item.shiftName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Text(
                        AppFormatters.formatCurrency(item.netTotal),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppStrings.guardLabel} ${item.guardName} • ${AppFormatters.formatDate(item.shiftDate)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${AppStrings.cash}: ${AppFormatters.formatCurrency(item.totalCash)}', style: const TextStyle(fontSize: 12)),
                      Text('${AppStrings.upi}: ${AppFormatters.formatCurrency(item.totalUpi)}', style: const TextStyle(fontSize: 12)),
                      Text('${item.transactionCount} ${AppStrings.transactions}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCashManagementTab() {
    return StreamBuilder<List<GuardFinancialRecord>>(
      stream: _financialService.watchAllGuardsFinancialRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error);
        }

        final allRecords = (snapshot.data ?? []).where((r) => r.guard.isActive).toList();

        // Pipeline: Search → Filter → Sort (numeric amounts & actual DateTimes)
        var list = allRecords;

        if (_cashSearch.isNotEmpty) {
          final q = _cashSearch.toLowerCase();
          list = list.where((r) =>
              r.guard.name.toLowerCase().contains(q) ||
              r.guard.uid.toLowerCase().contains(q) ||
              r.guard.email.toLowerCase().contains(q) ||
              r.guard.currentShift.toLowerCase().contains(q)).toList();
        }

        if (_cashFilter == 'outstanding') {
          list = list.where((r) => r.responsibility.outstandingCash > 0).toList();
        } else if (_cashFilter == 'handover') {
          list = list.where((r) => r.responsibility.cashHandedOver > 0).toList();
        } else if (_cashFilter == 'keep_with_me') {
          list = list.where((r) => r.responsibility.outstandingCash > 0).toList();
        } else if (_cashFilter == 'withdrawn') {
          list = list.where((r) => r.responsibility.cashWithdrawn > 0).toList();
        } else if (_cashFilter == 'received') {
          list = list.where((r) => r.responsibility.cashReceived > 0).toList();
        }

        switch (_cashSort) {
          case ResponsibilitySort.highestOutstanding:
            list.sort((a, b) => b.responsibility.outstandingCash.compareTo(a.responsibility.outstandingCash));
            break;
          case ResponsibilitySort.lowestOutstanding:
            list.sort((a, b) => a.responsibility.outstandingCash.compareTo(b.responsibility.outstandingCash));
            break;
          case ResponsibilitySort.guardAZ:
            list.sort((a, b) => a.guard.name.toLowerCase().compareTo(b.guard.name.toLowerCase()));
            break;
          case ResponsibilitySort.guardZA:
            list.sort((a, b) => b.guard.name.toLowerCase().compareTo(a.guard.name.toLowerCase()));
            break;
          case ResponsibilitySort.newestActivity:
            list.sort((a, b) {
              final tA = a.lastActivity ?? DateTime(2000);
              final tB = b.lastActivity ?? DateTime(2000);
              return tB.compareTo(tA);
            });
            break;
          case ResponsibilitySort.oldestActivity:
            list.sort((a, b) {
              final tA = a.lastActivity ?? DateTime(2000);
              final tB = b.lastActivity ?? DateTime(2000);
              return tA.compareTo(tB);
            });
            break;
        }

        return Column(
          children: [
            // Controls: Search bar + Filter chips + Sort
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cashSearchController,
                          decoration: InputDecoration(
                            hintText: AppStrings.searchGuardsUidShiftHint,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _cashSearch.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() {
                                      _cashSearchController.clear();
                                      _cashSearch = '';
                                    }),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _cashSearch = v.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<ResponsibilitySort>(
                        initialValue: _cashSort,
                        tooltip: AppStrings.sortBy,
                        onSelected: (s) => setState(() => _cashSort = s),
                        itemBuilder: (ctx) => [
                          _respSortItem(ResponsibilitySort.highestOutstanding, AppStrings.highestOutstanding, _cashSort),
                          _respSortItem(ResponsibilitySort.lowestOutstanding, AppStrings.lowestOutstanding, _cashSort),
                          _respSortItem(ResponsibilitySort.guardAZ, AppStrings.guardAZ, _cashSort),
                          _respSortItem(ResponsibilitySort.guardZA, AppStrings.guardZA, _cashSort),
                          _respSortItem(ResponsibilitySort.newestActivity, AppStrings.newestFirst, _cashSort),
                          _respSortItem(ResponsibilitySort.oldestActivity, AppStrings.oldestFirst, _cashSort),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.sort, size: 16, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCashFilterChip(AppStrings.all, 'all'),
                        const SizedBox(width: 6),
                        _buildCashFilterChip(AppStrings.outstanding, 'outstanding'),
                        const SizedBox(width: 6),
                        _buildCashFilterChip(AppStrings.handovers, 'handover'),
                        const SizedBox(width: 6),
                        _buildCashFilterChip(AppStrings.keepWithMe, 'keep_with_me'),
                        const SizedBox(width: 6),
                        _buildCashFilterChip(AppStrings.withdrawn, 'withdrawn'),
                        const SizedBox(width: 6),
                        _buildCashFilterChip(AppStrings.received, 'received'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          AppStrings.noMatchingRecords,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final guard = item.guard;
                        final resp = item.responsibility;
                        final outstanding = resp.outstandingCash;
                        final totalColl = resp.totalCashCollected;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(guard.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text('${guard.email} • UID: ${guard.uid}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      if (guard.currentShift.isNotEmpty)
                                        Text('${AppStrings.shift}: ${guard.currentShift}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(AppStrings.outstandingCash, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      Text(
                                        AppFormatters.formatCurrency(outstanding),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: outstanding > 0 ? AppColors.danger : AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              LayoutBuilder(
                                builder: (context, cardConstraints) {
                                  final isCompact = cardConstraints.maxWidth < 460;
                                  final withdrawBtn = outstanding > 0
                                      ? ElevatedButton.icon(
                                          key: ValueKey('withdraw_cash_btn_${guard.uid}'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.cashColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.download, size: 16),
                                          label: Text(
                                            AppStrings.withdrawCash,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          onPressed: () => _openSpecificWithdrawalDialog(guard, 'CASH', outstanding),
                                        )
                                      : StatusBadge(label: AppStrings.settled, type: BadgeType.active);

                                  final metricsCol = Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${AppStrings.totalCollected}: ${AppFormatters.formatCurrency(totalColl)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      if (resp.cashHandedOver > 0)
                                        Text('${AppStrings.handedOver}: ${AppFormatters.formatCurrency(resp.cashHandedOver)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      if (resp.cashWithdrawn > 0)
                                        Text('${AppStrings.withdrawn}: ${AppFormatters.formatCurrency(resp.cashWithdrawn)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  );

                                  if (isCompact) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        metricsCol,
                                        const SizedBox(height: 10),
                                        withdrawBtn,
                                      ],
                                    );
                                  }

                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: metricsCol),
                                      const SizedBox(width: 8),
                                      withdrawBtn,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCashFilterChip(String label, String value) {
    final isSelected = _cashFilter == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (_) => setState(() => _cashFilter = value),
    );
  }

  Widget _buildUpiManagementTab() {
    return StreamBuilder<List<GuardFinancialRecord>>(
      stream: _financialService.watchAllGuardsFinancialRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error);
        }

        final allRecords = (snapshot.data ?? []).where((r) => r.guard.isActive).toList();

        // Pipeline: Search → Filter → Sort (numeric amounts & actual DateTimes)
        var list = allRecords;

        if (_upiSearch.isNotEmpty) {
          final q = _upiSearch.toLowerCase();
          list = list.where((r) =>
              r.guard.name.toLowerCase().contains(q) ||
              r.guard.uid.toLowerCase().contains(q) ||
              r.guard.email.toLowerCase().contains(q) ||
              r.guard.currentShift.toLowerCase().contains(q)).toList();
        }

        if (_upiFilter == 'outstanding') {
          list = list.where((r) => r.responsibility.outstandingUpi > 0).toList();
        } else if (_upiFilter == 'handover') {
          list = list.where((r) => r.responsibility.upiHandedOver > 0).toList();
        } else if (_upiFilter == 'keep_with_me') {
          list = list.where((r) => r.responsibility.outstandingUpi > 0).toList();
        } else if (_upiFilter == 'withdrawn') {
          list = list.where((r) => r.responsibility.upiWithdrawn > 0).toList();
        } else if (_upiFilter == 'received') {
          list = list.where((r) => r.responsibility.upiReceived > 0).toList();
        }

        switch (_upiSort) {
          case ResponsibilitySort.highestOutstanding:
            list.sort((a, b) => b.responsibility.outstandingUpi.compareTo(a.responsibility.outstandingUpi));
            break;
          case ResponsibilitySort.lowestOutstanding:
            list.sort((a, b) => a.responsibility.outstandingUpi.compareTo(b.responsibility.outstandingUpi));
            break;
          case ResponsibilitySort.guardAZ:
            list.sort((a, b) => a.guard.name.toLowerCase().compareTo(b.guard.name.toLowerCase()));
            break;
          case ResponsibilitySort.guardZA:
            list.sort((a, b) => b.guard.name.toLowerCase().compareTo(a.guard.name.toLowerCase()));
            break;
          case ResponsibilitySort.newestActivity:
            list.sort((a, b) {
              final tA = a.lastActivity ?? DateTime(2000);
              final tB = b.lastActivity ?? DateTime(2000);
              return tB.compareTo(tA);
            });
            break;
          case ResponsibilitySort.oldestActivity:
            list.sort((a, b) {
              final tA = a.lastActivity ?? DateTime(2000);
              final tB = b.lastActivity ?? DateTime(2000);
              return tA.compareTo(tB);
            });
            break;
        }

        return Column(
          children: [
            // Controls: Search bar + Filter chips + Sort
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _upiSearchController,
                          decoration: InputDecoration(
                            hintText: AppStrings.searchGuardsUidShiftHint,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _upiSearch.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() {
                                      _upiSearchController.clear();
                                      _upiSearch = '';
                                    }),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _upiSearch = v.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<ResponsibilitySort>(
                        initialValue: _upiSort,
                        tooltip: AppStrings.sortBy,
                        onSelected: (s) => setState(() => _upiSort = s),
                        itemBuilder: (ctx) => [
                          _respSortItem(ResponsibilitySort.highestOutstanding, AppStrings.highestOutstanding, _upiSort),
                          _respSortItem(ResponsibilitySort.lowestOutstanding, AppStrings.lowestOutstanding, _upiSort),
                          _respSortItem(ResponsibilitySort.guardAZ, AppStrings.guardAZ, _upiSort),
                          _respSortItem(ResponsibilitySort.guardZA, AppStrings.guardZA, _upiSort),
                          _respSortItem(ResponsibilitySort.newestActivity, AppStrings.newestActivity, _upiSort),
                          _respSortItem(ResponsibilitySort.oldestActivity, AppStrings.oldestActivity, _upiSort),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.sort, size: 16, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildUpiFilterChip(AppStrings.all, 'all'),
                        const SizedBox(width: 6),
                        _buildUpiFilterChip(AppStrings.outstanding, 'outstanding'),
                        const SizedBox(width: 6),
                        _buildUpiFilterChip(AppStrings.handover, 'handover'),
                        const SizedBox(width: 6),
                        _buildUpiFilterChip(AppStrings.keepWithMe, 'keep_with_me'),
                        const SizedBox(width: 6),
                        _buildUpiFilterChip(AppStrings.withdrawn, 'withdrawn'),
                        const SizedBox(width: 6),
                        _buildUpiFilterChip(AppStrings.received, 'received'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          AppStrings.noMatchingRecords,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final guard = item.guard;
                        final resp = item.responsibility;
                        final outstanding = resp.outstandingUpi;
                        final totalColl = resp.totalUpiCollected;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(guard.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text('${guard.email} • UID: ${guard.uid}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      if (guard.currentShift.isNotEmpty)
                                        Text('${AppStrings.shift}: ${guard.currentShift}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(AppStrings.outstandingUpi, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      Text(
                                        AppFormatters.formatCurrency(outstanding),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: outstanding > 0 ? AppColors.danger : AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              LayoutBuilder(
                                builder: (context, cardConstraints) {
                                  final isCompact = cardConstraints.maxWidth < 460;
                                  final withdrawBtn = outstanding > 0
                                      ? ElevatedButton.icon(
                                          key: ValueKey('withdraw_upi_btn_${guard.uid}'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.upiColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.download, size: 16),
                                          label: Text(
                                            AppStrings.withdrawUpi,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          onPressed: () => _openSpecificWithdrawalDialog(guard, 'UPI', outstanding),
                                        )
                                      : StatusBadge(label: AppStrings.settled, type: BadgeType.active);

                                  final metricsCol = Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${AppStrings.totalCollected}: ${AppFormatters.formatCurrency(totalColl)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      if (resp.upiHandedOver > 0)
                                        Text('${AppStrings.handedOver}: ${AppFormatters.formatCurrency(resp.upiHandedOver)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      if (resp.upiWithdrawn > 0)
                                        Text('${AppStrings.withdrawn}: ${AppFormatters.formatCurrency(resp.upiWithdrawn)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  );

                                  if (isCompact) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        metricsCol,
                                        const SizedBox(height: 10),
                                        withdrawBtn,
                                      ],
                                    );
                                  }

                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: metricsCol),
                                      const SizedBox(width: 8),
                                      withdrawBtn,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUpiFilterChip(String label, String value) {
    final isSelected = _upiFilter == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (_) => setState(() => _upiFilter = value),
    );
  }

  Widget _buildKeepWithMeTab() {
    return StreamBuilder<List<ResponsibilityEventModel>>(
      stream: _financialService.watchAllKeepWithMeEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error);
        }

        final rawEvents = snapshot.data ?? [];

        // Pipeline: Search -> Type filter -> Period filter -> Sort
        var events = rawEvents;
        if (_keepWithMeSearch.isNotEmpty) {
          final q = _keepWithMeSearch.toLowerCase();
          events = events.where((e) =>
              e.guardName.toLowerCase().contains(q) ||
              e.guardId.toLowerCase().contains(q) ||
              e.shiftId.toLowerCase().contains(q) ||
              e.paymentType.toLowerCase().contains(q) ||
              (e.notes != null && e.notes!.toLowerCase().contains(q))).toList();
        }
        if (_keepWithMeTypeFilter != 'all') {
          events = events.where((e) => e.paymentType.toUpperCase() == _keepWithMeTypeFilter).toList();
        }
        if (_keepWithMePeriodFilter != 'all') {
          events = events.where((e) => _isDateInPeriod(e.timestamp, _keepWithMePeriodFilter, _keepWithMeCustomRange)).toList();
        }

        switch (_keepWithMeSort) {
          case AdminPaymentSort.newestFirst:
            events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            break;
          case AdminPaymentSort.oldestFirst:
            events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            break;
          case AdminPaymentSort.highestAmount:
            events.sort((a, b) => b.amount.compareTo(a.amount));
            break;
          case AdminPaymentSort.lowestAmount:
            events.sort((a, b) => a.amount.compareTo(b.amount));
            break;
        }

        return Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _keepWithMeSearchController,
                          decoration: InputDecoration(
                            hintText: AppStrings.searchKeepWithMeHint,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _keepWithMeSearch.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() {
                                      _keepWithMeSearchController.clear();
                                      _keepWithMeSearch = '';
                                    }),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _keepWithMeSearch = v.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<AdminPaymentSort>(
                        initialValue: _keepWithMeSort,
                        tooltip: AppStrings.sortBy,
                        onSelected: (s) => setState(() => _keepWithMeSort = s),
                        itemBuilder: (ctx) => [
                          _adminSortItem(AdminPaymentSort.newestFirst, AppStrings.newestFirst, _keepWithMeSort),
                          _adminSortItem(AdminPaymentSort.oldestFirst, AppStrings.oldestFirst, _keepWithMeSort),
                          _adminSortItem(AdminPaymentSort.highestAmount, AppStrings.highestAmount, _keepWithMeSort),
                          _adminSortItem(AdminPaymentSort.lowestAmount, AppStrings.lowestAmount, _keepWithMeSort),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.sort, size: 16, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in ['all', 'CASH', 'UPI']) ...[
                          FilterChip(
                            label: Text(t == 'all' ? AppStrings.all : AppStrings.formatPaymentMethod(t), style: const TextStyle(fontSize: 11)),
                            selected: _keepWithMeTypeFilter == t,
                            onSelected: (_) => setState(() => _keepWithMeTypeFilter = t),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const VerticalDivider(width: 12),
                        for (final p in [
                          ('all', AppStrings.allTime),
                          ('today', AppStrings.today),
                          ('7d', AppStrings.last7Days),
                          ('30d', AppStrings.last30Days),
                          ('this_year', AppStrings.thisYear),
                          ('custom', _keepWithMeCustomRange != null
                              ? '${AppFormatters.formatDate(_keepWithMeCustomRange!.start)} - ${AppFormatters.formatDate(_keepWithMeCustomRange!.end)}'
                              : AppStrings.customDateRange),
                        ]) ...[
                          FilterChip(
                            label: Text(p.$2, style: const TextStyle(fontSize: 11)),
                            selected: _keepWithMePeriodFilter == p.$1,
                            onSelected: (_) async {
                              if (p.$1 == 'custom') {
                                final now = DateTime.now();
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2025, 1, 1),
                                  lastDate: now.add(const Duration(days: 365)),
                                  initialDateRange: _keepWithMeCustomRange ??
                                      DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _keepWithMeCustomRange = picked;
                                    _keepWithMePeriodFilter = 'custom';
                                  });
                                }
                              } else {
                                setState(() => _keepWithMePeriodFilter = p.$1);
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Text(
                        _keepWithMeSearch.isNotEmpty || _keepWithMeTypeFilter != 'all' || _keepWithMePeriodFilter != 'all'
                            ? AppStrings.noMatchingRecords
                            : AppStrings.noKeepWithMeHistory,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final e = events[index];
                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      StatusBadge(
                                        label: AppStrings.formatPaymentMethod(e.paymentType),
                                        type: e.paymentType == 'CASH' ? BadgeType.active : BadgeType.info,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppFormatters.formatCurrency(e.amount),
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  StatusBadge(
                                    label: e.status.isNotEmpty ? AppStrings.formatStatus(e.status) : AppStrings.carriedForward,
                                    type: BadgeType.warning,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${AppStrings.entryGuard}: ${e.guardName} (${e.guardId})',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('${AppStrings.action}: ${AppStrings.keepWithMe}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  if (e.shiftId.isNotEmpty) ...[
                                    const Text(' • ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    Text('${AppStrings.shift}: ${e.shiftId}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${AppStrings.recorded}: ${AppFormatters.formatDate(e.timestamp)} ${AppFormatters.formatTime(e.timestamp)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              if (e.notes != null && e.notes!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('${AppStrings.notes}: ${e.notes!}',
                                    style: const TextStyle(
                                        fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHandoversTab() {
    return StreamBuilder<List<HandoverModel>>(
      stream: _financialService.watchAllHandovers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error);
        }

        final rawHandovers = snapshot.data ?? [];

        // Pipeline: Search → Type filter → Status filter → Period filter → Sort (raw DateTime/double)
        var handovers = rawHandovers;
        if (_handoverSearch.isNotEmpty) {
          final q = _handoverSearch.toLowerCase();
          handovers = handovers.where((h) =>
              h.fromGuardName.toLowerCase().contains(q) ||
              h.toGuardName.toLowerCase().contains(q) ||
              h.handoverId.toLowerCase().contains(q) ||
              h.shiftId.toLowerCase().contains(q) ||
              h.type.toLowerCase().contains(q) ||
              h.status.toLowerCase().contains(q)).toList();
        }
        if (_handoverTypeFilter != 'all') {
          handovers = handovers.where((h) => h.type.toUpperCase() == _handoverTypeFilter).toList();
        }
        if (_handoverStatusFilter != 'all') {
          handovers = handovers.where((h) => h.status.toUpperCase() == _handoverStatusFilter).toList();
        }
        if (_handoverPeriodFilter != 'all') {
          handovers = handovers.where((h) => _isDateInPeriod(h.createdAt, _handoverPeriodFilter, _handoverCustomRange)).toList();
        }

        switch (_handoverSort) {
          case AdminPaymentSort.newestFirst:
            handovers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case AdminPaymentSort.oldestFirst:
            handovers.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            break;
          case AdminPaymentSort.highestAmount:
            handovers.sort((a, b) => b.amount.compareTo(a.amount));
            break;
          case AdminPaymentSort.lowestAmount:
            handovers.sort((a, b) => a.amount.compareTo(b.amount));
            break;
        }

        return Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _handoverSearchController,
                          decoration: InputDecoration(
                            hintText: AppStrings.searchHandoversHint,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _handoverSearch.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() {
                                      _handoverSearchController.clear();
                                      _handoverSearch = '';
                                    }),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _handoverSearch = v.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<AdminPaymentSort>(
                        initialValue: _handoverSort,
                        tooltip: AppStrings.sortBy,
                        onSelected: (s) => setState(() => _handoverSort = s),
                        itemBuilder: (ctx) => [
                          _adminSortItem(AdminPaymentSort.newestFirst, AppStrings.newestFirst, _handoverSort),
                          _adminSortItem(AdminPaymentSort.oldestFirst, AppStrings.oldestFirst, _handoverSort),
                          _adminSortItem(AdminPaymentSort.highestAmount, AppStrings.highestAmount, _handoverSort),
                          _adminSortItem(AdminPaymentSort.lowestAmount, AppStrings.lowestAmount, _handoverSort),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.sort, size: 16, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in ['all', 'CASH', 'UPI']) ...[  
                          FilterChip(
                            label: Text(t == 'all' ? AppStrings.all : AppStrings.formatPaymentMethod(t), style: const TextStyle(fontSize: 11)),
                            selected: _handoverTypeFilter == t,
                            onSelected: (_) => setState(() => _handoverTypeFilter = t),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const VerticalDivider(width: 12),
                        for (final s in ['all', 'PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED']) ...[  
                          FilterChip(
                            label: Text(s == 'all' ? AppStrings.allStatus : AppStrings.formatStatus(s), style: const TextStyle(fontSize: 11)),
                            selected: _handoverStatusFilter == s,
                            onSelected: (_) => setState(() => _handoverStatusFilter = s),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const VerticalDivider(width: 12),
                        for (final p in [
                          ('all', AppStrings.allTime),
                          ('today', AppStrings.today),
                          ('7d', AppStrings.last7Days),
                          ('30d', AppStrings.last30Days),
                          ('this_year', AppStrings.thisYear),
                          ('custom', _handoverCustomRange != null
                              ? '${AppFormatters.formatDate(_handoverCustomRange!.start)} - ${AppFormatters.formatDate(_handoverCustomRange!.end)}'
                              : AppStrings.customDateRange),
                        ]) ...[
                          FilterChip(
                            label: Text(p.$2, style: const TextStyle(fontSize: 11)),
                            selected: _handoverPeriodFilter == p.$1,
                            onSelected: (_) async {
                              if (p.$1 == 'custom') {
                                final now = DateTime.now();
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2025, 1, 1),
                                  lastDate: now.add(const Duration(days: 365)),
                                  initialDateRange: _handoverCustomRange ??
                                      DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _handoverCustomRange = picked;
                                    _handoverPeriodFilter = 'custom';
                                  });
                                }
                              } else {
                                setState(() => _handoverPeriodFilter = p.$1);
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: handovers.isEmpty
                  ? Center(
                      child: Text(
                        _handoverSearch.isNotEmpty || _handoverTypeFilter != 'all' || _handoverStatusFilter != 'all' || _handoverPeriodFilter != 'all'
                            ? AppStrings.noMatchingRecords
                            : AppStrings.noHandoverHistory,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: handovers.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final h = handovers[index];
                        BadgeType bType;
                        if (h.isAccepted) {
                          bType = BadgeType.active;
                        } else if (h.isRejected) {
                          bType = BadgeType.danger;
                        } else if (h.isCancelled) {
                          bType = BadgeType.danger;
                        } else {
                          bType = BadgeType.warning;
                        }

                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      StatusBadge(
                                        label: AppStrings.formatPaymentMethod(h.type),
                                        type: h.type == 'CASH' ? BadgeType.active : BadgeType.info,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppFormatters.formatCurrency(h.amount),
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  StatusBadge(label: AppStrings.formatStatus(h.status), type: bType),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${AppStrings.from}: ${h.fromGuardName}  ➔  ${AppStrings.to}: ${h.toGuardName}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('ID: ${h.handoverId.substring(0, h.handoverId.length > 8 ? 8 : h.handoverId.length)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  if (h.shiftId.isNotEmpty) ...[
                                    const Text(' • ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    Text('${AppStrings.fromShift}: ${h.shiftId}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                  if (h.toShiftId != null && h.toShiftId!.isNotEmpty) ...[
                                    const Text(' • ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    Text('${AppStrings.toShift}: ${h.toShiftId!}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${AppStrings.created}: ${AppFormatters.formatDate(h.createdAt)} ${AppFormatters.formatTime(h.createdAt)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              if (h.acceptedAt != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${AppStrings.accepted}: ${AppFormatters.formatDate(h.acceptedAt!)} ${AppFormatters.formatTime(h.acceptedAt!)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.success),
                                ),
                              ],
                              if (h.rejectedAt != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${AppStrings.rejected}: ${AppFormatters.formatDate(h.rejectedAt!)} ${AppFormatters.formatTime(h.rejectedAt!)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.danger),
                                ),
                              ],
                              if (h.cancelledAt != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${AppStrings.cancelled}: ${AppFormatters.formatDate(h.cancelledAt!)} ${AppFormatters.formatTime(h.cancelledAt!)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                              if (h.notes != null && h.notes!.isNotEmpty) ...[  
                                const SizedBox(height: 4),
                                Text('${AppStrings.notes}: ${h.notes}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textSecondary)),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWithdrawalsTab() {
    return StreamBuilder<List<WithdrawalModel>>(
      stream: _financialService.watchAllWithdrawals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorView(snapshot.error);
        }

        final rawWithdrawals = snapshot.data ?? [];

        // Pipeline: Search → Type filter → Status filter → Sort (raw DateTime/double)
        var withdrawals = rawWithdrawals;
        if (_withdrawalSearch.isNotEmpty) {
          final q = _withdrawalSearch.toLowerCase();
          withdrawals = withdrawals.where((w) =>
              w.guardName.toLowerCase().contains(q) ||
              w.adminName.toLowerCase().contains(q) ||
              w.withdrawalId.toLowerCase().contains(q) ||
              w.shiftId.toLowerCase().contains(q) ||
              w.type.toLowerCase().contains(q) ||
              w.status.toLowerCase().contains(q)).toList();
        }
        if (_withdrawalTypeFilter != 'all') {
          withdrawals = withdrawals.where((w) => w.type.toUpperCase() == _withdrawalTypeFilter).toList();
        }
        if (_withdrawalStatusFilter != 'all') {
          withdrawals = withdrawals.where((w) => w.status.toUpperCase() == _withdrawalStatusFilter).toList();
        }
        switch (_withdrawalSort) {
          case AdminPaymentSort.newestFirst:
            withdrawals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case AdminPaymentSort.oldestFirst:
            withdrawals.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            break;
          case AdminPaymentSort.highestAmount:
            withdrawals.sort((a, b) => b.amount.compareTo(a.amount));
            break;
          case AdminPaymentSort.lowestAmount:
            withdrawals.sort((a, b) => a.amount.compareTo(b.amount));
            break;
        }

        return Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _withdrawalSearchController,
                          decoration: InputDecoration(
                            hintText: AppStrings.searchWithdrawalsHint,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _withdrawalSearch.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(() {
                                      _withdrawalSearchController.clear();
                                      _withdrawalSearch = '';
                                    }),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _withdrawalSearch = v.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<AdminPaymentSort>(
                        initialValue: _withdrawalSort,
                        tooltip: AppStrings.sortBy,
                        onSelected: (s) => setState(() => _withdrawalSort = s),
                        itemBuilder: (ctx) => [
                          _adminSortItem(AdminPaymentSort.newestFirst, AppStrings.newestFirst, _withdrawalSort),
                          _adminSortItem(AdminPaymentSort.oldestFirst, AppStrings.oldestFirst, _withdrawalSort),
                          _adminSortItem(AdminPaymentSort.highestAmount, AppStrings.highestAmount, _withdrawalSort),
                          _adminSortItem(AdminPaymentSort.lowestAmount, AppStrings.lowestAmount, _withdrawalSort),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.sort, size: 16, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in ['all', 'CASH', 'UPI']) ...[  
                          FilterChip(
                            label: Text(t == 'all' ? AppStrings.all : AppStrings.formatPaymentMethod(t), style: const TextStyle(fontSize: 11)),
                            selected: _withdrawalTypeFilter == t,
                            onSelected: (_) => setState(() => _withdrawalTypeFilter = t),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const VerticalDivider(width: 12),
                        for (final s in ['all', 'COMPLETED', 'CANCELLED']) ...[  
                          FilterChip(
                            label: Text(s == 'all' ? AppStrings.allStatus : AppStrings.formatStatus(s), style: const TextStyle(fontSize: 11)),
                            selected: _withdrawalStatusFilter == s,
                            onSelected: (_) => setState(() => _withdrawalStatusFilter = s),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: withdrawals.isEmpty
                  ? Center(
                      child: Text(
                        _withdrawalSearch.isNotEmpty || _withdrawalTypeFilter != 'all' || _withdrawalStatusFilter != 'all'
                            ? AppStrings.noMatchingRecords
                            : AppStrings.noWithdrawalHistory,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: withdrawals.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final w = withdrawals[index];

                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      StatusBadge(
                                        label: AppStrings.formatPaymentMethod(w.type),
                                        type: w.type == 'CASH' ? BadgeType.active : BadgeType.info,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppFormatters.formatCurrency(w.amount),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: AppColors.danger),
                                      ),
                                    ],
                                  ),
                                  StatusBadge(label: AppStrings.formatStatus(w.status), type: w.status == 'COMPLETED' ? BadgeType.active : BadgeType.danger),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${AppStrings.entryGuard}: ${w.guardName} • ${AppStrings.withdrawnBy}: ${w.adminName}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('ID: ${w.withdrawalId.substring(0, w.withdrawalId.length > 8 ? 8 : w.withdrawalId.length)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  if (w.shiftId.isNotEmpty) ...[
                                    const Text(' • ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    Text('${AppStrings.shift}: ${w.shiftId.substring(0, w.shiftId.length > 8 ? 8 : w.shiftId.length)}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                              if (w.previousOutstanding != null || w.remainingOutstanding != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (w.previousOutstanding != null)
                                      Text('${AppStrings.previousOutstanding}: ${AppFormatters.formatCurrency(w.previousOutstanding!)}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    if (w.previousOutstanding != null && w.remainingOutstanding != null)
                                      const Text(' • ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    if (w.remainingOutstanding != null)
                                      Text('${AppStrings.remainingOutstanding}: ${AppFormatters.formatCurrency(w.remainingOutstanding!)}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                '${AppStrings.timestamp}: ${AppFormatters.formatDate(w.createdAt)} ${AppFormatters.formatTime(w.createdAt)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuardAndShiftReportsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: AppStrings.guardWiseSummary),
              Tab(text: AppStrings.shiftWiseSummary),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildGuardWiseReportTab(),
                _buildShiftWiseReportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSpecificWithdrawalDialog(GuardModel guard, String type, double currentOutstanding) async {
    final cleanType = type.trim().toUpperCase();
    final isCash = cleanType == 'CASH';
    final amountController = TextEditingController();
    String? validationError;
    double enteredAmount = 0.0;
    double remainingAmount = currentOutstanding;

    final selectedAmount = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateCalculations(String val) {
              final trimmed = val.trim();
              if (trimmed.isEmpty) {
                setDialogState(() {
                  enteredAmount = 0.0;
                  remainingAmount = currentOutstanding;
                  validationError = null;
                });
                return;
              }
              final parsed = double.tryParse(trimmed);
              if (parsed == null || parsed <= 0) {
                setDialogState(() {
                  enteredAmount = 0.0;
                  remainingAmount = currentOutstanding;
                  validationError = AppStrings.withdrawalMustBeGreaterThanZero;
                });
                return;
              }
              if (parsed > currentOutstanding) {
                final methodStr = isCash ? 'cash' : 'UPI';
                setDialogState(() {
                  enteredAmount = parsed;
                  remainingAmount = 0.0;
                  validationError = AppStrings.withdrawalAmountExceeds(
                    methodStr,
                    AppFormatters.formatCurrency(currentOutstanding),
                  );
                });
                return;
              }
              setDialogState(() {
                enteredAmount = parsed;
                remainingAmount = (currentOutstanding - parsed).clamp(0.0, double.infinity);
                validationError = null;
              });
            }

            final canProceed = enteredAmount > 0 && enteredAmount <= currentOutstanding && validationError == null;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(
                    isCash ? Icons.money : Icons.qr_code,
                    color: isCash ? AppColors.cashColor : AppColors.upiColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCash ? AppStrings.withdrawCash : AppStrings.withdrawUpi,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(AppStrings.guard, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(guard.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isCash ? AppStrings.currentCashOutstanding : AppStrings.currentUpiOutstanding,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                Text(
                                  AppFormatters.formatCurrency(currentOutstanding),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: isCash ? AppColors.cashColor : AppColors.upiColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.withdrawalAmount,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        key: const ValueKey('withdrawal_amount_input'),
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: AppStrings.enterAmount,
                          prefixText: '₹ ',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          errorText: validationError,
                          errorMaxLines: 2,
                        ),
                        onChanged: updateCalculations,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppStrings.remainingAfterWithdrawal,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                            ),
                            Text(
                              AppFormatters.formatCurrency(remainingAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
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
                  onPressed: () => Navigator.pop(dialogCtx, null),
                  child: Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  key: const ValueKey('proceed_withdrawal_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCash ? AppColors.cashColor : AppColors.upiColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: canProceed ? () => Navigator.pop(dialogCtx, enteredAmount) : null,
                  child: Text(isCash ? AppStrings.withdrawCash : AppStrings.withdrawUpi),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedAmount == null || selectedAmount <= 0 || !mounted) return;

    // Step 2: Confirmation Dialog with authoritative re-read and double-click protection
    final adminUser = FirebaseAuth.instance.currentUser;
    final adminUid = adminUser?.uid ?? 'admin';
    final adminName = adminUser?.displayName ?? 'Admin';
    final now = DateTime.now();
    final remainingAfterWithdrawal = (currentOutstanding - selectedAmount).clamp(0.0, double.infinity);

    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (confirmCtx) {
        return StatefulBuilder(
          builder: (dialogContext, setConfirmState) {
            Future<void> handleConfirm() async {
              setConfirmState(() => isSubmitting = true);
              try {
                await _financialService.adminWithdrawSpecific(
                  guardId: guard.uid,
                  guardName: guard.name,
                  shiftId: 'admin_settlement_${DateTime.now().millisecondsSinceEpoch}',
                  type: cleanType,
                  amount: selectedAmount,
                  adminUid: adminUid,
                  adminName: adminName,
                );

                if (confirmCtx.mounted) {
                  Navigator.pop(confirmCtx);
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${AppStrings.withdrawn}: ${AppFormatters.formatCurrency(selectedAmount)} ($cleanType - ${guard.name})'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                setConfirmState(() => isSubmitting = false);
                if (confirmCtx.mounted) {
                  Navigator.pop(confirmCtx);
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceAll('Exception:', '').replaceAll('StateError:', '').trim()),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: isCash ? AppColors.cashColor : AppColors.upiColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCash ? AppStrings.confirmCashWithdrawal : AppStrings.confirmUpiWithdrawal,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConfirmRow(AppStrings.guard, guard.name),
                    const SizedBox(height: 8),
                    _buildConfirmRow(
                      isCash ? AppStrings.currentCashOutstanding : AppStrings.currentUpiOutstanding,
                      AppFormatters.formatCurrency(currentOutstanding),
                    ),
                    const SizedBox(height: 8),
                    _buildConfirmRow(
                      AppStrings.withdrawalAmount,
                      AppFormatters.formatCurrency(selectedAmount),
                      isHighlight: true,
                    ),
                    const SizedBox(height: 8),
                    _buildConfirmRow(
                      AppStrings.remainingAfterWithdrawal,
                      AppFormatters.formatCurrency(remainingAfterWithdrawal),
                    ),
                    const Divider(height: 20),
                    _buildConfirmRow(AppStrings.withdrawnBy, adminName),
                    const SizedBox(height: 8),
                    _buildConfirmRow(AppStrings.timestamp, AppFormatters.formatDateTime(now)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(confirmCtx),
                  child: Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  key: const ValueKey('confirm_withdrawal_submit_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCash ? AppColors.cashColor : AppColors.upiColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSubmitting ? null : handleConfirm,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(AppStrings.confirmWithdrawal),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildConfirmRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            fontSize: isHighlight ? 14 : 12,
            color: isHighlight ? AppColors.danger : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
