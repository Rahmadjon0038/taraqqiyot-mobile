import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({super.key, required this.payload});

  static const String routeName = '/notification-detail';

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final title = _stringValue(payload['title'], fallback: 'Bildirishnoma');
    final body = _stringValue(payload['body']);
    final type = _stringValue(payload['type'], fallback: 'payment');
    final createdAt = _stringValue(payload['created_at']);
    final createdAtLabel = _formatDateTimeLabel(createdAt);
    final data = _extractData(payload);
    final attendanceGroup = _stringValue(data['group_name']);
    final attendanceTeacher = _stringValue(data['teacher_name']);
    final attendanceSubject = _stringValue(data['subject_name']);
    final attendanceStatus = _stringValue(data['attendance_status']);
    final paymentAmount = _extractPaymentAmount(data);
    final discountAmount = _extractDiscountAmount(data);
    final discountReason = _extractDiscountReason(payload);
    final paymentReceiverName = _extractPaymentReceiverName(payload);
    final displayBody = _buildDisplayBody(
      type: type,
      attendanceGroup: attendanceGroup,
      attendanceTeacher: attendanceTeacher,
      attendanceSubject: attendanceSubject,
      attendanceStatus: attendanceStatus,
      paymentAmount: paymentAmount,
      discountAmount: discountAmount,
      discountReason: discountReason,
      paymentReceiverName: paymentReceiverName,
      fallbackBody: body,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Bildirishnoma',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF182033),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.brandColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    _iconForType(type),
                    color: AppTheme.brandColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF182033),
                        ),
                      ),
                      if (createdAt.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          createdAtLabel,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7B8497),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (type == 'discount' && discountAmount.isNotEmpty) ...[
                        _InfoChip(
                          icon: Icons.local_offer_rounded,
                          title: 'Chegirma',
                          value: discountAmount,
                        ),
                        const SizedBox(height: 8),
                        if (discountReason.isNotEmpty)
                          _InfoChip(
                            icon: Icons.notes_rounded,
                            title: 'Sabab',
                            value: discountReason,
                          ),
                      ] else if (type == 'attendance') ...[
                        _InfoChip(
                          icon: Icons.fact_check_rounded,
                          title: 'Davomat',
                          value: _attendanceStatusLabel(attendanceStatus),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: type == 'attendance'
                  ? [
                      Text(
                        displayBody.isEmpty
                            ? 'Mazmun mavjud emas'
                            : displayBody,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DetailRow(
                        label: 'Guruh',
                        value: attendanceGroup.isEmpty ? '-' : attendanceGroup,
                      ),
                      const SizedBox(height: 10),
                      _DetailRow(
                        label: 'Fan',
                        value: attendanceSubject.isEmpty
                            ? '-'
                            : attendanceSubject,
                      ),
                      const SizedBox(height: 10),
                      _DetailRow(
                        label: 'Teacher',
                        value: attendanceTeacher.isEmpty
                            ? '-'
                            : attendanceTeacher,
                      ),
                      const SizedBox(height: 10),
                      _DetailRow(
                        label: 'Holat',
                        value: _attendanceStatusLabel(attendanceStatus),
                        valueColor: _attendanceStatusColor(attendanceStatus),
                      ),
                    ]
                  : [
                      Text(
                        displayBody.isEmpty
                            ? 'Mazmun mavjud emas'
                            : displayBody,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (type != 'discount' &&
                          paymentReceiverName.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F7FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFD7E3F8)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                size: 18,
                                color: Color(0xFF4F6FA6),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'To\'lov qabul qiluvchi: $paymentReceiverName',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.35,
                                    color: Color(0xFF31455F),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _extractData(Map<String, dynamic> payload) {
    final rawData = payload['data'];
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }

    return <String, dynamic>{};
  }

  String _extractPaymentReceiverName(Map<String, dynamic> payload) {
    final data = _extractData(payload);
    final receiverName = _stringValue(data['payment_receiver_name']);
    if (receiverName.isNotEmpty) {
      return receiverName;
    }

    final adminName = _stringValue(data['admin_name']);
    if (adminName.isNotEmpty) {
      return adminName;
    }

    return _stringValue(payload['payment_receiver_name']);
  }

  String _extractDiscountReason(Map<String, dynamic> payload) {
    final data = _extractData(payload);
    final reason = _stringValue(data['discount_reason']);
    if (reason.isNotEmpty) {
      return reason;
    }

    final description = _stringValue(data['description']);
    if (description.isNotEmpty) {
      return description;
    }

    final body = _stringValue(payload['body']);
    final match = RegExp(r'Sabab:\s*(.+?)(?:[.。!?]\s*$|$)').firstMatch(body);
    if (match != null) {
      return match.group(1)?.trim() ?? '';
    }

    return '';
  }

  String _extractPaymentAmount(Map<String, dynamic> data) {
    final amount = data['amount'] ?? data['paid_amount'];
    final text = _stringValue(amount);
    if (text.isEmpty) {
      return '';
    }

    final parsed = num.tryParse(text);
    if (parsed == null) {
      return text;
    }

    return '${_formatMoney(parsed)} so\'m';
  }

  String _buildDisplayBody({
    required String type,
    required String attendanceGroup,
    required String attendanceTeacher,
    required String attendanceSubject,
    required String attendanceStatus,
    required String paymentAmount,
    required String discountAmount,
    required String discountReason,
    required String paymentReceiverName,
    required String fallbackBody,
  }) {
    if (type == 'attendance') {
      final parts = <String>[];
      if (attendanceGroup.isNotEmpty) {
        parts.add(attendanceGroup);
      }
      final statusLabel = _attendanceStatusLabel(attendanceStatus);
      if (statusLabel.isNotEmpty) {
        parts.add('Davomat: $statusLabel');
      }
      if (attendanceSubject.isNotEmpty) {
        parts.add('Fan: $attendanceSubject');
      }
      if (attendanceTeacher.isNotEmpty) {
        parts.add('Teacher: $attendanceTeacher');
      }
      if (parts.isNotEmpty) {
        return parts.join(' • ');
      }
      return fallbackBody;
    }

    if (type == 'discount') {
      final parts = <String>[];
      if (discountAmount.isNotEmpty) {
        parts.add('Chegirma: $discountAmount');
      }
      if (discountReason.isNotEmpty) {
        parts.add('Sabab: $discountReason');
      }
      if (parts.isNotEmpty) {
        return '${parts.join(' ')}.';
      }
      return fallbackBody;
    }

    final parts = <String>[];
    if (paymentAmount.isNotEmpty) {
      parts.add('To\'lov qabul qilindi: $paymentAmount');
    }
    if (parts.isNotEmpty) {
      return '${parts.join('. ')}.';
    }
    return fallbackBody;
  }

  String _extractDiscountAmount(Map<String, dynamic> data) {
    final rawAmount = data['discount_amount'];
    if (rawAmount == null) {
      return '';
    }

    final text = rawAmount.toString().trim();
    if (text.isEmpty) {
      return '';
    }

    final parsed = num.tryParse(text);
    if (parsed == null) {
      return text;
    }

    return '${_formatMoney(parsed)} so\'m';
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

  Color _attendanceStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'keldi':
      case 'present':
        return const Color(0xFF0F9D58);
      case 'kelmadi':
      case 'absent':
        return const Color(0xFFE53935);
      case 'kechikdi':
      case 'late':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF4B5563);
    }
  }

  String _formatDateTimeLabel(String raw) {
    final parsed = _parseFlexibleDateTime(raw.trim());
    if (parsed == null) {
      return raw.trim();
    }
    final year = parsed.year.toString().padLeft(4, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  DateTime? _parseFlexibleDateTime(String raw) {
    if (raw.isEmpty) return null;

    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;

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

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return Icons.payments_rounded;
      case 'discount':
        return Icons.local_offer_rounded;
      case 'attendance':
        return Icons.fact_check_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  String _stringValue(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatMoney(num value) {
    final fixed = value % 1 == 0 ? value.toInt().toString() : value.toString();
    final parts = fixed.split('.');
    final integer = parts.first;
    final buffer = StringBuffer();
    for (var i = 0; i < integer.length; i++) {
      final indexFromEnd = integer.length - i;
      buffer.write(integer[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(' ');
      }
    }
    if (parts.length > 1) {
      buffer.write('.${parts[1]}');
    }
    return buffer.toString().trim();
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF556070)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF243042),
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(text: '$title: '),
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7B8497),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? const Color(0xFF243042),
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
