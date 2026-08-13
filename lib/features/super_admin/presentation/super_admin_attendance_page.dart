import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/super_admin_service.dart';
import 'super_admin_group_monthly_attendance_page.dart';

/// Davomat nazorati (faqat kuzatuv): markaz bo'yicha bugungi davomat
/// charti va bugun darsi bor teacherlarning davomat progresi.
/// Super admin davomat belgilamaydi — faqat kuzatib boradi.
class SuperAdminAttendancePage extends StatefulWidget {
  const SuperAdminAttendancePage({super.key, required this.session});

  final AuthSession session;

  @override
  State<SuperAdminAttendancePage> createState() =>
      _SuperAdminAttendancePageState();
}

class _SuperAdminAttendancePageState extends State<SuperAdminAttendancePage> {
  final SuperAdminService _service = SuperAdminService();
  late Future<List<AttendanceTeacher>> _teachersFuture;
  late Future<SnapshotSummary> _summaryFuture;

  /// Tanlangan oy (YYYY-MM) va kun (YYYY-MM-DD)
  late String _month;
  late String _date;
  late List<String> _months;

  /// Teacherlar ro'yxatini ism bo'yicha filtrlash uchun
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = _monthKey(now);
    _date = _dateKey(now);
    _months = [_month];
    _teachersFuture = _service.fetchAttendanceTeachers(
      widget.session,
      date: _date,
    );
    _summaryFuture = _service.fetchSnapshotSummary(
      widget.session,
      month: _month,
    );
    _loadMonths();
  }

  /// Oy ro'yxati tizim ish boshlagan oydan boshlanadi
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

  static String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  static String _dateKey(DateTime date) =>
      '${_monthKey(date)}-${date.day.toString().padLeft(2, '0')}';

  String get _todayKey => _dateKey(DateTime.now());

  /// Tanlangan oyning kunlari — oxirgi kun birinchi.
  /// Joriy oyda bugundan keyingi kunlar ko'rsatilmaydi.
  List<String> get _daysOfMonth {
    final parts = _month.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;
    final lastDay = isCurrentMonth
        ? now.day
        : DateTime(year, month + 1, 0).day;
    return List.generate(lastDay, (i) {
      final day = lastDay - i;
      return '$_month-${day.toString().padLeft(2, '0')}';
    });
  }

  void _selectMonth(String month) {
    if (month == _month) return;
    setState(() {
      _month = month;
      // Joriy oy tanlansa bugun, o'tgan oy tanlansa oyning oxirgi kuni
      _date = month == _monthKey(DateTime.now()) ? _todayKey : _daysFor(month);
      _teachersFuture = _service.fetchAttendanceTeachers(
        widget.session,
        date: _date,
      );
      _summaryFuture = _service.fetchSnapshotSummary(
        widget.session,
        month: month,
      );
    });
  }

  /// Oyning oxirgi kunini YYYY-MM-DD ko'rinishida qaytaradi
  String _daysFor(String month) {
    final parts = month.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final monthNum = int.tryParse(parts[1]) ?? DateTime.now().month;
    final lastDay = DateTime(year, monthNum + 1, 0).day;
    return '$month-${lastDay.toString().padLeft(2, '0')}';
  }

  void _selectDate(String date) {
    if (date == _date) return;
    setState(() {
      _date = date;
      _teachersFuture = _service.fetchAttendanceTeachers(
        widget.session,
        date: date,
      );
    });
  }

  Future<void> _reload() async {
    setState(() {
      _teachersFuture = _service.fetchAttendanceTeachers(
        widget.session,
        date: _date,
      );
      _summaryFuture = _service.fetchSnapshotSummary(
        widget.session,
        month: _month,
      );
    });
    await _teachersFuture;
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _date == _todayKey;

    return RefreshIndicator(
      onRefresh: _reload,
      color: AppTheme.brandColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Oylik umumiy statistika — saytdagi admin davomat sahifasi kabi
          // (tanlangan oyning to'lov jadvali bo'yicha)
          FutureBuilder<SnapshotSummary>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              final summary = snapshot.data;
              if (summary == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryPill(
                        label: 'Jami',
                        value: summary.totalStudents,
                        color: AppTheme.brandColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryPill(
                        label: 'Faol',
                        value: summary.activeStudents,
                        color: const Color(0xFF16934F),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryPill(
                        label: 'To\'xtatgan',
                        value: summary.stoppedStudents,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Oy tanlash
          SizedBox(
            height: 32,
            child: ListView.separated(
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
          const SizedBox(height: 8),
          // Kun tanlash — oxirgi kun birinchi
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _daysOfMonth.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final date = _daysOfMonth[index];
                final selected = date == _date;
                final dayNumber = date.split('-').last;
                final isTodayChip = date == _todayKey;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _selectDate(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 46,
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.brandColor : Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: selected
                            ? AppTheme.brandColor
                            : const Color(0xFFE4E9F1),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isTodayChip ? 'Bugun' : dayNumber,
                          style: TextStyle(
                            fontSize: isTodayChip ? 10 : 14,
                            fontWeight: FontWeight.w900,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF182033),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _weekdayShort(date),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white.withValues(alpha: 0.85)
                                : const Color(0xFF8A93A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<AttendanceTeacher>>(
            future: _teachersFuture,
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

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          snapshot.error is SuperAdminServiceException
                              ? (snapshot.error as SuperAdminServiceException)
                                    .message
                              : 'Davomat ma\'lumotlari yuklanmadi',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 10),
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

              final teachers = snapshot.data ?? const <AttendanceTeacher>[];

              // Tanlangan kunda jadval bo'yicha darsi bor teacherlar —
              // faqat kunlik davomat charti uchun
              final dayTeachers = teachers
                  .where((teacher) => teacher.todayGroupsCount > 0)
                  .toList();

              final totalGroups = dayTeachers.fold<int>(
                0,
                (sum, teacher) => sum + teacher.todayGroupsCount,
              );
              final markedGroups = dayTeachers.fold<int>(
                0,
                (sum, teacher) => sum + teacher.todayMarkedGroupsCount,
              );

              // Ro'yxat: barcha teacherlar — avval bugun darsi borlar
              // (davomati tugallanmaganlar tepada), keyin darsi yo'qlar
              // (alifbo tartibida)
              final withLessons = dayTeachers.toList()
                ..sort((a, b) {
                  final ratioA =
                      a.todayMarkedGroupsCount / a.todayGroupsCount;
                  final ratioB =
                      b.todayMarkedGroupsCount / b.todayGroupsCount;
                  return ratioA.compareTo(ratioB);
                });
              final withoutLessons =
                  teachers.where((teacher) => teacher.todayGroupsCount == 0).toList()
                    ..sort((a, b) => a.fullName.compareTo(b.fullName));
              final orderedTeachers = [...withLessons, ...withoutLessons];

              final query = _searchQuery.trim().toLowerCase();
              final visibleTeachers = query.isEmpty
                  ? orderedTeachers
                  : orderedTeachers
                        .where(
                          (teacher) =>
                              teacher.fullName.toLowerCase().contains(query),
                        )
                        .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DailyAttendanceChartCard(
                    title: isToday
                        ? 'Bugungi davomat'
                        : '${_formatDateLabel(_date)} davomati',
                    totalGroups: totalGroups,
                    markedGroups: markedGroups,
                  ),
                  if (teachers.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Teacherlar davomat progresi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF182033),
                        ),
                      ),
                    ),
                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Teacher ismi bo\'yicha qidirish',
                        hintStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9AA2B2),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 19,
                          color: Color(0xFF9AA2B2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                            color: Color(0xFFD6DDEA),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                            color: Color(0xFFD6DDEA),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                            color: AppTheme.brandColor,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (visibleTeachers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'Teacher topilmadi',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8A93A5),
                            ),
                          ),
                        ),
                      )
                    else
                      for (final teacher in visibleTeachers) ...[
                        _TeacherProgressCard(
                          teacher: teacher,
                          session: widget.session,
                          service: _service,
                          month: _month,
                        ),
                        const SizedBox(height: 8),
                      ],
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

String _formatDateLabel(String dateKey) {
  final parsed = DateTime.tryParse(dateKey);
  if (parsed == null) return dateKey;
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
  return '${parsed.day} ${names[parsed.month - 1]}';
}

String _weekdayShort(String dateKey) {
  final parsed = DateTime.tryParse(dateKey);
  if (parsed == null) return '';
  const names = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];
  return names[parsed.weekday - 1];
}

/// Markaz bo'yicha bugungi davomat charti:
/// qilingan (yashil) va qilinmagan (sariq) guruhlar
class _DailyAttendanceChartCard extends StatelessWidget {
  const _DailyAttendanceChartCard({
    required this.title,
    required this.totalGroups,
    required this.markedGroups,
  });

  final String title;
  final int totalGroups;
  final int markedGroups;

  static const _doneColor = Color(0xFF16934F);
  static const _pendingColor = Color(0xFFE9A23B);

  @override
  Widget build(BuildContext context) {
    final pendingGroups = totalGroups - markedGroups;
    final percent = totalGroups > 0
        ? (markedGroups / totalGroups * 100).round()
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.how_to_reg_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Jami: $totalGroups guruh',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5A6478),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (totalGroups == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Bu kunda jadval bo\'yicha darslar yo\'q',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8A93A5),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                // Donut chart — markazida bajarilgan foiz
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 34,
                          startDegreeOffset: -90,
                          sections: [
                            if (markedGroups > 0)
                              PieChartSectionData(
                                value: markedGroups.toDouble(),
                                color: _doneColor,
                                radius: 16,
                                showTitle: false,
                              ),
                            if (pendingGroups > 0)
                              PieChartSectionData(
                                value: pendingGroups.toDouble(),
                                color: _pendingColor,
                                radius: 14,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF182033),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _LegendRow(
                        color: _doneColor,
                        label: 'Davomat qilingan',
                        value: markedGroups,
                      ),
                      const SizedBox(height: 10),
                      _LegendRow(
                        color: _pendingColor,
                        label: 'Qilinmagan',
                        value: pendingGroups,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5A6478),
            ),
          ),
        ),
        Text(
          '$value guruh',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Umumiy statistika pilli (Jami / Faol / To'xtatgan)
class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A93A5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bitta teacherning tanlangan kundagi davomat progresi —
/// saytdagi admin davomat kartasi bilan bir xil ko'rsatkichlar
class _TeacherProgressCard extends StatefulWidget {
  const _TeacherProgressCard({
    required this.teacher,
    required this.session,
    required this.service,
    required this.month,
  });

  final AttendanceTeacher teacher;
  final AuthSession session;
  final SuperAdminService service;

  /// Tanlangan oy (YYYY-MM) — guruh tanlanganda shu oyning
  /// oylik davomat jadvali ochiladi
  final String month;

  @override
  State<_TeacherProgressCard> createState() => _TeacherProgressCardState();
}

class _TeacherProgressCardState extends State<_TeacherProgressCard> {
  bool _expanded = false;
  Future<List<AttendanceTeacherGroup>>? _groupsFuture;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      _groupsFuture ??= widget.service.fetchTeacherGroups(
        widget.session,
        widget.teacher.teacherId,
      );
    });
  }

  void _openMonthlyAttendance(AttendanceTeacherGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SuperAdminGroupMonthlyAttendancePage(
          session: widget.session,
          groupId: group.id,
          groupLabel: group.name,
          initialMonth: widget.month,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacher = widget.teacher;
    final hasLessonToday = teacher.todayGroupsCount > 0;
    final ratio = hasLessonToday
        ? (teacher.todayMarkedGroupsCount / teacher.todayGroupsCount).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final percent = (ratio * 100).round();
    final done = ratio >= 1.0;
    final color = !hasLessonToday
        ? const Color(0xFF8A93A5)
        : (done ? const Color(0xFF16934F) : const Color(0xFFE9A23B));

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleExpanded,
            child: Row(
              children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 19,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF182033),
                      ),
                    ),
                    if (teacher.subjects.isNotEmpty ||
                        teacher.roomNumbers.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (teacher.subjects.isNotEmpty)
                            teacher.subjects.join(', '),
                          if (teacher.roomNumbers.isNotEmpty)
                            '${teacher.roomNumbers.join(', ')}-xona',
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7B8495),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      !hasLessonToday
                          ? Icons.event_busy_rounded
                          : (done
                                ? Icons.check_circle_rounded
                                : Icons.pending_rounded),
                      size: 12,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      !hasLessonToday
                          ? 'Bugun darsi yo\'q'
                          : '${teacher.todayMarkedGroupsCount}/${teacher.todayGroupsCount} guruh',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: Color(0xFF8A93A5),
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: 8),
          // Saytdagi karta bilan bir xil ko'rsatkichlar
          Text(
            'Guruhlar: ${teacher.groupsCount} • '
            'Shu kuni darsi bor: ${teacher.todayGroupsCount} • '
            'Talabalar: ${teacher.studentsCount}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5A6478),
            ),
          ),
          if (hasLessonToday) ...[
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 7,
                width: double.infinity,
                child: Stack(
                  children: [
                    Container(color: const Color(0xFFEDF1F7)),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(color: color),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Progress: $percent%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
          if (_expanded) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEDF1F7)),
            const SizedBox(height: 10),
            Text(
              'Oylik davomat jadvalini ko\'rish uchun guruhni tanlang',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A93A5),
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<AttendanceTeacherGroup>>(
              future: _groupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppTheme.brandColor,
                        ),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    snapshot.error is SuperAdminServiceException
                        ? (snapshot.error as SuperAdminServiceException)
                              .message
                        : 'Guruhlar yuklanmadi',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  );
                }
                final groups =
                    snapshot.data ?? const <AttendanceTeacherGroup>[];
                if (groups.isEmpty) {
                  return const Text(
                    'Guruhlar topilmadi',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final group in groups) ...[
                      _TeacherGroupRow(
                        group: group,
                        onTap: () => _openMonthlyAttendance(group),
                      ),
                      if (group != groups.last) const SizedBox(height: 6),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Teacher kartasi ochilganda ko'rinadigan bitta guruh qatori —
/// bosilsa shu guruhning oylik davomat jadvali ochiladi
class _TeacherGroupRow extends StatelessWidget {
  const _TeacherGroupRow({required this.group, required this.onTap});

  final AttendanceTeacherGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.table_chart_rounded,
              size: 15,
              color: AppTheme.brandColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF182033),
                    ),
                  ),
                  Text(
                    [
                      if (group.subjectName.isNotEmpty) group.subjectName,
                      if (group.roomNumber.isNotEmpty)
                        '${group.roomNumber}-xona',
                      '${group.studentsCount} talaba',
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7B8495),
                    ),
                  ),
                  if (!group.schedule.isEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      group.schedule.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brandColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF8A93A5),
            ),
          ],
        ),
      ),
    );
  }
}
