// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/guard_model.dart';
import '../../../models/handover_model.dart';
import '../../../models/payment_transaction_model.dart';
import '../../../models/responsibility_event_model.dart';
import '../../../models/withdrawal_model.dart';
import '../../../services/financial_responsibility_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/payment_service.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../widgets/notifications/notification_dialog.dart';

/// PaymentManagementScreen displays real-time Cash and UPI collection reports
/// derived authoritatively from the 'payment_transactions' Firestore ledger,
/// with separate Cash & UPI financial responsibilities, full handover, and keep-with-me operations.
class PaymentManagementScreen extends StatefulWidget {
  final GuardModel currentGuard;
  final Stream<PaymentReportData>? customReportStream;

  const PaymentManagementScreen({
    super.key,
    required this.currentGuard,
    this.customReportStream,
  });

  @override
  State<PaymentManagementScreen> createState() => _PaymentManagementScreenState();
}

/// Sort modes for Guard Payment Management — uses actual timestamps/amounts.
enum PaymentSort {
  newestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount,
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  final _paymentService = PaymentService();
  final _financialService = FinancialResponsibilityService.instance;
  late Stream<PaymentReportData> _reportStream;
  late Stream<GuardFinancialResponsibility> _responsibilityStream;
  late Stream<List<HandoverModel>> _pendingHandoversStream;

