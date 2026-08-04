import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/teacher_service.dart';

String _monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

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

const double _statisticsStudentColumnWidth = 128;
const double _statisticsScoreColumnWidth = 42;
const double _statisticsTotalColumnWidth = 34;
const double _statisticsPercentColumnWidth = 40;
const double _statisticsFeedbackColumnWidth = 60;
const double _statisticsColumnGap = 4;
const double _statisticsHorizontalPadding = 16;

class TeacherStatisticsPage extends StatefulWidget {
  const TeacherStatisticsPage({
    super.key,
    required this.session,
    this.initialGroupId,
  });

  final AuthSession session;
  final int? initialGroupId;

  @override
  State<TeacherStatisticsPage> createState() => _TeacherStatisticsPageState();
}

class _TeacherStatisticsPageState extends State<TeacherStatisticsPage> {
  final TeacherService _service = TeacherService();
  late Future<List<TeacherGroup>> _groupsFuture;
  Future<List<TeacherLesson>>? _lessonsFuture;
  final Map<int, TeacherLessonStatisticsReport> _lessonReports =
      <int, TeacherLessonStatisticsReport>{};

  int? _selectedGroupId;
  String _month = '';
  bool _didApplyInitialSelection = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = _monthKey(now);
    _groupsFuture = _service.fetchMyGroups(widget.session);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  static String _formatDayLabel(String dayKey) {
    final parsed = DateTime.tryParse(dayKey);
    if (parsed == null) return dayKey;
    const names = [
      'Dushanba',
      'Seshanba',
      'Chorshanba',
      'Payshanba',
      'Juma',
      'Shanba',
      'Yakshanba',
    ];
    const months = [
      'Yan',
      'Fev',
      'Mar',
      'Apr',
      'May',
      'Iyun',
      'Iyul',
      'Avg',
      'Sen',
      'Okt',
      'Noy',
      'Dek',
    ];
    final weekdays = names[parsed.weekday - 1];
    return '${parsed.day.toString().padLeft(2, '0')} '
        '${parsed.month >= 1 && parsed.month <= 12 ? months[parsed.month - 1] : ''} • $weekdays';
  }

