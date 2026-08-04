import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/student_payments_service.dart';

String _formatMonthLabel(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final year = parts[0];
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
  return '$monthName $year';
}

String _formatDisplayDate(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return '';

  int? day;
  int? month;
  int? year;

  // ISO format (2026-07-10T10:53:34.888Z) — DateTime o'zi tushunadi,
  // lokal vaqtga o'girib sanani olamiz
  final isoParsed = DateTime.tryParse(value);
  if (isoParsed != null) {
    final local = isoParsed.toLocal();
    day = local.day;
    month = local.month;
    year = local.year;
  } else {
    final dateTimePart = value.split(' ').first;
    final parts = dateTimePart.split(RegExp(r'[.\-/]'));
    if (parts.length != 3) {
      return value;
    }

    if (parts[0].length == 4) {
      year = int.tryParse(parts[0]);
      month = int.tryParse(parts[1]);
      day = int.tryParse(parts[2]);
    } else {
      day = int.tryParse(parts[0]);
      month = int.tryParse(parts[1]);
      year = int.tryParse(parts[2]);
    }
  }

  if (day == null || month == null || year == null) {
    return value;
  }

  const names = [
    'yanvar',
    'fevral',
    'mart',
    'aprel',
    'may',
    'iyun',
    'iyul',
    'avgust',
    'sentabr',
    'oktabr',
    'noyabr',
    'dekabr',
  ];

  final monthName = month >= 1 && month <= 12 ? names[month - 1] : '';
  if (monthName.isEmpty) return value;
  return '$day $monthName $year';
}

class StudentPaymentsPage extends StatefulWidget {
  const StudentPaymentsPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<StudentPaymentsPage> createState() => _StudentPaymentsPageState();
}

