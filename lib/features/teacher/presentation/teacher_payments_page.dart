import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/teacher_service.dart';

/// Talabalar to'lovlari — teacher faqat ko'radi, o'zgartira olmaydi.
class TeacherPaymentsPage extends StatefulWidget {
  const TeacherPaymentsPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<TeacherPaymentsPage> createState() => _TeacherPaymentsPageState();
}

class _TeacherPaymentsPageState extends State<TeacherPaymentsPage> {
  final TeacherService _service = TeacherService();
  final TextEditingController _searchController = TextEditingController();
  late String _selectedMonth;
  late Future<TeacherPaymentsResponse> _future;
  String _search = '';

  /// Teacher guruhlari ichida eng erta dars boshlangan oy —
  /// oy filtri shu oydan boshlanadi
  DateTime? _earliestStartMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = _monthKey(now);
    _future = _load();
    _loadEarliestStartMonth();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadEarliestStartMonth() async {
    try {
      final groups = await _service.fetchMyGroups(widget.session);
      DateTime? earliest;
      for (final group in groups) {
        final start = group.classStartMonth;
        if (start != null && (earliest == null || start.isBefore(earliest))) {
          earliest = start;
        }
      }
      if (mounted && earliest != null) {
        setState(() => _earliestStartMonth = earliest);
      }
    } catch (_) {
      // Guruhlar yuklanmasa oy filtri joriy oy bilan cheklanadi
    }
  }

  Future<TeacherPaymentsResponse> _load() {
    return _service.fetchPaymentSnapshots(
      widget.session,
      month: _selectedMonth,
      limit: 200,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  void _selectMonth(String month) {
    if (month == _selectedMonth) return;
    setState(() {
      _selectedMonth = month;
      _future = _load();
    });
  }

  /// Guruhlar dars boshlagan oydan joriy oygacha (joriy oy birinchi)
  List<String> get _months {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    final start = _earliestStartMonth;
    if (start == null || start.isAfter(current)) {
      return [_monthKey(current)];
    }
    final months = <String>[];
    var cursor = current;
    while (!cursor.isBefore(start) && months.length < 36) {
      months.add(_monthKey(cursor));
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    return months;
  }

  static String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: AppTheme.brandColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Oy statistikasi — eng yuqorida
          FutureBuilder<TeacherPaymentsResponse>(
            future: _future,
            builder: (context, snapshot) {
              final summary = snapshot.data?.summary;
              if (summary == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SummaryCard(summary: summary),
              );
            },
          ),
          // Oy tanlagich
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _months.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final month = _months[index];
                final selected = month == _selectedMonth;
                return GestureDetector(
                  onTap: () => _selectMonth(month),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.brandColor : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? AppTheme.brandColor
                            : const Color(0xFFD6DDEA),
                      ),
                    ),
                    child: Text(
                      _formatMonthLabel(month),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // O'quvchi yoki guruh nomi bo'yicha qidiruv
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'O\'quvchi yoki guruh nomi...',
              hintStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9AA2B2),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: Color(0xFF7B8497),
              ),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF7B8497),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE4E9F1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE4E9F1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppTheme.brandColor,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<TeacherPaymentsResponse>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.brandColor,
                    ),
                  ),
                );
              }
              final data = snapshot.data;
              if (snapshot.hasError || data == null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          snapshot.error is TeacherServiceException
                              ? (snapshot.error as TeacherServiceException)
                                    .message
                              : 'To\'lov ma\'lumotlari yuklanmadi',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _reload,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.brandColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Qayta urinish'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final query = _search.trim().toLowerCase();
              final snapshots = query.isEmpty
                  ? data.snapshots
                  : data.snapshots
                        .where(
                          (item) =>
                              item.fullName.toLowerCase().contains(query) ||
                              item.groupName.toLowerCase().contains(query),
                        )
                        .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snapshots.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 30,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE4E9F1)),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 34,
                            color: Color(0xFF7B8497),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Bu oy uchun ma\'lumot topilmadi',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final item in snapshots) ...[
                      _SnapshotCard(snapshot: item),
                      const SizedBox(height: 8),
                    ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final TeacherPaymentsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C0A05), Color(0xFFA70E07), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -22,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 104,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'O\'quvchilar to\'lov holati',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Teacher uchun pul summalari ko'rsatilmaydi — faqat
                // o'quvchilar soni va to'lov holati kesimi
                Row(
                  children: [
                    _SummaryStat(
                      label: 'Jami',
                      value: '${summary.totalStudents} ta',
                    ),
                    const SizedBox(width: 8),
                    _SummaryStat(
                      label: 'To\'lagan',
                      value: '${summary.paidStudents} ta',
                    ),
                    const SizedBox(width: 8),
                    _SummaryStat(
                      label: 'Qisman',
                      value: '${summary.partialStudents} ta',
                    ),
                    const SizedBox(width: 8),
                    _SummaryStat(
                      label: 'To\'lamagan',
                      value: '${summary.unpaidStudents} ta',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.snapshot});

  final PaymentSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(snapshot.paymentStatus);
    final statusColor = _statusColor(snapshot.paymentStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(snapshot.fullName),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF182033),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      snapshot.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7B8495),
                      ),
                    ),
                    if (snapshot.studentPhone.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri(
                            scheme: 'tel',
                            path: snapshot.studentPhone.trim(),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone_rounded,
                              size: 11,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              snapshot.studentPhone.trim(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _AmountInfo(
                label: 'Kerak',
                value: _formatMoney(snapshot.requiredAmount),
                color: const Color(0xFF182033),
              ),
              _AmountInfo(
                label: 'To\'langan',
                value: _formatMoney(snapshot.paidAmount),
                color: const Color(0xFF16934F),
              ),
              _AmountInfo(
                label: 'Qarz',
                value: _formatMoney(snapshot.debtAmount),
                color: const Color(0xFFDC2626),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _AmountInfo extends StatelessWidget {
  const _AmountInfo({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7B8497),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMonthLabel(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final month = int.tryParse(parts[1]) ?? 1;
  const names = [
    'Yanvar',
    'Fevral',
    'Mart',
    'Aprel',
    'May',
    'Iyun',
    'Iyul',
    'Avgust',
    'Sentabr',
    'Oktabr',
    'Noyabr',
    'Dekabr',
  ];
  final monthName = month >= 1 && month <= 12 ? names[month - 1] : monthKey;
  return '$monthName ${parts[0]}';
}

String _formatMoney(num value) {
  final rounded = value.round();
  final text = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final offsetFromEnd = text.length - i;
    buffer.write(text[i]);
    if (offsetFromEnd > 1 && offsetFromEnd % 3 == 1) {
      buffer.write(' ');
    }
  }
  return '$buffer so\'m';
}

String _statusLabel(String rawStatus) {
  switch (rawStatus) {
    case 'paid':
      return 'To\'langan';
    case 'partial':
      return 'Qisman';
    case 'unpaid':
      return 'To\'lanmagan';
    default:
      return rawStatus.isEmpty ? 'Noma\'lum' : rawStatus;
  }
}

Color _statusColor(String rawStatus) {
  switch (rawStatus) {
    case 'paid':
      return const Color(0xFF16934F);
    case 'partial':
      return const Color(0xFFB45309);
    case 'unpaid':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF64748B);
  }
}
