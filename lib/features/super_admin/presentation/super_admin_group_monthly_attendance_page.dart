import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/super_admin_service.dart';

/// Bitta guruhning tanlangan oydagi to'liq davomat jadvali:
/// har bir talaba uchun har bir dars kuni bo'yicha keldi/kelmadi belgisi
/// va to'lov holati (saytdagi guruh davomat sahifasi bilan bir xil).
class SuperAdminGroupMonthlyAttendancePage extends StatefulWidget {
  const SuperAdminGroupMonthlyAttendancePage({
    super.key,
    required this.session,
    required this.groupId,
    required this.groupLabel,
    required this.initialMonth,
  });

  final AuthSession session;
  final int groupId;
  final String groupLabel;

  /// YYYY-MM
  final String initialMonth;

  @override
  State<SuperAdminGroupMonthlyAttendancePage> createState() =>
      _SuperAdminGroupMonthlyAttendancePageState();
}

class _SuperAdminGroupMonthlyAttendancePageState
    extends State<SuperAdminGroupMonthlyAttendancePage> {
  final SuperAdminService _service = SuperAdminService();
  late String _month;
  late List<String> _months;
  late Future<MonthlyAttendanceData> _future;

  static const _nameColumnWidth = 150.0;
  static const _statusColumnWidth = 62.0;
  static const _moneyColumnWidth = 82.0;
  static const _lessonColumnWidth = 40.0;
  static const _indexColumnWidth = 26.0;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _months = [_month];
    _future = _service.fetchMonthlyAttendance(
      widget.session,
      groupId: widget.groupId,
      month: _month,
    );
    _loadMonths();
  }

  Future<void> _loadMonths() async {
    final start = await _service.fetchSystemStartMonth(widget.session);
    if (!mounted) return;
    setState(() {
      _months = SuperAdminService.monthsFrom(start);
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _selectMonth(String month) {
    if (month == _month) return;
    setState(() {
      _month = month;
      _future = _service.fetchMonthlyAttendance(
        widget.session,
        groupId: widget.groupId,
        month: month,
      );
    });
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.fetchMonthlyAttendance(
        widget.session,
        groupId: widget.groupId,
        month: _month,
      );
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.groupLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Color(0xFF182033),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: AppTheme.brandColor,
        child: Column(
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _months.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final month = _months[index];
                  final selected = month == _month;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _selectMonth(month),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.brandColor.withValues(alpha: 0.10)
                            : Colors.transparent,
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppTheme.brandColor
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<MonthlyAttendanceData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.brandColor,
                      ),
                    );
                  }
                  final data = snapshot.data;
                  if (snapshot.hasError || data == null) {
                    return Center(
                      child: Text(
                        snapshot.error is SuperAdminServiceException
                            ? (snapshot.error as SuperAdminServiceException)
                                  .message
                            : 'Davomat jadvali yuklanmadi',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!data.schedule.isEmpty || data.subjectName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: _GroupScheduleHeader(data: data),
                        ),
                      Expanded(
                        child: data.students.isEmpty
                            ? const Center(
                                child: Text(
                                  'Bu oyda talabalar topilmadi',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              )
                            : _MonthlyAttendanceTable(
                                data: data,
                                nameColumnWidth: _nameColumnWidth,
                                statusColumnWidth: _statusColumnWidth,
                                moneyColumnWidth: _moneyColumnWidth,
                                lessonColumnWidth: _lessonColumnWidth,
                                indexColumnWidth: _indexColumnWidth,
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guruh sarlavhasi: fan + dars kunlari va vaqti (jadval ustida)
class _GroupScheduleHeader extends StatelessWidget {
  const _GroupScheduleHeader({required this.data});

  final MonthlyAttendanceData data;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (data.subjectName.isNotEmpty)
          _InfoBadge(icon: Icons.menu_book_rounded, label: data.subjectName),
        if (data.schedule.days.isNotEmpty)
          _InfoBadge(
            icon: Icons.calendar_month_rounded,
            label: data.schedule.days.join(', '),
          ),
        if (data.schedule.time.isNotEmpty)
          _InfoBadge(icon: Icons.timer_outlined, label: data.schedule.time),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.brandColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3A4256),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyAttendanceTable extends StatelessWidget {
  const _MonthlyAttendanceTable({
    required this.data,
    required this.nameColumnWidth,
    required this.statusColumnWidth,
    required this.moneyColumnWidth,
    required this.lessonColumnWidth,
    required this.indexColumnWidth,
  });

  final MonthlyAttendanceData data;
  final double nameColumnWidth;
  final double statusColumnWidth;
  final double moneyColumnWidth;
  final double lessonColumnWidth;
  final double indexColumnWidth;

  double get _tableWidth =>
      indexColumnWidth +
      nameColumnWidth +
      statusColumnWidth +
      (moneyColumnWidth * 3) +
      (lessonColumnWidth * data.lessons.length);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Vertikal skroll — talabalar ko'p bo'lsa jadval tashqariga
      // toshib ketmasligi (overflow) uchun
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: _tableWidth,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B4A7A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _headerCell('#', indexColumnWidth),
                  _headerCell('Talaba', nameColumnWidth, alignLeft: true),
                  _headerCell('Holati', statusColumnWidth),
                  _headerCell('To\'langan', moneyColumnWidth),
                  _headerCell('Chegirma', moneyColumnWidth),
                  _headerCell('Qarz', moneyColumnWidth),
                  for (final lesson in data.lessons)
                    _headerCell(lesson.dayLabel, lessonColumnWidth),
                ],
              ),
            ),
            for (var i = 0; i < data.students.length; i++)
              _studentRow(i, data.students[i]),
            const SizedBox(height: 20),
          ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(String label, double width, {bool alignLeft = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignLeft ? TextAlign.left : TextAlign.center,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _studentRow(int index, MonthlyAttendanceStudent student) {
    final statusColor = student.isActive
        ? const Color(0xFF16934F)
        : const Color(0xFF8A93A5);

    return Container(
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : const Color(0xFFFAFBFD),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEDF1F7)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: indexColumnWidth,
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A93A5),
              ),
            ),
          ),
          Container(
            width: nameColumnWidth,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF182033),
                  ),
                ),
                if (student.phone.isNotEmpty)
                  Text(
                    student.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A93A5),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: statusColumnWidth,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                student.isActive ? 'Faol' : student.monthlyStatus,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ),
          ),
          _moneyCell(student.paidAmount, moneyColumnWidth),
          _moneyCell(student.discountAmount, moneyColumnWidth),
          _moneyCell(
            student.debtAmount,
            moneyColumnWidth,
            color: student.debtAmount > 0 ? const Color(0xFFDC2626) : null,
          ),
          for (final lesson in data.lessons)
            _attendanceCell(
              lessonColumnWidth,
              student.statusByLessonId[lesson.lessonId],
              isHoliday: lesson.isHoliday,
            ),
        ],
      ),
    );
  }

  Widget _moneyCell(double value, double width, {Color? color}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        _formatMoney(value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color ?? const Color(0xFF3A4256),
        ),
      ),
    );
  }

  Widget _attendanceCell(double width, String? status, {bool isHoliday = false}) {
    IconData icon;
    Color color;
    if (isHoliday) {
      icon = Icons.remove_rounded;
      color = const Color(0xFFB8BFCC);
    } else {
      switch (status) {
        case 'keldi':
          icon = Icons.check_circle_rounded;
          color = const Color(0xFF16934F);
        case 'kelmadi':
          icon = Icons.cancel_rounded;
          color = const Color(0xFFDC2626);
        case 'kechikdi':
          icon = Icons.schedule_rounded;
          color = const Color(0xFFB45309);
        default:
          icon = Icons.remove_rounded;
          color = const Color(0xFFCBD3E1);
      }
    }
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      child: Icon(icon, size: 15, color: color),
    );
  }
}

String _formatMoney(double value) {
  final rounded = value.round();
  if (rounded == 0) return '0';
  final text = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(text[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer';
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