  // Filter for the transactions breakdown list: 'all', 'cash', 'upi'
  String _selectedFilter = 'all';
  // Type filter: 'all', 'advance', 'final', 'refund'
  String _typeFilter = 'all';
  // Period filter: 'today', 'last7', 'last30', 'thisYear', 'custom'
  String _selectedPeriod = 'today';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  // Sort mode
  PaymentSort _sortMode = PaymentSort.newestFirst;
  // Search
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initStream() {
    if (widget.customReportStream != null) {
      _reportStream = widget.customReportStream!;
    } else {
      final now = DateTime.now();
      DateTime? start;
      DateTime? end;
      switch (_selectedPeriod) {
        case 'today':
          start = DateTime(now.year, now.month, now.day);
          break;
        case 'last7':
          start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
          break;
        case 'last30':
          start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
          break;
        case 'thisYear':
          start = DateTime(now.year, 1, 1);
          break;
        case 'custom':
          start = _customStartDate;
          end = _customEndDate != null
              ? DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59)
              : null;
          break;
      }
      _reportStream = _paymentService.watchPaymentReport(
        guardUid: widget.currentGuard.uid,
        startDate: start,
        endDate: end,
      );
    }
    _responsibilityStream = _financialService.watchGuardResponsibility(
      widget.currentGuard.uid,
      widget.currentGuard.name,
    );
    _pendingHandoversStream = _financialService.watchPendingHandoversForGuard(widget.currentGuard.uid);
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _initStream();
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
              AppStrings.paymentManagement,
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
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: AppColors.border, height: 1),
            ),
          ),
          body: StreamBuilder<PaymentReportData>(
            stream: _reportStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return _buildLoadingState();
              }

              if (snapshot.hasError) {
                return _buildErrorState('${snapshot.error}');
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

                  return StreamBuilder<List<HandoverModel>>(
                    stream: _pendingHandoversStream,
                    initialData: const [],
                    builder: (context, pendingSnap) {
                      final pendingList = pendingSnap.data ?? const [];
                      return _buildReportContent(report, resp, pendingList);
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.loading,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_problem, size: 54, color: AppColors.warning),
            const SizedBox(height: 16),
            Text(
              AppStrings.unableToLoadPaymentReport,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: AppStrings.retry,
              icon: Icons.refresh,
              type: AppButtonType.primary,
              onPressed: () {
                setState(() {
                  _initStream();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(
    PaymentReportData report,
    GuardFinancialResponsibility resp,
    List<HandoverModel> pendingHandovers,
  ) {
    // Pipeline: Search → Method Filter → Type Filter → Sort
    // IMPORTANT: use raw DateTime (createdAt) and double (amount) for sorting—never formatted strings
    var filtered = report.transactions.where((txn) {
      // Method filter
      if (_selectedFilter == 'cash' && !txn.isCash) return false;
      if (_selectedFilter == 'upi' && !txn.isUpi) return false;
      // Type filter
      if (_typeFilter == 'advance' && !txn.isAdvance) return false;
      if (_typeFilter == 'final' && !txn.isFinal) return false;
      if (_typeFilter == 'refund' && !txn.isRefund) return false;
      // Search: transaction ID, ticket number, vehicle number
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return txn.transactionId.toLowerCase().contains(q) ||
            txn.ticketId.toLowerCase().contains(q) ||
            txn.vehicleNumber.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // Sort using raw values
    switch (_sortMode) {
      case PaymentSort.newestFirst:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case PaymentSort.oldestFirst:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case PaymentSort.highestAmount:
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case PaymentSort.lowestAmount:
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
    final filteredTransactions = filtered;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _initStream();
        });
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pending Handovers Alert Banner
            if (pendingHandovers.isNotEmpty) _buildPendingHandoversBanner(pendingHandovers),

            // Period Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip(AppStrings.todayPeriod, 'today'),
                  const SizedBox(width: 6),
                  _buildPeriodChip(AppStrings.last7DaysPeriod, 'last7'),
                  const SizedBox(width: 6),
                  _buildPeriodChip(AppStrings.last30DaysPeriod, 'last30'),
                  const SizedBox(width: 6),
                  _buildPeriodChip(AppStrings.thisYearPeriod, 'thisYear'),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.date_range, size: 14),
                    label: Text(
                      _selectedPeriod == 'custom' && _customStartDate != null && _customEndDate != null
                          ? '${AppFormatters.formatDate(_customStartDate!)} - ${AppFormatters.formatDate(_customEndDate!)}'
                          : AppStrings.customDateRangePeriod,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _selectedPeriod == 'custom' ? FontWeight.bold : FontWeight.normal,
                        color: _selectedPeriod == 'custom' ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    onPressed: _pickCustomRange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Top Summary Card: Total Collection
            _buildTotalSummaryCard(report.todayTotalCollection),
            const SizedBox(height: 16),

            // Two Separate Independent Cards: Cash & UPI
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildCashCard(
                    report: report,
                    resp: resp,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildUpiCard(
                    report: report,
                    resp: resp,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // History Quick Actions Bar (Wrap for responsive mobile/tablet layout)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 40) / 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    icon: const Icon(Icons.lock_clock, size: 14, color: AppColors.warning),
                    label: const Text('Keep With Me History', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    onPressed: _showKeepWithMeHistoryModal,
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 40) / 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    icon: const Icon(Icons.swap_horiz, size: 14, color: AppColors.primary),
                    label: const Text('Handover History', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    onPressed: _showHandoverHistoryModal,
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 40) / 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    icon: const Icon(Icons.account_balance_outlined, size: 14, color: AppColors.success),
                    label: const Text('Withdrawals', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    onPressed: _showWithdrawalHistoryModal,
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 40) / 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    icon: const Icon(Icons.history_edu, size: 14, color: AppColors.textSecondary),
                    label: const Text('Responsibility', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    onPressed: _showResponsibilityHistoryModal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // View Transactions Header, Search, Filter & Sort
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Txn ID, Ticket, Vehicle...',
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
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
                const SizedBox(height: 10),
                // Method + Type chips + Sort
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(AppStrings.transactions,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                )),
                            const SizedBox(width: 10),
                            _buildFilterChip(label: AppStrings.all, value: 'all'),
                            const SizedBox(width: 6),
                            _buildFilterChip(label: AppStrings.cashLabel, value: 'cash'),
                            const SizedBox(width: 6),
                            _buildFilterChip(label: AppStrings.upiLabel, value: 'upi'),
                            const SizedBox(width: 6),
                            _buildTypeFilterChip(label: AppStrings.advance, value: 'advance'),
                            const SizedBox(width: 6),
                            _buildTypeFilterChip(label: AppStrings.finalPayment, value: 'final'),
                            const SizedBox(width: 6),
                            _buildTypeFilterChip(label: AppStrings.refund, value: 'refund'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<PaymentSort>(
                      initialValue: _sortMode,
                      tooltip: AppStrings.sortBy,
                      onSelected: (s) => setState(() => _sortMode = s),
                      itemBuilder: (ctx) => [
                        _paymentSortItem(PaymentSort.newestFirst, AppStrings.newestFirst),
                        _paymentSortItem(PaymentSort.oldestFirst, AppStrings.oldestFirst),
                        _paymentSortItem(PaymentSort.highestAmount, AppStrings.highestAmount),
                        _paymentSortItem(PaymentSort.lowestAmount, AppStrings.lowestAmount),
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
            const SizedBox(height: 12),

            // Transaction List or Empty State
            if (filteredTransactions.isEmpty)
              _buildEmptyTransactionsCard()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTransactions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final txn = filteredTransactions[index];
                  return _buildTransactionItemCard(txn);
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSummaryCard(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.todayTotalCollection.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      AppFormatters.formatDate(DateTime.now()),
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
          const SizedBox(height: 10),
          Text(
            AppFormatters.formatCurrency(total),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashCard({
    required PaymentReportData report,
    required GuardFinancialResponsibility resp,
  }) {
    final collection = resp.totalCashCollected > 0 ? resp.totalCashCollected : report.collectedCash;
    final outstanding = resp.totalCashCollected > 0
        ? resp.outstandingCash
        : (report.collectedCash - resp.cashHandedOver - resp.cashWithdrawn).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.cashColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.money, size: 18, color: AppColors.cashColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.cashCollection,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.expectedCash,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppFormatters.formatCurrency(report.expectedCash),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppStrings.collectedCash,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppFormatters.formatCurrency(collection),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.cashColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Text(
            'Outstanding Responsibility',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            'Bal: ${AppFormatters.formatCurrency(outstanding)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: outstanding > 0 ? AppColors.danger : AppColors.success,
            ),
          ),
          const SizedBox(height: 14),
          if (outstanding > 0) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cashColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openHandoverModal('CASH', outstanding),
                child: Text(
                  'Handover ${AppFormatters.formatCurrency(outstanding)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showKeepWithMeDialog('CASH', outstanding),
                child: Text(
                  'Keep With Me ${AppFormatters.formatCurrency(outstanding)}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  'Settled • ₹0 Outstanding',
                  style: TextStyle(fontSize: 10, color: AppColors.successDark, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpiCard({
    required PaymentReportData report,
    required GuardFinancialResponsibility resp,
  }) {
    final collection = resp.totalUpiCollected > 0 ? resp.totalUpiCollected : report.collectedUpi;
    final outstanding = resp.totalUpiCollected > 0
        ? resp.outstandingUpi
        : (report.collectedUpi - resp.upiHandedOver - resp.upiWithdrawn).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.upiColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_2, size: 18, color: AppColors.upiColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.upiCollection,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.expectedUpi,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppFormatters.formatCurrency(report.expectedUpi),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppStrings.collectedUpi,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppFormatters.formatCurrency(collection),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.upiColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Text(
            'Outstanding Responsibility',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            'Bal: ${AppFormatters.formatCurrency(outstanding)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: outstanding > 0 ? AppColors.danger : AppColors.success,
            ),
          ),
          const SizedBox(height: 14),
          if (outstanding > 0) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.upiColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openHandoverModal('UPI', outstanding),
                child: Text(
                  'Handover ${AppFormatters.formatCurrency(outstanding)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showKeepWithMeDialog('UPI', outstanding),
                child: Text(
                  'Keep With Me ${AppFormatters.formatCurrency(outstanding)}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Text(
                  'Settled • ₹0 Outstanding',
                  style: TextStyle(fontSize: 10, color: AppColors.successDark, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingHandoversBanner(List<HandoverModel> handovers) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions, color: AppColors.warningDark, size: 20),
              const SizedBox(width: 8),
              Text(
                'Incoming Handover Requests (${handovers.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.warningDark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...handovers.map((h) {
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${h.fromGuardName} has handed over ${AppFormatters.formatCurrency(h.amount)} ${h.type} responsibility to you.',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        try {
                          await _financialService.respondToHandover(
                            handoverId: h.handoverId,
                            accept: true,
                            guardUid: widget.currentGuard.uid,
                            guardName: widget.currentGuard.name,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppStrings.handoverAcceptedSuccess)),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            final errStr = e.toString().replaceFirst('Exception: ', '').trim();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errStr.isNotEmpty ? errStr : AppStrings.unableToAcceptHandover)),
                            );
                          }
                        }
                      },
                      child: Text(AppStrings.accept, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _openHandoverModal(String type, double amount) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('guards').get();
      final allGuards = snap.docs.map((d) => GuardModel.fromFirestore(d)).toList();
      var otherGuards = allGuards
          .where((g) => g.isActive && g.uid != widget.currentGuard.uid)
          .toList();
      if (otherGuards.isEmpty) {
        otherGuards = allGuards.where((g) => g.uid != widget.currentGuard.uid).toList();
      }

      if (!mounted) return;

      if (otherGuards.isEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppStrings.noReceivingGuardAvailable),
            content: Text(AppStrings.noReceivingGuardMessage),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.ok)),
            ],
          ),
        );
        return;
      }

      GuardModel selectedGuard = otherGuards.first;
      final notesController = TextEditingController();
      bool isSubmitting = false;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return StatefulBuilder(
            builder: (modalCtx, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${AppStrings.handover} $type ${AppStrings.responsibility}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: type == 'CASH' ? AppColors.cashLight : AppColors.upiLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${AppStrings.full} $type ${AppStrings.outstanding}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(AppFormatters.formatCurrency(amount), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: type == 'CASH' ? AppColors.cashColor : AppColors.upiColor)),
                          const SizedBox(height: 4),
                          Text(AppStrings.partialHandoversNotPermitted, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(AppStrings.selectReceivingGuard, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<GuardModel>(
                      initialValue: selectedGuard,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: otherGuards.map((g) {
                        return DropdownMenuItem(value: g, child: Text('${g.name} (${g.email})'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedGuard = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: '${AppStrings.handover} ${AppStrings.notes} (${AppStrings.optional})',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: '${AppStrings.handover} ${AppFormatters.formatCurrency(amount)}',
                      isLoading: isSubmitting,
                      onPressed: isSubmitting ? null : () async {
                        setModalState(() => isSubmitting = true);
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);
                        try {
                          await _financialService.initiateHandover(
                            fromGuardId: widget.currentGuard.uid,
                            fromGuardName: widget.currentGuard.name,
                            fromGuardEmail: widget.currentGuard.email,
                            toGuardId: selectedGuard.uid,
                            toGuardName: selectedGuard.name,
                            toGuardEmail: selectedGuard.email,
                            shiftId: widget.currentGuard.currentShift.isNotEmpty
                                ? widget.currentGuard.currentShift
                                : 'shift_${DateTime.now().millisecondsSinceEpoch}',
                            type: type,
                            amount: amount,
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          );
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(content: Text('$type Handover of ${AppFormatters.formatCurrency(amount)} initiated to ${selectedGuard.name}.')),
                          );
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text('Handover failed: $e')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading guards: $e')));
      }
    }
  }

  Future<void> _showKeepWithMeDialog(String type, double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${AppStrings.keepFullWithMe} ($type)'),
        content: Text(
          'Confirm keeping full ${AppFormatters.formatCurrency(amount)} $type responsibility with you?\n\nThis amount will remain your active financial responsibility until settled or withdrawn.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.keepWithMe, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _financialService.recordKeepWithMe(
          guardId: widget.currentGuard.uid,
          guardName: widget.currentGuard.name,
          shiftId: widget.currentGuard.currentShift.isNotEmpty
              ? widget.currentGuard.currentShift
              : 'shift_${DateTime.now().millisecondsSinceEpoch}',
          type: type,
          amount: amount,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Retained full ${AppFormatters.formatCurrency(amount)} $type responsibility.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Keep With Me failed: $e')),
          );
        }
      }
    }
  }

  void _showKeepWithMeHistoryModal() {
    String period = 'today';
    DateTime? customStart;
    DateTime? customEnd;
    String method = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (sheetCtx, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lock_clock, color: AppColors.warning, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                AppStrings.keepWithMeHistory,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Period filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildModalFilterChip(AppStrings.today, 'today', period, (v) => setModalState(() => period = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.last7Days, 'last7', period, (v) => setModalState(() => period = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.last30Days, 'last30', period, (v) => setModalState(() => period = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.thisYear, 'thisYear', period, (v) => setModalState(() => period = v)),
                            const SizedBox(width: 6),
                            ActionChip(
                              avatar: const Icon(Icons.date_range, size: 14),
                              label: Text(
                                period == 'custom' && customStart != null && customEnd != null
                                    ? '${AppFormatters.formatDate(customStart!)} - ${AppFormatters.formatDate(customEnd!)}'
                                    : AppStrings.custom,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: period == 'custom' ? FontWeight.bold : FontWeight.normal,
                                  color: period == 'custom' ? AppColors.primary : AppColors.textPrimary,
                                ),
                              ),
                              onPressed: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2025, 1, 1),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    period = 'custom';
                                    customStart = picked.start;
                                    customEnd = picked.end;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Method filter chips (Cash & UPI separate)
                      Row(
                        children: [
                          _buildModalFilterChip(AppStrings.all, 'all', method, (v) => setModalState(() => method = v)),
                          const SizedBox(width: 6),
                          _buildModalFilterChip(AppStrings.cashLabel, 'CASH', method, (v) => setModalState(() => method = v)),
                          const SizedBox(width: 6),
                          _buildModalFilterChip(AppStrings.upiLabel, 'UPI', method, (v) => setModalState(() => method = v)),
                        ],
                      ),
                      const Divider(height: 16),

                      Expanded(
                        child: StreamBuilder<List<ResponsibilityEventModel>>(
                          stream: _financialService.watchGuardKeepWithMeEvents(widget.currentGuard.uid),
                          builder: (streamCtx, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(AppStrings.unableToLoadKeepWithMe, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ),
                              );
                            }
                            final rawEvents = snapshot.data ?? [];
                            final filtered = rawEvents.where((ev) {
                              if (method != 'all' && ev.type.toUpperCase() != method) return false;
                              return _filterByPeriod(ev.createdAt, period, customStart, customEnd);
                            }).toList();

                            if (filtered.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Text(AppStrings.noKeepWithMeHistory, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ),
                              );
                            }

                            return ListView.separated(
                              controller: scrollController,
                              itemCount: filtered.length,
                              separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                              itemBuilder: (context, idx) {
                                final ev = filtered[idx];
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
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                ev.isCash ? Icons.money : Icons.qr_code_2,
                                                color: ev.isCash ? AppColors.cashColor : AppColors.upiColor,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${ev.type}: ${AppFormatters.formatCurrency(ev.amount)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ],
                                          ),
                                          StatusBadge(
                                            label: AppStrings.carriedForward,
                                            type: BadgeType.warning,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Guard: ${ev.guardName} • Shift: ${ev.shiftId}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Action: ${ev.action} • Date: ${AppFormatters.formatDate(ev.createdAt)} at ${AppFormatters.formatTime(ev.createdAt)}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showHandoverHistoryModal() {
    String period = 'today';
    DateTime? customStart;
    DateTime? customEnd;
    String method = 'all';
    String status = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (sheetCtx, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.swap_horiz, color: AppColors.primary, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                AppStrings.handoverHistory,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Period filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildModalFilterChip(AppStrings.today, 'today', period, (v) => setModalState(() => period = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.last7Days, 'last7', period, (v) => setModalState(() => period = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.last30Days, 'last30', period, (v) => setModalState(() => period = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.thisYear, 'thisYear', period, (v) => setModalState(() => period = v)),
                            const SizedBox(width: 6),
                            ActionChip(
                              avatar: const Icon(Icons.date_range, size: 14),
                              label: Text(
                                period == 'custom' && customStart != null && customEnd != null
                                    ? '${AppFormatters.formatDate(customStart!)} - ${AppFormatters.formatDate(customEnd!)}'
                                    : AppStrings.custom,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: period == 'custom' ? FontWeight.bold : FontWeight.normal,
                                  color: period == 'custom' ? AppColors.primary : AppColors.textPrimary,
                                ),
                              ),
                              onPressed: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2025, 1, 1),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    period = 'custom';
                                    customStart = picked.start;
                                    customEnd = picked.end;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Method + Status filters
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildModalFilterChip(AppStrings.all, 'all', method, (v) => setModalState(() => method = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.cashLabel, 'CASH', method, (v) => setModalState(() => method = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.upiLabel, 'UPI', method, (v) => setModalState(() => method = v)),
                            const SizedBox(width: 12),
                            Container(width: 1, height: 16, color: AppColors.border),
                            const SizedBox(width: 12),
                            _buildModalFilterChip(AppStrings.statusAll, 'all', status, (v) => setModalState(() => status = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.pending, 'PENDING', status, (v) => setModalState(() => status = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.accepted, 'ACCEPTED', status, (v) => setModalState(() => status = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.rejected, 'REJECTED', status, (v) => setModalState(() => status = v)),
                            const SizedBox(width: 6),
                            _buildModalFilterChip(AppStrings.cancelled, 'CANCELLED', status, (v) => setModalState(() => status = v)),
                          ],
                        ),
                      ),
                      const Divider(height: 16),

                      Expanded(
                        child: StreamBuilder<List<HandoverModel>>(
                          stream: _financialService.watchGuardHandovers(widget.currentGuard.uid),
                          builder: (streamCtx, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(AppStrings.unableToLoadHandovers, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ),
                              );
                            }
                            final rawHandovers = snapshot.data ?? [];
                            final filtered = rawHandovers.where((h) {
                              if (method != 'all' && h.type.toUpperCase() != method) return false;
                              if (status != 'all' && h.status.toUpperCase() != status) return false;
                              return _filterByPeriod(h.createdAt, period, customStart, customEnd);
                            }).toList();

                            if (filtered.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Text(AppStrings.noHandoverHistory, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ),
                              );
                            }

                            return ListView.separated(
                              controller: scrollController,
                              itemCount: filtered.length,
                              separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                              itemBuilder: (context, idx) {
                                final h = filtered[idx];
                                final isOutgoing = h.fromGuardId == widget.currentGuard.uid;
                                final isIncoming = h.toGuardId == widget.currentGuard.uid;

                                BadgeType bType = BadgeType.warning;
                                if (h.isAccepted) bType = BadgeType.active;
                                if (h.isRejected || h.isCancelled) bType = BadgeType.danger;

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
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                isOutgoing ? Icons.arrow_upward : Icons.arrow_downward,
                                                color: isOutgoing ? AppColors.warningDark : AppColors.success,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${h.type}: ${AppFormatters.formatCurrency(h.amount)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ],
                                          ),
                                          StatusBadge(label: h.status, type: bType),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'From: ${h.fromGuardName}  ➔  To: ${h.toGuardName}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Shift: ${h.fromShiftId}${h.toShiftId != null ? " ➔ ${h.toShiftId}" : ""} • Handover ID: ${h.handoverId.substring(0, h.handoverId.length > 8 ? 8 : h.handoverId.length)}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Created: ${AppFormatters.formatDate(h.createdAt)} ${AppFormatters.formatTime(h.createdAt)}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      if (h.acceptedAt != null)
                                        Text(
                                          'Accepted: ${AppFormatters.formatDate(h.acceptedAt!)} ${AppFormatters.formatTime(h.acceptedAt!)}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.success),
                                        ),
                                      if (h.rejectedAt != null)
                                        Text(
                                          'Rejected: ${AppFormatters.formatDate(h.rejectedAt!)} ${AppFormatters.formatTime(h.rejectedAt!)}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.danger),
                                        ),
                                      if (h.cancelledAt != null)
                                        Text(
                                          'Cancelled: ${AppFormatters.formatDate(h.cancelledAt!)} ${AppFormatters.formatTime(h.cancelledAt!)}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      if (h.notes != null && h.notes!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text('Notes: ${h.notes}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                                        ),

                                      // Actions if PENDING
                                      if (h.isPending) ...[
                                        const SizedBox(height: 10),
                                        if (isIncoming) ...[
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.success,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                                  ),
                                                  onPressed: () async {
                                                    try {
                                                      await _financialService.respondToHandover(
                                                        handoverId: h.handoverId,
                                                        accept: true,
                                                        guardUid: widget.currentGuard.uid,
                                                        guardName: widget.currentGuard.name,
                                                      );
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Accepted ${h.type} handover.')),
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Error: $e')),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  child: Text(AppStrings.acceptHandover, style: const TextStyle(fontSize: 11)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppColors.danger,
                                                    side: const BorderSide(color: AppColors.danger),
                                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                                  ),
                                                  onPressed: () async {
                                                    try {
                                                      await _financialService.respondToHandover(
                                                        handoverId: h.handoverId,
                                                        accept: false,
                                                        guardUid: widget.currentGuard.uid,
                                                        guardName: widget.currentGuard.name,
                                                      );
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Rejected ${h.type} handover.')),
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Error: $e')),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  child: Text(AppStrings.reject, style: const TextStyle(fontSize: 11)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (isOutgoing) ...[
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.danger,
                                                side: const BorderSide(color: AppColors.danger),
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                              ),
                                              onPressed: () async {
                                                try {
                                                  await _financialService.cancelHandover(
                                                    handoverId: h.handoverId,
                                                    guardUid: widget.currentGuard.uid,
                                                    guardName: widget.currentGuard.name,
                                                  );
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Handover cancelled.')),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Error: $e')),
                                                    );
                                                  }
                                                }
                                              },
                                              child: Text(AppStrings.cancelHandover, style: const TextStyle(fontSize: 11)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ],
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
          },
        );
      },
    );
  }

  Widget _buildModalFilterChip(String label, String value, String currentSelected, ValueChanged<String> onSelected) {
    final isSelected = currentSelected == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      onSelected: (_) => onSelected(value),
    );
  }

  bool _filterByPeriod(DateTime dt, String period, DateTime? customStart, DateTime? customEnd) {
    final now = DateTime.now();
    switch (period) {
      case 'today':
        final start = DateTime(now.year, now.month, now.day);
        return !dt.isBefore(start);
      case 'last7':
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
        return !dt.isBefore(start);
      case 'last30':
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
        return !dt.isBefore(start);
      case 'thisYear':
        final start = DateTime(now.year, 1, 1);
        return !dt.isBefore(start);
      case 'custom':
        if (customStart != null && dt.isBefore(customStart)) return false;
        if (customEnd != null) {
          final end = DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999);
          if (dt.isAfter(end)) return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showWithdrawalHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.withdrawals,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: StreamBuilder<List<WithdrawalModel>>(
                      stream: _financialService.watchGuardWithdrawals(widget.currentGuard.uid),
                      builder: (streamCtx, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(AppStrings.unableToLoadWithdrawals, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ),
                          );
                        }
                        final withdrawals = snapshot.data ?? [];
                        if (withdrawals.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(AppStrings.noWithdrawalHistory, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: withdrawals.length,
                          separatorBuilder: (ctx, idx) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final w = withdrawals[idx];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.successLight,
                                child: const Icon(Icons.account_balance, color: AppColors.successDark, size: 18),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${w.type}: ${AppFormatters.formatCurrency(w.amount)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  StatusBadge(label: AppStrings.withdrawn, type: BadgeType.active),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text('Admin: ${w.adminName} • Remaining: ₹0', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                                  Text('${AppFormatters.formatDate(w.createdAt)} • ${AppFormatters.formatTime(w.createdAt)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
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
      },
    );
  }

  void _showResponsibilityHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.responsibilityHistory,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: StreamBuilder<List<ResponsibilityEventModel>>(
                      stream: _financialService.watchResponsibilityHistory(widget.currentGuard.uid),
                      builder: (streamCtx, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(AppStrings.unableToLoadResponsibility, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ),
                          );
                        }
                        final events = snapshot.data ?? [];
                        if (events.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(AppStrings.noResponsibilityHistory, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: events.length,
                          separatorBuilder: (ctx, idx) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final ev = events[idx];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: ev.isKeepWithMe
                                    ? AppColors.warningLight
                                    : (ev.isWithdrawal ? AppColors.successLight : AppColors.primarySurface),
                                child: Icon(
                                  ev.isKeepWithMe
                                      ? Icons.lock_clock
                                      : (ev.isWithdrawal ? Icons.account_balance : Icons.swap_horiz),
                                  size: 18,
                                  color: ev.isKeepWithMe
                                      ? AppColors.warningDark
                                      : (ev.isWithdrawal ? AppColors.successDark : AppColors.primary),
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${ev.type}: ${AppFormatters.formatCurrency(ev.amount)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  StatusBadge(
                                    label: ev.action.replaceAll('_', ' '),
                                    type: ev.isWithdrawal
                                        ? BadgeType.active
                                        : (ev.isKeepWithMe ? BadgeType.warning : BadgeType.info),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    'Shift: ${ev.shiftId}${ev.targetGuardName != null ? " • With: ${ev.targetGuardName}" : ""}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    '${AppFormatters.formatDate(ev.createdAt)} • ${AppFormatters.formatTime(ev.createdAt)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedPeriod = value;
          _initStream();
        });
      },
    );
  }

  Widget _buildFilterChip({required String label, required String value}) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilterChip({required String label, required String value}) {
    final isSelected = _typeFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          _typeFilter = isSelected ? 'all' : value;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.secondary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<PaymentSort> _paymentSortItem(PaymentSort value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortMode == value)
            const Icon(Icons.check, size: 16, color: AppColors.primary)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            AppStrings.noPaymentTransactionsToday,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItemCard(PaymentTransactionModel txn) {
    Color typeColor;
    String typeLabel;
    IconData typeIcon;

    if (txn.isRefund) {
      typeColor = AppColors.danger;
      typeLabel = AppStrings.refund;
      typeIcon = Icons.remove_circle_outline;
    } else if (txn.isAdvance) {
      typeColor = AppColors.primary;
      typeLabel = AppStrings.advance;
      typeIcon = Icons.arrow_downward;
    } else {
      typeColor = AppColors.success;
      typeLabel = AppStrings.finalPayment;
      typeIcon = Icons.check_circle_outline;
    }

    final isUpi = txn.isUpi;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, size: 20, color: typeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    StatusBadge(
                      label: isUpi ? 'UPI' : 'CASH',
                      type: isUpi ? BadgeType.info : BadgeType.active,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${txn.ticketId.isNotEmpty ? "${AppStrings.ticketLabel} ${txn.ticketId}" : ""} ${txn.vehicleNumber.isNotEmpty ? "• ${txn.vehicleNumber}" : ""}'
                      .trim(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppFormatters.formatDate(txn.createdAt)} ${AppFormatters.formatTime(txn.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${txn.isRefund ? "-" : "+"}${AppFormatters.formatCurrency(txn.amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: txn.isRefund ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