class _StudentPaymentsPageState extends State<StudentPaymentsPage> {
  final StudentPaymentsService _service = StudentPaymentsService();
  late Future<StudentPaymentsResponse> _future;
  String? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchMyPayments(widget.session);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.fetchMyPayments(widget.session);
    });
    await _future;
  }

  void _ensureSelectedMonth(List<String> months) {
    if (_selectedMonth != null || months.isEmpty) return;
    final currentMonth = _currentMonthKey();
    final nextSelected = months.contains(currentMonth)
        ? currentMonth
        : months.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedMonth != null) return;
      setState(() {
        _selectedMonth = nextSelected;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StudentPaymentsResponse>(
      future: _future,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.error;
        final data = snapshot.data;

        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.brandColor),
          );
        }

        if (error != null || data == null) {
          return _PaymentsErrorState(
            message: _readErrorMessage(error),
            onRetry: _reload,
          );
        }

        final months = _collectMonths(data);
        _ensureSelectedMonth(months);
        final selectedMonth =
            _selectedMonth ??
            (months.isNotEmpty ? months.first : _currentMonthKey());
        final monthEnrollments = data.enrollments
            .where((item) => item.month == selectedMonth)
            .toList();
        final monthTransactions = data.transactions
            .where((item) => item.month == selectedMonth)
            .toList();
        final stats = _MonthlyStats.fromEnrollments(monthEnrollments);

        return RefreshIndicator(
          color: AppTheme.brandColor,
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              _SummaryHero(
                monthLabel: _formatMonthLabel(selectedMonth),
                stats: stats,
              ),
              const SizedBox(height: 12),
              _MonthSelector(
                months: months,
                selectedMonth: selectedMonth,
                onSelected: (month) {
                  setState(() {
                    _selectedMonth = month;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (monthEnrollments.isEmpty)
                const _EmptyPaymentsState()
              else
                ...monthEnrollments.map(
                  (enrollment) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PaymentCard(enrollment: enrollment),
                  ),
                ),
              if (monthTransactions.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _SectionTitle(title: 'To\'lov tarixi'),
                const SizedBox(height: 10),
                ...monthTransactions.map(
                  (transaction) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TransactionCard(transaction: transaction),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<String> _collectMonths(StudentPaymentsResponse data) {
    final months = <String>{};
    for (final enrollment in data.enrollments) {
      if (enrollment.month.trim().isNotEmpty) {
        months.add(enrollment.month);
      }
    }
    for (final transaction in data.transactions) {
      if (transaction.month.trim().isNotEmpty) {
        months.add(transaction.month);
      }
    }
    final list = months.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  String _readErrorMessage(Object? error) {
    if (error is StudentPaymentsException) {
      return error.message;
    }
    return 'To\'lov ma\'lumotlari yuklanmadi';
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
}

class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.monthLabel, required this.stats});

  final String monthLabel;
  final _MonthlyStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
            child: Transform.rotate(
              angle: 0.18,
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 110,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            right: 76,
            top: -14,
            child: Transform.rotate(
              angle: -0.3,
              child: Icon(
                Icons.payments_rounded,
                size: 56,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'To\'lovlarim',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            monthLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _HeroStat(
                      label: 'Kerak',
                      value: _formatMoney(stats.totalRequired),
                    ),
                    const SizedBox(width: 8),
                    _HeroStat(
                      label: 'To\'langan',
                      value: _formatMoney(stats.totalPaid),
                    ),
                    const SizedBox(width: 8),
                    _HeroStat(
                      label: 'Qarz',
                      value: _formatMoney(stats.totalDebt),
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
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
                  fontSize: 12.5,
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

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.months,
    required this.selectedMonth,
    required this.onSelected,
  });

  final List<String> months;
  final String selectedMonth;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var index = 0; index < months.length; index++) ...[
              if (index > 0) const SizedBox(width: 6),
              Builder(
                builder: (context) {
                  final month = months[index];
                  final selected = month == selectedMonth;
                  return Material(
                    color: selected ? AppTheme.brandColor : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => onSelected(month),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
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
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.enrollment});

  final StudentPaymentEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final paymentStatus = _paymentStatusLabel(enrollment.paymentStatus);
    final statusColor = _paymentStatusColor(enrollment.paymentStatus);
    final monthlyStatus = _monthlyStatusLabel(enrollment.monthlyStatus);
    final monthlyStatusColor = _monthlyStatusColor(enrollment.monthlyStatus);
    final paidRatio = enrollment.requiredAmount > 0
        ? (enrollment.paidAmount / enrollment.requiredAmount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -18,
            child: Transform.rotate(
              angle: 0.18,
              child: Icon(
                Icons.receipt_long_rounded,
                size: 84,
                color: AppTheme.brandColor.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enrollment.groupName.isEmpty
                                ? 'Guruh'
                                : enrollment.groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF182033),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${enrollment.subjectName} • ${enrollment.teacherName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(label: paymentStatus, color: statusColor),
                  ],
                ),
                const SizedBox(height: 12),
                // Summalar — uch ustunli ixcham blok
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _AmountCol(
                            label: 'Kerak',
                            value: _formatMoney(enrollment.requiredAmount),
                            color: const Color(0xFF182033),
                          ),
                          _AmountCol(
                            label: 'To\'langan',
                            value: _formatMoney(enrollment.paidAmount),
                            color: const Color(0xFF16934F),
                          ),
                          _AmountCol(
                            label: 'Qarz',
                            value: _formatMoney(enrollment.debtAmount),
                            color: const Color(0xFFDC2626),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // To'lov jarayoni progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 6,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              Container(color: const Color(0xFFE5EAF2)),
                              FractionallySizedBox(
                                widthFactor: paidRatio,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF16934F),
                                        Color(0xFF22C55E),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniChip(
                      icon: Icons.how_to_reg_rounded,
                      label:
                          'Davomat: ${enrollment.attendedLessons}/${enrollment.totalLessons} • ${enrollment.attendancePercentage.toStringAsFixed(0)}%',
                    ),
                    if (enrollment.lastPaymentDate.isNotEmpty)
                      _MiniChip(
                        icon: Icons.event_rounded,
                        label: _formatDisplayDate(enrollment.lastPaymentDate),
                      ),
                    if (enrollment.discountAmount > 0)
                      _MiniChip(
                        icon: Icons.discount_rounded,
                        label:
                            'Chegirma: ${_formatMoney(enrollment.discountAmount)}',
                        color: const Color(0xFF8B5CF6),
                      ),
                    _MiniChip(
                      icon: Icons.circle,
                      iconSize: 7,
                      label: monthlyStatus,
                      color: monthlyStatusColor,
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

/// Summalar blokidagi bitta ustun (Kerak / To'langan / Qarz)
class _AmountCol extends StatelessWidget {
  const _AmountCol({
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
              fontSize: 10,
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
                fontSize: 12.5,
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

/// Icon + matnli kichik ma'lumot chipi
class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF5C6474),
    this.iconSize = 12,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});

  final StudentPaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final dateLabel = transaction.paymentDate.isEmpty
        ? ''
        : _formatDisplayDate(transaction.paymentDate);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF16934F).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16934F),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.groupName.isEmpty
                      ? 'To\'lov'
                      : transaction.groupName,
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
                  [
                    if (dateLabel.isNotEmpty) dateLabel,
                    if (transaction.description.trim().isNotEmpty)
                      transaction.description,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${_formatMoney(transaction.amount)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF16934F),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Color(0xFF182033),
      ),
    );
  }
}

class _EmptyPaymentsState extends StatelessWidget {
  const _EmptyPaymentsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.payments_outlined, size: 34, color: Color(0xFF7B8497)),
          SizedBox(height: 10),
          Text(
            'Bu oy uchun to\'lov yozuvlari topilmadi',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsErrorState extends StatelessWidget {
  const _PaymentsErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 46,
              color: AppTheme.brandColor,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF182033),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => onRetry(),
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
}

class _MonthlyStats {
  const _MonthlyStats({
    required this.totalEnrollments,
    required this.paidCount,
    required this.partialCount,
    required this.unpaidCount,
    required this.totalRequired,
    required this.totalPaid,
    required this.totalDiscount,
    required this.totalDebt,
  });

  final int totalEnrollments;
  final int paidCount;
  final int partialCount;
  final int unpaidCount;
  final double totalRequired;
  final double totalPaid;
  final double totalDiscount;
  final double totalDebt;

  factory _MonthlyStats.fromEnrollments(
    List<StudentPaymentEnrollment> enrollments,
  ) {
    double totalRequired = 0;
    double totalPaid = 0;
    double totalDiscount = 0;
    double totalDebt = 0;
    var paidCount = 0;
    var partialCount = 0;
    var unpaidCount = 0;

    for (final item in enrollments) {
      totalRequired += item.requiredAmount;
      totalPaid += item.paidAmount;
      totalDiscount += item.discountAmount;
      totalDebt += item.debtAmount;

      switch (item.paymentStatus) {
        case 'paid':
          paidCount += 1;
          break;
        case 'partial':
          partialCount += 1;
          break;
        default:
          unpaidCount += 1;
      }
    }

    return _MonthlyStats(
      totalEnrollments: enrollments.length,
      paidCount: paidCount,
      partialCount: partialCount,
      unpaidCount: unpaidCount,
      totalRequired: totalRequired,
      totalPaid: totalPaid,
      totalDiscount: totalDiscount,
      totalDebt: totalDebt,
    );
  }
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
  return '${buffer.toString()} so\'m';
}

String _paymentStatusLabel(String rawStatus) {
  switch (rawStatus) {
    case 'paid':
      return 'To\'liq to\'langan';
    case 'partial':
      return 'Qisman';
    case 'unpaid':
      return 'To\'lanmagan';
    default:
      return rawStatus.isEmpty ? 'Noma\'lum' : rawStatus;
  }
}

Color _paymentStatusColor(String rawStatus) {
  switch (rawStatus) {
    case 'paid':
      return const Color(0xFF16934F);
    case 'partial':
      return const Color(0xFFD97706);
    case 'unpaid':
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF64748B);
  }
}

String _monthlyStatusLabel(String rawStatus) {
  switch (rawStatus) {
    case 'active':
      return 'Faol';
    case 'stopped':
      return 'To\'xtagan';
    case 'finished':
      return 'Bitirgan';
    default:
      return rawStatus.isEmpty ? 'Noma\'lum' : rawStatus;
  }
}

Color _monthlyStatusColor(String rawStatus) {
  switch (rawStatus) {
    case 'active':
      return const Color(0xFF16934F);
    case 'stopped':
      return const Color(0xFFB45309);
    case 'finished':
      return const Color(0xFF8B5CF6);
    default:
      return const Color(0xFF64748B);
  }
}
