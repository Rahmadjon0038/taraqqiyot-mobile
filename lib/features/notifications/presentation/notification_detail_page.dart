import 'dart:convert';

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
    final reportColumns = _extractReportColumns(data);
    final reportTotal = _extractReportTotal(data);
    final attendanceGroup = _stringValue(data['group_name']);
    final attendanceTeacher = _stringValue(data['teacher_name']);
    final attendanceSubject = _stringValue(data['subject_name']);
    final attendanceStatus = _stringValue(data['attendance_status']);
    final attendanceMarkedAt = _stringValue(data['attendance_marked_at']);
    final paymentAmount = _extractPaymentAmount(data);
    final paymentReminderDebtAmount = _extractPaymentReminderAmount(data);
    final paymentReminderMessage = _stringValue(data['reminder_message']);
    final paymentReminderMonth = _stringValue(data['month_label']);
    final discountAmount = _extractDiscountAmount(data);
    final discountReason = _extractDiscountReason(payload);
    final paymentReceiverName = _extractPaymentReceiverName(payload);
    final displayBody = _buildDisplayBody(
      type: type,
      reportColumns: reportColumns,
      reportTotal: reportTotal,
      attendanceGroup: attendanceGroup,
      attendanceTeacher: attendanceTeacher,
      attendanceSubject: attendanceSubject,
      attendanceStatus: attendanceStatus,
      attendanceMarkedAt: attendanceMarkedAt,
      paymentAmount: paymentAmount,
      paymentReminderDebtAmount: paymentReminderDebtAmount,
      paymentReminderMessage: paymentReminderMessage,
      paymentReminderMonth: paymentReminderMonth,
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
                      if (type == 'report' && reportColumns.isNotEmpty) ...[
                        _InfoChip(
                          icon: Icons.assignment_turned_in_rounded,
                          title: 'Jami',
                          value: reportTotal.isNotEmpty ? '$reportTotal ball' : '-',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: reportColumns
                              .map(
                                (item) => _MiniReportChip(
                                  title: _stringValue(item['label']),
                                  value: _stringValue(item['value']),
                                ),
                              )
                              .toList(),
                        ),
                      ] else if (type == 'discount' && discountAmount.isNotEmpty) ...[
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
                      ] else if (type == 'payment_reminder') ...[
                        _InfoChip(
                          icon: Icons.payments_rounded,
                          title: 'Qarz',
                          value: paymentReminderDebtAmount.isNotEmpty
                              ? paymentReminderDebtAmount
                              : '-',
                        ),
                        const SizedBox(height: 8),
                        if (paymentReminderMonth.isNotEmpty)
                          _InfoChip(
                            icon: Icons.calendar_month_rounded,
                            title: 'Oy',
                            value: paymentReminderMonth,
                          ),
                      ] else if (type == 'attendance') ...[
                        _InfoChip(
                          icon: Icons.fact_check_rounded,
                          title: 'Holat',
                          value: _attendanceStatusLabel(attendanceStatus),
                        ),
                        const SizedBox(height: 8),
                        _InfoChip(
                          icon: Icons.schedule_rounded,
                          title: 'Sana',
                          value: attendanceMarkedAt.isNotEmpty
                              ? attendanceMarkedAt
                              : createdAtLabel,
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
                      if (attendanceMarkedAt.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          label: 'Sana',
                          value: attendanceMarkedAt,
                        ),
                      ],
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
                      if (type == 'report' && reportColumns.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: 'Jami',
                          value: reportTotal.isEmpty ? '-' : '$reportTotal ball',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: reportColumns
                              .map(
                                (item) => _MiniReportChip(
                                  title: _stringValue(item['label']),
                                  value: _stringValue(item['value']),
                                ),
                              )
                              .toList(),
                        ),
                      ] else if (attendanceSubject.isNotEmpty ||
                          attendanceGroup.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        if (attendanceSubject.isNotEmpty)
                          _DetailRow(
                            label: 'Fan',
                            value: attendanceSubject,
                          ),
                        if (attendanceSubject.isNotEmpty &&
                            attendanceGroup.isNotEmpty)
                          const SizedBox(height: 10),
                        if (attendanceGroup.isNotEmpty)
                          _DetailRow(
                            label: 'Guruh',
                            value: attendanceGroup,
                          ),
                      ],
                      if (type == 'payment' &&
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
                      if (type == 'payment_reminder') ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          label: 'Xabar',
                          value: paymentReminderMessage.isEmpty
                              ? '-'
                              : paymentReminderMessage,
                        ),
                        const SizedBox(height: 10),
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
                          label: 'Qarz',
                          value: paymentReminderDebtAmount.isEmpty
                              ? '-'
                              : paymentReminderDebtAmount,
                          valueColor: const Color(0xFFB91C1C),
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

    // Push notification'lar navigator orqali kelganda payload maydonlari
    // ko'pincha to'g'ridan-to'g'ri top-level bo'lib keladi. Shu holatda ham
    // report/payment/attendance tafsilotlari yo'qolib ketmasligi uchun
    // umumiy metadata'ni olib tashlab, qolganini data sifatida ishlatamiz.
    final fallbackData = Map<String, dynamic>.from(payload)
      ..remove('route')
      ..remove('type')
      ..remove('title')
      ..remove('body')
      ..remove('created_at')
      ..remove('is_read')
      ..remove('id');

    if (fallbackData.isNotEmpty) {
      return fallbackData;
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

  List<Map<String, dynamic>> _extractReportColumns(Map<String, dynamic> data) {
    final rawColumns = data['report_columns'];
    List<dynamic>? columnsList;
    if (rawColumns is List) {
      columnsList = rawColumns;
    } else if (rawColumns is String && rawColumns.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawColumns);
        if (decoded is List) {
          columnsList = decoded;
        }
      } catch (_) {
        columnsList = null;
      }
    }

    if (columnsList == null) {
      return const <Map<String, dynamic>>[];
    }

    return columnsList
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return <String, dynamic>{
            ...map,
            'label': _stringValue(map['label']),
            'value': _stringValue(map['value']),
          };
        })
        .where((item) => _stringValue(item['label']).isNotEmpty)
        .toList();
  }

  String _extractReportTotal(Map<String, dynamic> data) {
    final raw = data['total'] ?? data['report_total'];
    final text = _stringValue(raw);
    if (text.isEmpty) return '';
    final parsed = num.tryParse(text);
    if (parsed == null) return text;
    return _formatMoney(parsed);
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
    required List<Map<String, dynamic>> reportColumns,
    required String reportTotal,
    required String attendanceGroup,
    required String attendanceTeacher,
    required String attendanceSubject,
    required String attendanceStatus,
    required String attendanceMarkedAt,
    required String paymentAmount,
    required String paymentReminderDebtAmount,
    required String paymentReminderMessage,
    required String paymentReminderMonth,
    required String discountAmount,
    required String discountReason,
    required String paymentReceiverName,
    required String fallbackBody,
  }) {
    if (type == 'report') {
      final parts = <String>[];
      if (reportColumns.isNotEmpty) {
        final shortColumns = reportColumns
            .map((item) {
              final label = _stringValue(item['label']);
              final value = _stringValue(item['value']);
              return label.isNotEmpty && value.isNotEmpty ? '$label $value' : '';
            })
            .where((part) => part.isNotEmpty)
            .toList();
        if (shortColumns.isNotEmpty) {
          parts.add(shortColumns.join(' • '));
        }
      }
      if (reportTotal.isNotEmpty) {
        parts.add('Jami $reportTotal ball');
      }
      if (parts.isNotEmpty) {
        return parts.join('\n');
      }
      return _cleanReportBody(fallbackBody);
    }

    if (type == 'attendance') {
      final parts = <String>[];
      final statusLabel = _attendanceStatusLabel(attendanceStatus);
      if (statusLabel.isNotEmpty) {
        parts.add(statusLabel);
      }
      if (attendanceMarkedAt.isNotEmpty) {
        parts.add(attendanceMarkedAt);
      }
      if (parts.isNotEmpty) {
        return parts.join('\n');
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

    if (type == 'payment_reminder') {
      final parts = <String>[];
      if (paymentReminderDebtAmount.isNotEmpty) {
        parts.add('Qarz: $paymentReminderDebtAmount');
      }
      if (paymentReminderMonth.isNotEmpty) {
        parts.add(paymentReminderMonth);
      }
      if (paymentReminderMessage.isNotEmpty) {
        parts.add(paymentReminderMessage);
      }
      if (parts.isNotEmpty) {
        return parts.join('\n');
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

  String _cleanReportBody(String body) {
    final text = body.trim();
    if (text.isEmpty) return '';

    final cleaned = text
        .replaceAll(RegExp(r'foiz', caseSensitive: false), '')
        .replaceAll(RegExp(r'\d{1,3}\s*%'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*•\s*•\s*'), ' • ')
        .replaceAll(RegExp(r'(?:\s*•\s*)+$'), '')
        .trim();

    return cleaned;
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

  String _extractPaymentReminderAmount(Map<String, dynamic> data) {
    final rawAmount = data['debt_amount'] ?? data['amount'] ?? data['paid_amount'];
    if (rawAmount == null) {
      return '';
    }

    final text = rawAmount.toString().trim();
    if (text.isEmpty) {
      return '';
    }

    final parsed = num.tryParse(text);
    if (parsed == null) {
      return text.endsWith('so\'m') ? text : '$text so\'m';
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
      case 'payment_reminder':
        return Icons.notifications_active_rounded;
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

class _MiniReportChip extends StatelessWidget {
  const _MiniReportChip({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
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