  List<String> _monthsForGroup(TeacherGroup? group) {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    final start = group?.classStartMonth;
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

  Future<void> _reloadGroups() async {
    setState(() {
      _groupsFuture = _service.fetchMyGroups(widget.session);
    });
    await _groupsFuture;
  }

  Future<void> _reloadLessons() async {
    final groupId = _selectedGroupId;
    if (groupId == null) return;
    setState(() {
      _lessonsFuture = _service.fetchGroupLessons(
        widget.session,
        groupId,
        month: _month,
      );
    });
    await _lessonsFuture;
    await _syncReportsForSelectedGroup();
  }

  void _selectGroup(TeacherGroup group) {
    setState(() {
      _selectedGroupId = group.id;
      if (!_monthsForGroup(group).contains(_month)) {
        _month = _monthKey(DateTime.now());
      }
      _lessonsFuture = _service.fetchGroupLessons(
        widget.session,
        group.id,
        month: _month,
      );
    });
    _syncReportsForGroup(group.id, _month);
  }

  void _selectMonth(String month) {
    if (month == _month) return;
    final groupId = _selectedGroupId;
    setState(() {
      _month = month;
      if (groupId != null) {
        _lessonsFuture = _service.fetchGroupLessons(
          widget.session,
          groupId,
          month: month,
        );
      }
    });
    if (groupId != null) {
      _syncReportsForGroup(groupId, month);
    }
  }

  Future<void> _syncReportsForSelectedGroup() async {
    final groupId = _selectedGroupId;
    if (groupId == null) return;
    await _syncReportsForGroup(groupId, _month);
  }

  Future<void> _syncReportsForGroup(int groupId, String month) async {
    try {
      final reports = await _service.fetchGroupLessonReports(
        widget.session,
        groupId,
        month: month,
      );
      if (!mounted) return;
      setState(() {
        for (final report in reports) {
          _lessonReports[report.lessonId] = report;
        }
      });
    } catch (_) {
      // Serverdan report o'qilmasa mavjud UI holati saqlanib qoladi.
    }
  }

  bool _isToday(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return false;
    final now = DateTime.now();
    return parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
  }

  bool _canSend(TeacherLesson lesson) {
    final parsed = DateTime.tryParse(lesson.date);
    if (parsed == null) return false;
    final now = DateTime.now();
    final lessonDay = DateTime(parsed.year, parsed.month, parsed.day);
    final today = DateTime(now.year, now.month, now.day);
    return !lessonDay.isAfter(today);
  }

  Future<void> _openStatisticsEditor(
    TeacherLesson lesson, {
    required String groupName,
    TeacherLessonStatisticsReport? existingReport,
    bool readOnly = false,
  }) async {
    if (existingReport == null && !_canSend(lesson)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu dars uchun statistika yopilgan'),
          backgroundColor: Color(0xFFB45309),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final students = await _service.fetchLessonStudents(
      widget.session,
      lesson.id,
    );
    if (!mounted) return;

    final result = await showModalBottomSheet<TeacherLessonStatisticsReport>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _LessonStatisticsEditorSheet(
          lesson: lesson,
          groupName: groupName,
          students: students,
          initialReport: existingReport,
          readOnly: readOnly,
        );
      },
    );

    if (result == null) return;

    TeacherLessonStatisticsReport savedReport = result;
    try {
      savedReport = await _service.saveLessonStatistics(
        widget.session,
        lessonId: lesson.id,
        report: result,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is TeacherServiceException
                ? error.message
                : 'Statistika saqlanmadi',
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _lessonReports[lesson.id] = savedReport;
    });
    await _reloadGroups();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existingReport == null
              ? 'Statistika yuborildi: ${lesson.formattedDate}'
              : 'Statistika yangilandi: ${lesson.formattedDate}',
        ),
        backgroundColor: const Color(0xFF16934F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteStatisticsReport(TeacherLesson lesson) async {
    final removed = _lessonReports[lesson.id];
    if (removed == null) return;

    try {
      await _service.deleteLessonStatistics(widget.session, lesson.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is TeacherServiceException
                ? error.message
                : 'Statistika o\'chirilmadi',
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _lessonReports.remove(lesson.id);
    await _reloadGroups();
    if (!mounted) return;

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Statistika o\'chirildi: ${lesson.formattedDate}'),
        backgroundColor: const Color(0xFF64748B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Oylik statistika',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF182033),
          ),
        ),
      ),
      body: FutureBuilder<List<TeacherGroup>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          final groups = snapshot.data ?? const <TeacherGroup>[];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.brandColor),
            );
          }
          if (snapshot.hasError || groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.hasError
                      ? 'Guruhlar yuklanmadi'
                      : 'Sizga biriktirilgan guruhlar topilmadi',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            );
          }

          if (_selectedGroupId == null &&
              groups.isNotEmpty &&
              !_didApplyInitialSelection) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted ||
                  _selectedGroupId != null ||
                  _didApplyInitialSelection) {
                return;
              }
              _didApplyInitialSelection = true;
              final initialGroup = widget.initialGroupId == null
                  ? groups.first
                  : groups.firstWhere(
                      (group) => group.id == widget.initialGroupId,
                      orElse: () => groups.first,
                    );
              _selectGroup(initialGroup);
            });
          }

          TeacherGroup? selectedGroup;
          for (final group in groups) {
            if (group.id == _selectedGroupId) {
              selectedGroup = group;
              break;
            }
          }

          final months = _monthsForGroup(selectedGroup);

          return RefreshIndicator(
            onRefresh: () async {
              await _reloadGroups();
              await _reloadLessons();
            },
            color: AppTheme.brandColor,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _GroupStrip(
                  groups: groups,
                  selectedGroupId: _selectedGroupId,
                  onSelect: _selectGroup,
                ),
                const SizedBox(height: 10),
                _MonthStrip(
                  months: months,
                  selectedMonth: _month,
                  onSelect: _selectMonth,
                ),
                if (selectedGroup != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      selectedGroup.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF182033),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (_lessonsFuture != null)
                  FutureBuilder<List<TeacherLesson>>(
                    future: _lessonsFuture,
                    builder: (context, lessonSnapshot) {
                      final lessons =
                          lessonSnapshot.data ?? const <TeacherLesson>[];
                      if (lessonSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 56),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.brandColor,
                            ),
                          ),
                        );
                      }
                      if (lessonSnapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              lessonSnapshot.error is TeacherServiceException
                                  ? (lessonSnapshot.error
                                            as TeacherServiceException)
                                        .message
                                  : 'Darslar yuklanmadi',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      }
                      if (lessons.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              'Bu oy uchun darslar topilmadi',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      }

                      final sorted = [...lessons]
                        ..sort((a, b) {
                          final byDate = a.date.compareTo(b.date);
                          if (byDate != 0) return byDate;
                          return a.startTime.compareTo(b.startTime);
                        });

                      final lessonWidgets = <Widget>[];
                      for (final lesson in sorted) {
                        final report = _lessonReports[lesson.id];
                        final canEditReport =
                            report != null && _canSend(lesson);
                        lessonWidgets.add(
                          _LessonStatisticsCard(
                            lesson: lesson,
                            dayLabel: _formatDayLabel(lesson.date),
                            hasReport: report != null,
                            canSend: _canSend(lesson),
                            onSend: () => _openStatisticsEditor(
                              lesson,
                              groupName: selectedGroup?.name ?? '',
                            ),
                            onView: () => _openStatisticsEditor(
                              lesson,
                              groupName: selectedGroup?.name ?? '',
                              existingReport: report,
                              readOnly: true,
                            ),
                            onEdit: canEditReport
                                ? () => _openStatisticsEditor(
                                    lesson,
                                    groupName: selectedGroup?.name ?? '',
                                    existingReport: report,
                                    readOnly: false,
                                  )
                                : null,
                            onDelete: canEditReport
                                ? () => _deleteStatisticsReport(lesson)
                                : null,
                            canEditReport: canEditReport,
                            canDeleteReport: canEditReport,
                            isToday: _isToday(lesson.date),
                          ),
                        );
                        lessonWidgets.add(const SizedBox(height: 10));
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: lessonWidgets,
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TeacherDailyStatisticsCard extends StatelessWidget {
  const TeacherDailyStatisticsCard({
    super.key,
    required this.groups,
    required this.onOpen,
    required this.onOpenGroup,
  });

  final List<TeacherGroup> groups;
  final VoidCallback onOpen;
  final ValueChanged<int> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final todayGroups = groups
        .where((group) => group.todayLessonsCount > 0)
        .toList();
    final sentCount = todayGroups
        .where((group) => group.todayReportSent)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF7C0A05),
                  Color(0xFFA70E07),
                  Color(0xFFD32F2F),
                ],
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
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.today_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bugungi darslar',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Statistikalarni yuborish',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE8EEF9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${todayGroups.length} guruh',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (todayGroups.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Bugun dars yo\'q',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    for (final group in todayGroups.take(3)) ...[
                      InkWell(
                        onTap: () => onOpenGroup(group.id),
                        borderRadius: BorderRadius.circular(16),
                        child: _TodayGroupRow(group: group),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (todayGroups.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '+${todayGroups.length - 3} ta guruh',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: const Color(0xFF4ADE80),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$sentCount yuborildi',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${todayGroups.length - sentCount} kutilmoqda',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayGroupRow extends StatelessWidget {
  const _TodayGroupRow({required this.group});

  final TeacherGroup group;

  @override
  Widget build(BuildContext context) {
    final sent = group.todayReportSent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.school_rounded, size: 17, color: Colors.white),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${group.subjectName} • ${group.scheduleTime.isEmpty ? '—' : group.scheduleTime}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            sent
                ? Icons.check_circle_rounded
                : Icons.remove_circle_outline_rounded,
            color: sent
                ? const Color(0xFF4ADE80)
                : Colors.white.withValues(alpha: 0.78),
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _GroupStrip extends StatelessWidget {
  const _GroupStrip({
    required this.groups,
    required this.selectedGroupId,
    required this.onSelect,
  });

  final List<TeacherGroup> groups;
  final int? selectedGroupId;
  final ValueChanged<TeacherGroup> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = groups[index];
          final selected = group.id == selectedGroupId;
          final sent = group.todayReportSent;
          return GestureDetector(
            onTap: () => onSelect(group),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.brandColor : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? AppTheme.brandColor
                          : const Color(0xFFD6DDEA),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        group.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        sent
                            ? Icons.check_circle_rounded
                            : Icons.remove_circle_outline_rounded,
                        size: 15,
                        color: selected
                            ? Colors.white
                            : (sent
                                  ? const Color(0xFF16934F)
                                  : const Color(0xFF8A93A5)),
                      ),
                    ],
                  ),
                ),
                if (group.todayLessonsCount > 0) ...[
                  const SizedBox(height: 4),
                  _MiniPill(
                    label: group.todayReportSent
                        ? 'Report yuborildi'
                        : 'Report kutilmoqda',
                    backgroundColor: group.todayReportSent
                        ? const Color(0xFFEAF8EF)
                        : const Color(0xFFFFF4E5),
                    textColor: group.todayReportSent
                        ? const Color(0xFF16934F)
                        : const Color(0xFFB45309),
                    borderColor: group.todayReportSent
                        ? const Color(0xFFBFE7CD)
                        : const Color(0xFFF6C88B),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthStrip extends StatelessWidget {
  const _MonthStrip({
    required this.months,
    required this.selectedMonth,
    required this.onSelect,
  });

  final List<String> months;
  final String selectedMonth;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final month = months[index];
          final selected = month == selectedMonth;
          return GestureDetector(
            onTap: () => onSelect(month),
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
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _LessonStatisticsCard extends StatelessWidget {
  const _LessonStatisticsCard({
    required this.lesson,
    required this.dayLabel,
    required this.hasReport,
    required this.canSend,
    required this.onSend,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.canEditReport,
    required this.canDeleteReport,
    required this.isToday,
  });

  final TeacherLesson lesson;
  final String dayLabel;
  final bool hasReport;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool canEditReport;
  final bool canDeleteReport;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final stateColor = hasReport
        ? const Color(0xFF16934F)
        : canSend
        ? const Color(0xFFB45309)
        : const Color(0xFF8A93A5);

    final stateIcon = hasReport
        ? Icons.check_circle_rounded
        : Icons.remove_circle_outline_rounded;

    final stateLabel = hasReport
        ? 'Yuborildi'
        : canSend
        ? 'Yuborish mumkin'
        : 'Yopilgan';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(stateIcon, size: 20, color: stateColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayLabel,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF182033),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lesson.startTime}-${lesson.endTime} • '
                      '${lesson.markedStudentsCount}/${lesson.activeStudentsCount} belgilangan',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7B8495),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: stateColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 380;

              final badgeRow = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (isToday)
                    const _MiniBadge(icon: Icons.today_rounded, label: 'Bugun'),
                  _MiniBadge(
                    icon: lesson.attendanceCompleted
                        ? Icons.assignment_turned_in_rounded
                        : Icons.edit_note_rounded,
                    label: lesson.attendanceCompleted
                        ? 'Yakunlangan'
                        : 'Tayyorlanmoqda',
                  ),
                ],
              );

              Widget actionWidget;
              if (!hasReport) {
                actionWidget = FilledButton(
                  onPressed: canSend ? onSend : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Statistika yuborish'),
                );
              } else if (canEditReport) {
                actionWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: onEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF16934F),
                          side: const BorderSide(color: Color(0xFFBFE7CD)),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 40),
                          maximumSize: const Size(40, 40),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => _confirmDelete(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFF3C5C5)),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 40),
                          maximumSize: const Size(40, 40),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 16),
                      ),
                    ),
                  ],
                );
              } else {
                actionWidget = OutlinedButton.icon(
                  onPressed: onView,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF16934F),
                    side: const BorderSide(color: Color(0xFFBFE7CD)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Ko\'rish'),
                );
              }

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    badgeRow,
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: actionWidget,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: badgeRow),
                  const SizedBox(width: 8),
                  actionWidget,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hisobotni o\'chirish'),
          content: const Text('Bu statistika o\'chirilsinmi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDelete?.call();
              },
              child: const Text('O\'chirish'),
            ),
          ],
        );
      },
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreControllers {
  _ScoreControllers({
    String homework = '',
    String vocabulary = '',
    String attendance = '',
    String participation = '',
  }) : homework = TextEditingController(text: homework),
       vocabulary = TextEditingController(text: vocabulary),
       attendance = TextEditingController(text: attendance),
       participation = TextEditingController(text: participation);

  final TextEditingController homework;
  final TextEditingController vocabulary;
  final TextEditingController attendance;
  final TextEditingController participation;

  void dispose() {
    homework.dispose();
    vocabulary.dispose();
    attendance.dispose();
    participation.dispose();
  }
}

