import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/models/auth_session.dart';
import 'notification_detail_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<NotificationRecord> _notifications = const <NotificationRecord>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    NotificationService.instance.refreshUnreadCount(
      accessToken: widget.session.accessToken,
    );
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await NotificationService.instance
          .fetchNotifications(widget.session.accessToken, page: 1, limit: 50);
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _reload() async {
    await _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    try {
      await NotificationService.instance.markAllNotificationsRead(
        widget.session.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (notification) => NotificationRecord(
                id: notification.id,
                type: notification.type,
                title: notification.title,
                body: notification.body,
                data: notification.data,
                isRead: true,
                createdAt: notification.createdAt,
              ),
            )
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openNotification(NotificationRecord notification) async {
    if (!notification.isRead) {
      try {
        await NotificationService.instance.markNotificationRead(
          widget.session.accessToken,
          notification.id,
        );
        if (mounted) {
          setState(() {
            _notifications = _notifications
                .map(
                  (item) => item.id == notification.id
                      ? NotificationRecord(
                          id: item.id,
                          type: item.type,
                          title: item.title,
                          body: item.body,
                          data: item.data,
                          isRead: true,
                          createdAt: item.createdAt,
                        )
                      : item,
                )
                .toList();
          });
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }

    if (notification.type.trim().toLowerCase() == 'attendance') {
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).pushNamed(
      NotificationDetailPage.routeName,
      arguments: <String, dynamic>{
        'id': notification.id,
        'type': notification.type,
        'title': notification.title,
        'body': notification.body,
        'data': notification.data,
        'created_at': notification.createdAt,
        'is_read': notification.isRead,
      },
    );
  }

  Future<void> _deleteNotification(NotificationRecord notification) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Bildirishnomani o‘chirish'),
              content: const Text('Ushbu bildirishnomani o‘chirmoqchimisiz?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Bekor qilish'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'O‘chirish',
                    style: TextStyle(color: AppTheme.brandColor),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      await NotificationService.instance.deleteNotification(
        widget.session.accessToken,
        notification.id,
      );
      if (!mounted) return;
      setState(() {
        _notifications.removeWhere((item) => item.id == notification.id);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _categoryLabel(String type) {
    switch (type.trim().toLowerCase()) {
      case 'payment':
        return 'To‘lov';
      case 'attendance':
        return 'Davomat';
      case 'lesson':
        return 'Dars';
      case 'report':
        return 'Hisobot';
      default:
        return 'Xabar';
    }
  }

  String _displayTitle(NotificationRecord notification) {
    if (notification.type.trim().toLowerCase() == 'attendance') {
      return 'Davomat belgilandi';
    }
    return notification.title;
  }

  IconData _categoryIcon(String type) {
    switch (type.trim().toLowerCase()) {
      case 'payment':
        return Icons.payments_rounded;
      case 'attendance':
        return Icons.fact_check_rounded;
      case 'lesson':
        return Icons.school_rounded;
      case 'report':
        return Icons.assignment_turned_in_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _previewBody(NotificationRecord notification) {
    final type = notification.type.trim().toLowerCase();
    final data = notification.data;

    if (type == 'attendance') {
      final groupName = data['group_name']?.toString().trim() ?? '';
      final status = _attendanceStatusLabel(
        data['attendance_status']?.toString() ?? '',
      );
      final markedAt = _createdAtLabel(
        data['attendance_marked_at']?.toString().trim() ?? '',
      );
      final parts = <String>[];
      if (groupName.isNotEmpty) parts.add(groupName);
      if (status.isNotEmpty && status != '-') {
        parts.add(status);
      }
      if (markedAt.isNotEmpty) {
        parts.add(markedAt);
      }
      if (parts.isNotEmpty) {
        return parts.join(' • ');
      }
    }

    if (type == 'discount') {
      final amount = data['discount_amount']?.toString().trim() ?? '';
      final reason =
          data['discount_reason']?.toString().trim() ??
          data['description']?.toString().trim() ??
          '';
      final parts = <String>[];
      if (amount.isNotEmpty) parts.add('Chegirma: $amount');
      if (reason.isNotEmpty) parts.add('Sabab: $reason');
      if (parts.isNotEmpty) {
        return parts.join(' • ');
      }
    }

    if (type == 'payment') {
      final amount = data['amount']?.toString().trim().isNotEmpty == true
          ? data['amount'].toString().trim()
          : data['paid_amount']?.toString().trim() ?? '';
      final parts = <String>[];
      if (amount.isNotEmpty) parts.add('$amount so\'m');
      if (parts.isNotEmpty) {
        return parts.join(' • ');
      }
    }

    if (type == 'report') {
      final groupName = data['group_name']?.toString().trim() ?? '';
      final total = data['total']?.toString().trim() ?? '';
      final percent = data['percent']?.toString().trim() ?? '';
      // "Ball" rejimida (grading_enabled=false) foiz ma'noga ega emas.
      final gradingEnabled = data['grading_enabled']?.toString() != 'false';
      final parts = <String>[];
      if (groupName.isNotEmpty) parts.add(groupName);
      if (total.isNotEmpty) parts.add('$total ball');
      if (gradingEnabled && percent.isNotEmpty) parts.add('$percent%');
      if (parts.isNotEmpty) {
        return parts.join(' • ');
      }
    }

    return notification.body;
  }

  String _createdAtLabel(String raw) {
    final parsed = _parseFlexibleDateTime(raw.trim());
    if (parsed == null) return raw.trim();
    final year = parsed.year.toString().padLeft(4, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  String _attendanceStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'keldi':
      case 'present':
        return 'Keldi';
      case 'kelmadi':
      case 'absent':
        return 'Kelmadi';
      case 'kechikdi':
      case 'late':
        return 'Kechikdi';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  DateTime? _parseFlexibleDateTime(String raw) {
    if (raw.isEmpty) return null;

    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;

    final normalized = raw.replaceAll(RegExp(r'\s+GMT.*$'), '').trim();
    final directNormalized = DateTime.tryParse(normalized);
    if (directNormalized != null) return directNormalized;

    final dotMatch = RegExp(
      r'^(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})',
    ).firstMatch(raw);
    if (dotMatch != null) {
      final day = int.tryParse(dotMatch.group(1)!);
      final month = int.tryParse(dotMatch.group(2)!);
      final year = int.tryParse(dotMatch.group(3)!);
      final hour = int.tryParse(dotMatch.group(4)!);
      final minute = int.tryParse(dotMatch.group(5)!);
      if (day != null &&
          month != null &&
          year != null &&
          hour != null &&
          minute != null) {
        return DateTime(year, month, day, hour, minute);
      }
    }

    final jsMatch = RegExp(
      r'^[A-Za-z]{3}\s+([A-Za-z]{3})\s+(\d{1,2})\s+(\d{4})\s+(\d{2}):(\d{2})',
    ).firstMatch(raw);
    if (jsMatch != null) {
      const monthMap = <String, int>{
        'Jan': 1,
        'Feb': 2,
        'Mar': 3,
        'Apr': 4,
        'May': 5,
        'Jun': 6,
        'Jul': 7,
        'Aug': 8,
        'Sep': 9,
        'Oct': 10,
        'Nov': 11,
        'Dec': 12,
      };
      final month = monthMap[jsMatch.group(1)!];
      final day = int.tryParse(jsMatch.group(2)!);
      final year = int.tryParse(jsMatch.group(3)!);
      final hour = int.tryParse(jsMatch.group(4)!);
      final minute = int.tryParse(jsMatch.group(5)!);
      if (month != null &&
          day != null &&
          year != null &&
          hour != null &&
          minute != null) {
        return DateTime(year, month, day, hour, minute);
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Bildirishnomalar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF182033),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: NotificationService.instance.unreadCount,
            builder: (context, unreadCount, _) {
              if (unreadCount <= 0) {
                return const SizedBox(width: 16);
              }

              return TextButton(
                onPressed: _markAllAsRead,
                child: Text(
                  'Hammasi o‘qildi',
                  style: TextStyle(
                    color: AppTheme.brandColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          children: [
            _buildHero(),
            const SizedBox(height: 16),
            if (_isLoading) ...[
              for (var i = 0; i < 5; i++) ...[
                const _NotificationSkeleton(),
                const SizedBox(height: 12),
              ],
            ] else if (_error != null) ...[
              _EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Bildirishnomalar yuklanmadi',
                subtitle: _error!,
              ),
            ] else if (_notifications.isEmpty) ...[
              const _EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Hozircha xabar yo‘q',
                subtitle: 'Yangi bildirishnomalar shu yerda ko‘rinadi.',
              ),
            ] else ...[
              ..._notifications.map(
                (notification) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NotificationCard(
                    notification: notification,
                    displayTitle: _displayTitle(notification),
                    categoryLabel: _categoryLabel(notification.type),
                    categoryIcon: _categoryIcon(notification.type),
                    previewBody: _previewBody(notification),
                    createdAtLabel: _createdAtLabel(notification.createdAt),
                    onTap: () => _openNotification(notification),
                    onDelete: () => _deleteNotification(notification),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.brandColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: AppTheme.brandColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bildirishnomalar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF182033),
                  ),
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<int>(
                  valueListenable: NotificationService.instance.unreadCount,
                  builder: (context, unreadCount, _) {
                    return Text(
                      unreadCount > 0
                          ? '$unreadCount ta o‘qilmagan xabar bor'
                          : 'Hamma xabarlar o‘qilgan',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7B8497),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.displayTitle,
    required this.categoryLabel,
    required this.categoryIcon,
    required this.previewBody,
    required this.createdAtLabel,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationRecord notification;
  final String displayTitle;
  final String categoryLabel;
  final IconData categoryIcon;
  final String previewBody;
  final String createdAtLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notification.isRead
                ? const Color(0xFFE6EBF2)
                : const Color(0xFFF3C6C6),
          ),
        ),
        child: Stack(
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 56, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: notification.isRead
                            ? const Color(0xFFF6F7FB)
                            : AppTheme.brandColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        categoryIcon,
                        color: notification.isRead
                            ? const Color(0xFF7A8394)
                            : AppTheme.brandColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayTitle,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF182033),
                                  ),
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.brandColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            previewBody,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F7FB),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  categoryLabel,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5B6577),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                createdAtLabel,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF8A94A6),
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
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF7A8394),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EBF2)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            _SkeletonCircle(size: 48),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SkeletonLine(widthFactor: 0.7),
                  SizedBox(height: 10),
                  _SkeletonLine(widthFactor: 0.95, height: 12),
                  SizedBox(height: 8),
                  _SkeletonLine(widthFactor: 0.45, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF6),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor, this.height = 14});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE9EEF6),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EBF2)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.brandColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: AppTheme.brandColor, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF182033),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Color(0xFF7B8497),
            ),
          ),
        ],
      ),
    );
  }
}
