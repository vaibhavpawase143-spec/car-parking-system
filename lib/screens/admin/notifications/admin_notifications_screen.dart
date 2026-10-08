import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/notification_model.dart';
import '../../../services/notification_service.dart';

/// Admin Notifications Screen showing in-app alerts and notifications.
/// Supports search, category filter (All/Shift/Cash/UPI/Handover/Withdrawal/Security/System),
/// read/unread filter, and Newest/Oldest sort.
class AdminNotificationsScreen extends StatefulWidget {
  final String adminUid;

  const AdminNotificationsScreen({
    super.key,
    required this.adminUid,
  });

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'all'; // all / shift / cash / upi / handover / withdrawal / security / system
  String _readFilter = 'all'; // all / unread / read
  bool _newestFirst = true;

  static const _categories = [
    'all', 'shift', 'cash', 'upi', 'handover', 'withdrawal', 'security', 'system',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'all': return AppStrings.all;
      case 'shift': return AppStrings.shift;
      case 'cash': return AppStrings.cashLabel;
      case 'upi': return AppStrings.upiLabel;
      case 'handover': return AppStrings.handover;
      case 'withdrawal': return AppStrings.withdrawal;
      case 'security': return AppStrings.security;
      case 'system': return AppStrings.systemCategory;
      default: return cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppStrings.notifications, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: () => notificationService.markAllAsRead(widget.adminUid),
            child: Text(AppStrings.markAllAsRead, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: notificationService.watchUserNotifications(widget.adminUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final raw = snapshot.data ?? [];

          // Pipeline: Search → Category filter → Read/Unread → Sort
          var list = raw;

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            list = list.where((n) {
              final locTitle = n.localizedTitle.toLowerCase();
              final locMsg = n.localizedMessage.toLowerCase();
              final origTitle = n.title.toLowerCase();
              final origMsg = n.message.toLowerCase();
              return locTitle.contains(q) || locMsg.contains(q) || origTitle.contains(q) || origMsg.contains(q);
            }).toList();
          }

          if (_categoryFilter != 'all') {
            list = list.where((n) => n.type.toLowerCase() == _categoryFilter).toList();
          }

          if (_readFilter == 'unread') {
            list = list.where((n) => !n.isRead).toList();
          } else if (_readFilter == 'read') {
            list = list.where((n) => n.isRead).toList();
          }

          // Sort using actual DateTime — not formatted strings
          if (_newestFirst) {
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          } else {
            list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          }

          return Column(
            children: [
              // Search + Controls
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: AppStrings.searchNotifications,
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
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _categories.map((cat) {
                                final isSelected = _categoryFilter == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: FilterChip(
                                    label: Text(_categoryLabel(cat),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        )),
                                    selected: isSelected,
                                    onSelected: (_) => setState(() => _categoryFilter = cat),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          tooltip: 'Read/Unread',
                          initialValue: _readFilter,
                          onSelected: (v) => setState(() => _readFilter = v),
                          itemBuilder: (ctx) => [
                            PopupMenuItem(value: 'all', child: Text(AppStrings.all)),
                            PopupMenuItem(value: 'unread', child: Text(AppStrings.unread)),
                            PopupMenuItem(value: 'read', child: Text(AppStrings.read)),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.filter_list, size: 16, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => _newestFirst = !_newestFirst),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _newestFirst ? AppStrings.newestFirst : AppStrings.oldestFirst,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
              const Divider(height: 1),

              // Notification List
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.notifications_none, size: 54, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty || _categoryFilter != 'all' || _readFilter != 'all'
                                    ? AppStrings.noMatchingRecords
                                    : AppStrings.noNotifications,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              if (_searchQuery.isEmpty && _categoryFilter == 'all' && _readFilter == 'all') ...[
                                const SizedBox(height: 6),
                                Text(
                                  AppStrings.noNotificationsDesc,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = list[index];
                          final catColor = _getCategoryColor(item.type);
                          final catBg = catColor.withValues(alpha: 0.12);

                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: !item.isRead
                                    ? AppColors.primaryOrange.withValues(alpha: 0.4)
                                    : AppColors.border,
                                width: !item.isRead ? 1.5 : 1.0,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  if (!item.isRead) {
                                    notificationService.markAsRead(item.notificationId);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: item.isRead
                                            ? AppColors.surfaceVariant
                                            : catBg,
                                        child: Icon(
                                          _getCategoryIcon(item.type),
                                          size: 18,
                                          color: item.isRead ? AppColors.textSecondary : catColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.localizedTitle,
                                              style: TextStyle(
                                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.localizedMessage,
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Text(
                                                  AppFormatters.formatDateTime(item.createdAt),
                                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                                ),
                                                if (item.type.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: catBg,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: catColor.withValues(alpha: 0.3)),
                                                    ),
                                                    child: Text(
                                                      item.localizedCategory.toUpperCase(),
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: catColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!item.isRead)
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryOrange,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getCategoryColor(String type) {
    switch (type.toLowerCase()) {
      case 'shift':
        return AppColors.secondaryNavy;
      case 'cash':
      case 'withdrawal':
        return AppColors.success;
      case 'upi':
        return AppColors.secondaryNavy;
      case 'handover':
        return AppColors.primaryOrange;
      case 'security':
        return AppColors.error;
      case 'system':
      default:
        return AppColors.primaryNavy;
    }
  }

  IconData _getCategoryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'shift':
        return Icons.calendar_today;
      case 'cash':
        return Icons.payments_outlined;
      case 'upi':
        return Icons.qr_code;
      case 'handover':
        return Icons.sync_alt;
      case 'withdrawal':
        return Icons.account_balance_wallet;
      case 'security':
        return Icons.security;
      case 'system':
      default:
        return Icons.notifications;
    }
  }
}
