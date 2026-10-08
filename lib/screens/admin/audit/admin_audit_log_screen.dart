import 'package:flutter/material.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/audit_log_model.dart';
import '../../../services/audit_service.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/status_badge.dart';

/// Screen displaying the immutable system audit trail for administrative actions.
/// Supports search (Actor, Action, Entity, Entity ID), category filter, and Newest/Oldest sort.
class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  static void show(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminAuditLogScreen()),
    );
  }

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'all';
  bool _newestFirst = true;

  static const _categories = [
    ('all', 'All'),
    ('guard', 'Guard'),
    ('shift', 'Shift'),
    ('settings', 'Settings'),
    ('payment', 'Payment'),
    ('handover', 'Handover'),
    ('withdrawal', 'Withdrawal'),
    ('security', 'Security'),
    ('device', 'Device'),
    ('report', 'Report'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auditService = AuditService.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('System Audit Trail', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
      ),
      body: StreamBuilder<List<AuditLogModel>>(
        stream: auditService.watchRecentLogs(limit: 100),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final raw = snapshot.data ?? [];

          // Pipeline: Search → Category filter → Sort (using actual DateTime timestamps)
          var logs = raw;

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            logs = logs.where((l) =>
                l.adminName.toLowerCase().contains(q) ||
                l.adminUid.toLowerCase().contains(q) ||
                l.action.toLowerCase().contains(q) ||
                l.targetEntity.toLowerCase().contains(q) ||
                l.targetId.toLowerCase().contains(q)).toList();
          }

          if (_categoryFilter != 'all') {
            logs = logs.where((l) =>
                l.targetEntity.toLowerCase().contains(_categoryFilter) ||
                l.action.toLowerCase().contains(_categoryFilter)).toList();
          }

          // Sort by actual DateTime — not formatted string
          if (_newestFirst) {
            logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          } else {
            logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          }

          return Column(
            children: [
              // Search + Filter + Sort Controls
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '${AppStrings.search} Actor, Action, Entity, Entity ID...',
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
                                final isSelected = _categoryFilter == cat.$1;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: FilterChip(
                                    label: Text(cat.$2,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        )),
                                    selected: isSelected,
                                    onSelected: (_) => setState(() => _categoryFilter = cat.$1),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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

              // Count badge
              if (logs.isNotEmpty)
                Container(
                  color: AppColors.surfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${logs.length} records',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),

              // Audit Log List
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history_toggle_off, size: 54, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty || _categoryFilter != 'all'
                                    ? AppStrings.noMatchingRecords
                                    : 'No Audit Logs Recorded Yet',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: logs.length,
                        separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          StatusBadge(
                                            label: log.action.replaceAll('_', ' '),
                                            type: _badgeTypeForAction(log.action),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              '${log.targetEntity.toUpperCase()}: ${log.targetId}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      AppFormatters.formatTime(log.timestamp),
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Actor: ${log.adminName} (${log.adminUid})',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                Text(
                                  AppFormatters.formatDate(log.timestamp),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                                if (log.details.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    log.details.entries.map((e) => '${e.key}: ${e.value}').join(' • '),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
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
      ),
    );
  }

  BadgeType _badgeTypeForAction(String action) {
    if (action.contains('CREATE') || action.contains('ADD') || action.contains('ACTIVATE')) {
      return BadgeType.active;
    }
    if (action.contains('CANCEL') || action.contains('DEACTIVATE')) {
      return BadgeType.danger;
    }
    if (action.contains('UPDATE') || action.contains('EDIT') || action.contains('REASSIGN')) {
      return BadgeType.warning;
    }
    return BadgeType.info;
  }
}
