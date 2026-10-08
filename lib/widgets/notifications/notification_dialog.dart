import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

/// Modal dialog displaying real-time notifications for the authenticated user,
/// with category filtering, search, unread badge, and single/bulk read operations.
class NotificationDialog extends StatefulWidget {
  final String userId;

  const NotificationDialog({super.key, required this.userId});

  static Future<void> show(BuildContext context, {required String userId}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => NotificationDialog(userId: userId),
    );
  }

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  final NotificationService _service = NotificationService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'all';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getCategoryLabel(String cat) {
    switch (cat) {
      case 'all':
        return AppStrings.all;
      case 'shift':
        return AppStrings.myShift;
      case 'cash':
        return AppStrings.cash;
      case 'upi':
        return AppStrings.upi;
      case 'handover':
        return 'Handover';
      case 'withdrawal':
        return 'Withdrawal';
      case 'security':
        return 'Security';
      case 'system':
        return 'System';
      default:
        return cat.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon, title, unread count, and Mark All Read
          StreamBuilder<int>(
            stream: _service.watchUnreadCount(widget.userId),
            initialData: 0,
            builder: (context, countSnap) {
              final unread = countSnap.data ?? 0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            AppStrings.notifications,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _service.markAllAsRead(widget.userId),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: Text(
                      AppStrings.markAllAsRead,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Search Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search notifications...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 10),

          // Categories horizontal scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCatChip('all'),
                const SizedBox(width: 6),
                _buildCatChip('shift'),
                const SizedBox(width: 6),
                _buildCatChip('cash'),
                const SizedBox(width: 6),
                _buildCatChip('upi'),
                const SizedBox(width: 6),
                _buildCatChip('handover'),
                const SizedBox(width: 6),
                _buildCatChip('withdrawal'),
                const SizedBox(width: 6),
                _buildCatChip('security'),
                const SizedBox(width: 6),
                _buildCatChip('system'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Stream of User Notifications
          Flexible(
            child: StreamBuilder<List<NotificationModel>>(
              stream: _service.watchUserNotifications(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('Error loading notifications: ${snapshot.error}'),
                    ),
                  );
                }

                final rawList = snapshot.data ?? [];

                // Filter by category & search query
                final notifications = rawList.where((item) {
                  if (_selectedCategory != 'all') {
                    final t = item.type.toLowerCase();
                    final text = '${item.title} ${item.message}'.toLowerCase();
                    switch (_selectedCategory) {
                      case 'shift':
                        if (!t.contains('shift')) return false;
                        break;
                      case 'cash':
                        if (!t.contains('cash') && !text.contains('cash') && !text.contains('रोख')) return false;
                        break;
                      case 'upi':
                        if (!t.contains('upi') && !text.contains('upi')) return false;
                        break;
                      case 'handover':
                        if (!t.contains('handover') && !text.contains('handover') && !text.contains('हस्तांतरण')) return false;
                        break;
                      case 'withdrawal':
                        if (!t.contains('withdrawal') && !text.contains('withdrawal') && !text.contains('काढणे')) return false;
                        break;
                      case 'security':
                        if (!t.contains('security') && !t.contains('blocked') && !t.contains('conflict') && !text.contains('security')) return false;
                        break;
                      case 'system':
                        if (t != 'system' && t != 'capacity' && t != 'pass_expiry') return false;
                        break;
                    }
                  }

                  if (_searchQuery.isNotEmpty) {
                    final text = '${item.title} ${item.message}'.toLowerCase();
                    if (!text.contains(_searchQuery)) return false;
                  }

                  return true;
                }).toList();

                if (notifications.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.noNotifications,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.noNotificationsDesc,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return _buildNotificationTile(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatChip(String cat) {
    final isSelected = _selectedCategory == cat;
    return ChoiceChip(
      label: Text(
        _getCategoryLabel(cat),
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedCategory = cat),
    );
  }

  Widget _buildNotificationTile(NotificationModel item) {
    IconData iconData = Icons.info_outline;
    Color iconColor = AppColors.primary;
    String categoryTag = 'SYSTEM';

    final t = item.type.toLowerCase();
    final text = '${item.title} ${item.message}'.toLowerCase();

    if (t.contains('shift')) {
      iconData = Icons.schedule_outlined;
      iconColor = AppColors.primary;
      categoryTag = 'SHIFT';
    } else if (t.contains('handover') || text.contains('handover') || text.contains('हस्तांतरण')) {
      iconData = Icons.swap_horiz;
      iconColor = AppColors.warningDark;
      categoryTag = 'HANDOVER';
    } else if (t.contains('withdrawal') || text.contains('withdrawal') || text.contains('काढणे')) {
      iconData = Icons.account_balance;
      iconColor = AppColors.secondary;
      categoryTag = 'WITHDRAWAL';
    } else if (t.contains('cash') || text.contains('cash') || text.contains('रोख')) {
      iconData = Icons.money;
      iconColor = AppColors.cashColor;
      categoryTag = 'CASH';
    } else if (t.contains('upi') || text.contains('upi')) {
      iconData = Icons.qr_code_2;
      iconColor = AppColors.upiColor;
      categoryTag = 'UPI';
    } else if (t.contains('security') || t.contains('blocked') || t.contains('conflict') || text.contains('security')) {
      iconData = Icons.security;
      iconColor = AppColors.danger;
      categoryTag = 'SECURITY';
    }

    return InkWell(
      onTap: () {
        if (!item.isRead) {
          _service.markAsRead(item.notificationId);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        color: item.isRead ? Colors.transparent : AppColors.primarySurface.withValues(alpha: 0.35),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          categoryTag,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: item.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${AppFormatters.formatDate(item.createdAt)} ${AppFormatters.formatTime(item.createdAt)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (!item.isRead)
                        InkWell(
                          onTap: () => _service.markAsRead(item.notificationId),
                          child: const Text(
                            'Mark Read',
                            style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