class _LessonStatisticsEditorSheet extends StatefulWidget {
  const _LessonStatisticsEditorSheet({
    required this.lesson,
    required this.groupName,
    required this.students,
    required this.initialReport,
    required this.readOnly,
  });

  final TeacherLesson lesson;
  final String groupName;
  final List<LessonStudent> students;
  final TeacherLessonStatisticsReport? initialReport;
  final bool readOnly;

  @override
  State<_LessonStatisticsEditorSheet> createState() =>
      _LessonStatisticsEditorSheetState();
}

class _LessonStatisticsEditorSheetState
    extends State<_LessonStatisticsEditorSheet> {
  static const int _maxHomework = 10;
  static const int _maxVocabulary = 10;
  static const int _maxAttendance = 5;
  static const int _maxParticipation = 10;
  static const int _maxTotal =
      _maxHomework + _maxVocabulary + _maxAttendance + _maxParticipation;

  late final List<_ScoreControllers> _controllers;
  late final Map<int, TeacherLessonStatisticsRowReport> _initialRowsById;
  late final bool _readOnly;

  double get _statisticsTableWidth =>
      _statisticsStudentColumnWidth +
      (_statisticsScoreColumnWidth * 4) +
      _statisticsTotalColumnWidth +
      _statisticsPercentColumnWidth +
      _statisticsFeedbackColumnWidth +
      (_statisticsColumnGap * 7) +
      (_statisticsHorizontalPadding * 2);

  @override
  void initState() {
    super.initState();
    _readOnly = widget.readOnly;
    _initialRowsById = {
      for (final row in widget.initialReport?.rows ?? const [])
        row.studentId: row,
    };
    _controllers = [
      for (final student in widget.students)
        _buildControllersForStudent(student),
    ];
  }

  _ScoreControllers _buildControllersForStudent(LessonStudent student) {
    final row = _initialRowsById[student.studentId];
    final attendance =
        row?.attendance.toString() ??
        _defaultAttendanceForStudent(student).toString();
    return _ScoreControllers(
      homework: row?.homework.toString() ?? '',
      vocabulary: row?.vocabulary.toString() ?? '',
      attendance: attendance,
      participation: row?.participation.toString() ?? '',
    );
  }

  int _defaultAttendanceForStudent(LessonStudent student) {
    final status = student.status.trim().toLowerCase();
    if (status == 'keldi') return _maxAttendance;
    if (status == 'kechikdi') return (_maxAttendance / 2).ceil();
    return 0;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  int _parseScore(String text, int max) {
    final value = int.tryParse(text.trim()) ?? 0;
    if (value < 0) return 0;
    if (value > max) return max;
    return value;
  }

  int _totalFor(_ScoreControllers controllers) =>
      _parseScore(controllers.homework.text, _maxHomework) +
      _parseScore(controllers.vocabulary.text, _maxVocabulary) +
      _parseScore(controllers.attendance.text, _maxAttendance) +
      _parseScore(controllers.participation.text, _maxParticipation);

  int _percentFor(int total) =>
      ((_maxTotal == 0 ? 0 : total / _maxTotal) * 100).round().clamp(0, 100);

  String _feedbackFor(int percent) {
    if (percent >= 80) return 'PERFECT';
    if (percent >= 60) return 'GOOD';
    return 'BAD';
  }

  Color _feedbackColor(String feedback) {
    switch (feedback) {
      case 'PERFECT':
        return const Color(0xFF2563EB);
      case 'GOOD':
        return const Color(0xFF16934F);
      default:
        return const Color(0xFFDC2626);
    }
  }

  void _showColumnHelp(
    String shortTitle,
    String fullTitle,
    String description,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(fullTitle),
          content: Text(
            '$shortTitle — $description',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Yopish'),
            ),
          ],
        );
      },
    );
  }

  TeacherLessonStatisticsReport _buildReport() {
    final rows = <TeacherLessonStatisticsRowReport>[];
    for (var i = 0; i < widget.students.length; i++) {
      final student = widget.students[i];
      final controllers = _controllers[i];
      final homework = _parseScore(controllers.homework.text, _maxHomework);
      final vocabulary = _parseScore(
        controllers.vocabulary.text,
        _maxVocabulary,
      );
      final attendance = _parseScore(
        controllers.attendance.text,
        _maxAttendance,
      );
      final participation = _parseScore(
        controllers.participation.text,
        _maxParticipation,
      );
      final total = homework + vocabulary + attendance + participation;
      final percent = _percentFor(total);
      rows.add(
        TeacherLessonStatisticsRowReport(
          studentId: student.studentId,
          studentName: student.studentName,
          homework: homework,
          vocabulary: vocabulary,
          attendance: attendance,
          participation: participation,
          total: total,
          percent: percent,
          feedback: _feedbackFor(percent),
        ),
      );
    }

    return TeacherLessonStatisticsReport(
      lessonId: widget.lesson.id,
      lessonLabel:
          '${widget.lesson.formattedDate} • ${widget.lesson.weekdayName}',
      groupName: widget.groupName,
      createdAt: DateTime.now().toIso8601String(),
      rows: rows,
    );
  }

  Widget _headerCell(
    String title, {
    String? subtitle,
    String? fullTitle,
    String? description,
    double width = 60,
    Alignment alignment = Alignment.center,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: fullTitle == null || description == null
            ? null
            : () => _showColumnHelp(title, fullTitle, description),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          alignment: alignment,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 7.0,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 6.8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreField({
    required TextEditingController controller,
    required int maxValue,
    required bool enabled,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6DDEA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD6DDEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.brandColor, width: 1.2),
        ),
        hintText: '0-$maxValue',
        hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
      ),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF182033),
      ),
    );
  }

  List<String> _splitStudentName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return const <String>[];
    if (parts.length == 1) return [parts.first];
    return [parts.first, parts.skip(1).join(' ')];
  }

  Widget _studentRow(int index) {
    final student = widget.students[index];
    final controllers = _controllers[index];
    final total = _totalFor(controllers);
    final percent = _percentFor(total);
    final feedback = _feedbackFor(percent);
    final feedbackColor = _feedbackColor(feedback);
    final nameLines = _splitStudentName(student.studentName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _statisticsStudentColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameLines.isNotEmpty
                        ? nameLines.first
                        : student.studentName,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF182033),
                      height: 1.05,
                    ),
                  ),
                  if (nameLines.length > 1) ...[
                    const SizedBox(height: 1),
                    Text(
                      nameLines[1],
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        height: 1.05,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: _statisticsColumnGap),
          SizedBox(
            width: _statisticsScoreColumnWidth,
            child: _scoreField(
              controller: controllers.homework,
              maxValue: _maxHomework,
              enabled: !_readOnly,
            ),
          ),
          const SizedBox(width: _statisticsColumnGap),
          SizedBox(
            width: _statisticsScoreColumnWidth,
            child: _scoreField(
              controller: controllers.vocabulary,
              maxValue: _maxVocabulary,
              enabled: !_readOnly,
            ),
          ),
          const SizedBox(width: _statisticsColumnGap),
          SizedBox(
            width: _statisticsScoreColumnWidth,
            child: _scoreField(
              controller: controllers.attendance,
              maxValue: _maxAttendance,
              enabled: !_readOnly,
            ),
          ),
          const SizedBox(width: _statisticsColumnGap),
          SizedBox(
            width: _statisticsScoreColumnWidth,
            child: _scoreField(
              controller: controllers.participation,
              maxValue: _maxParticipation,
              enabled: !_readOnly,
            ),
          ),
          const SizedBox(width: _statisticsColumnGap),
          SizedBox(
            width: _statisticsTotalColumnWidth,
            child: Text(
              '$total',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF182033),
              ),
            ),
          ),
          SizedBox(
            width: _statisticsPercentColumnWidth,
            child: Text(
              '$percent%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF182033),
              ),
            ),
          ),
          SizedBox(
            width: _statisticsFeedbackColumnWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: feedbackColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                feedback,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.0,
                  fontWeight: FontWeight.w900,
                  color: feedbackColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.95,
      child: Material(
        color: const Color(0xFFF6F7FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _readOnly
                                ? 'Hisobotni ko\'rish'
                                : 'Statistika yuborish',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF182033),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.groupName} • ${widget.lesson.formattedDate}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE4E9F1)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MiniBadge(
                        icon: Icons.school_rounded,
                        label: widget.students.length.toString(),
                      ),
                      _MiniBadge(
                        icon: Icons.calendar_month_rounded,
                        label: widget.lesson.weekdayName,
                      ),
                      _MiniBadge(
                        icon: Icons.timer_outlined,
                        label:
                            '${widget.lesson.startTime}-${widget.lesson.endTime}',
                      ),
                      const _MiniBadge(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Avto hisob',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: _statisticsTableWidth,
                        height: constraints.maxHeight,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B4A7A),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    _headerCell(
                                      'STUDENTS',
                                      width: _statisticsStudentColumnWidth,
                                      alignment: Alignment.centerLeft,
                                      fullTitle: 'Students',
                                      description:
                                          'O\'quvchi ismi va familiyasi',
                                    ),
                                    const SizedBox(width: _statisticsColumnGap),
                                    _headerCell(
                                      'HK',
                                      width: _statisticsScoreColumnWidth,
                                      subtitle: '10',
                                      fullTitle: 'Homework',
                                      description:
                                          'Uy vazifasi uchun berilgan ball',
                                    ),
                                    const SizedBox(width: _statisticsColumnGap),
                                    _headerCell(
                                      'VOCAB',
                                      width: _statisticsScoreColumnWidth,
                                      subtitle: '10',
                                      fullTitle: 'Vocabulary',
                                      description:
                                          'So\'z boyligi uchun berilgan ball',
                                    ),
                                    const SizedBox(width: _statisticsColumnGap),
                                    _headerCell(
                                      'ATTEND',
                                      width: _statisticsScoreColumnWidth,
                                      subtitle: '5',
                                      fullTitle: 'Attendance',
                                      description:
                                          'Davomat va darsga qatnashuv balli',
                                    ),
                                    const SizedBox(width: _statisticsColumnGap),
                                    _headerCell(
                                      'PART',
                                      width: _statisticsScoreColumnWidth,
                                      subtitle: '10',
                                      fullTitle: 'Participation',
                                      description:
                                          'Darsdagi faollik va qatnashuv balli',
                                    ),
                                    const SizedBox(width: _statisticsColumnGap),
                                    _headerCell(
                                      'TOT',
                                      width: _statisticsTotalColumnWidth,
                                      subtitle: '35',
                                      fullTitle: 'Total',
                                      description:
                                          'Barcha ustunlar yig\'indisi',
                                    ),
                                    const SizedBox(width: _statisticsColumnGap),
                                    _headerCell(
                                      'PCT',
                                      width: _statisticsPercentColumnWidth,
                                      subtitle: '100%',
                                      fullTitle: 'Percent',
                                      description:
                                          'To\'plangan ballning foiz ko\'rinishi',
                                    ),
                                    const SizedBox(width: _statisticsColumnGap),
                                    _headerCell(
                                      'FB',
                                      width: _statisticsFeedbackColumnWidth,
                                      fullTitle: 'Feedback',
                                      description:
                                          'Avtomatik baho: BAD, GOOD yoki PERFECT',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: widget.students.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Bu dars uchun o\'quvchilar topilmadi',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    )
                                  : ListView(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        16,
                                      ),
                                      children: [
                                        for (
                                          var i = 0;
                                          i < widget.students.length;
                                          i++
                                        )
                                          _studentRow(i),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFD6DDEA)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Bekor qilish'),
                      ),
                    ),
                    if (!_readOnly) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final report = _buildReport();
                            Navigator.of(context).pop(report);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.brandColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            widget.initialReport == null
                                ? 'Yuborish'
                                : 'Yangilash',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
