import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/student_groups_service.dart';

class StudentPointReportsPage extends StatefulWidget {
  const StudentPointReportsPage({
    super.key,
    required this.session,
    this.initialGroupId,
    this.initialMonth,
  });

  final AuthSession session;
  final int? initialGroupId;

  /// Ochilganda tanlanadigan oy (YYYY-MM). Bo'lmasa joriy oy.
  final String? initialMonth;

  @override
  State<StudentPointReportsPage> createState() =>
      _StudentPointReportsPageState();
}

class _StudentPointReportsPageState extends State<StudentPointReportsPage> {
  final StudentGroupsService _service = StudentGroupsService();
  late Future<List<StudentGroupSummary>> _groupsFuture;
  Future<StudentPointReportsData>? _reportsFuture;
  Future<StudentGroupDetails>? _lessonReportsFuture;
  int? _selectedGroupId;
  late String _selectedMonth;

  @override
  void initState() {
    super.initState();
    final initialMonth = widget.initialMonth?.trim();
    _selectedMonth =
        (initialMonth != null &&
            RegExp(r'^\d{4}-\d{2}$').hasMatch(initialMonth))
        ? initialMonth
        : _currentMonthKey();
    _groupsFuture = _service.fetchMyGroups(widget.session);
    _loadInitialSelection();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _groupsFuture = _service.fetchMyGroups(widget.session);
    });
    final groups = await _groupsFuture;
    if (!mounted) return;
    if (groups.isEmpty) {
      setState(() {
        _selectedGroupId = null;
        _reportsFuture = null;
        _lessonReportsFuture = null;
      });
      return;
    }
    final selected = groups.any((group) => group.groupId == _selectedGroupId)
        ? _selectedGroupId
        : groups.first.groupId;
    final selectedGroup = groups.firstWhere(
      (group) => group.groupId == selected,
      orElse: () => groups.first,
    );
    final validMonth = _monthForGroup(selectedGroup, preferred: _selectedMonth);
    setState(() {
      _selectedGroupId = selected;
      _selectedMonth = validMonth;
      _reportsFuture = _service.fetchMyPointReports(
        widget.session,
        month: validMonth,
        groupId: _selectedGroupId,
      );
      _lessonReportsFuture = selected == null
          ? null
          : _service.fetchMyGroupInfo(
              widget.session,
              selected,
              month: validMonth,
            );
    });
    final reportsFuture = _reportsFuture;
    if (reportsFuture != null) {
      await reportsFuture;
    }
  }

  Future<void> _loadInitialSelection() async {
    try {
      final groups = await _groupsFuture;
      if (!mounted) return;
      if (groups.isEmpty) {
        setState(() {
          _reportsFuture = null;
          _lessonReportsFuture = null;
        });
        return;
      }
      final initialGroup = widget.initialGroupId;
      final selected = groups.any((group) => group.groupId == initialGroup)
          ? initialGroup
          : groups.first.groupId;
      final selectedGroup = groups.firstWhere(
        (group) => group.groupId == selected,
        orElse: () => groups.first,
      );
      final validMonth = _monthForGroup(
        selectedGroup,
        preferred: _selectedMonth,
      );
      setState(() {
        _selectedGroupId = selected;
        _selectedMonth = validMonth;
        _reportsFuture = _service.fetchMyPointReports(
          widget.session,
          month: validMonth,
          groupId: _selectedGroupId,
        );
        _lessonReportsFuture = selected == null
            ? null
            : _service.fetchMyGroupInfo(
                widget.session,
                selected,
                month: validMonth,
              );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reportsFuture = null;
        _lessonReportsFuture = null;
      });
    }
  }

  void _selectGroup(StudentGroupSummary group) {
    if (_selectedGroupId == group.groupId) return;
    final validMonth = _monthForGroup(group, preferred: _selectedMonth);
    setState(() {
      _selectedGroupId = group.groupId;
      _selectedMonth = validMonth;
      _reportsFuture = _service.fetchMyPointReports(
        widget.session,
        month: validMonth,
        groupId: _selectedGroupId,
      );
      _lessonReportsFuture = _service.fetchMyGroupInfo(
        widget.session,
        group.groupId,
        month: validMonth,
      );
    });
  }

  void _selectMonth(String monthKey) {
    if (_selectedMonth == monthKey) return;
    setState(() {
      _selectedMonth = monthKey;
      if (_selectedGroupId != null) {
        _reportsFuture = _service.fetchMyPointReports(
          widget.session,
          month: monthKey,
          groupId: _selectedGroupId,
        );
        _lessonReportsFuture = _service.fetchMyGroupInfo(
          widget.session,
          _selectedGroupId!,
          month: monthKey,
        );
      }
    });
  }

  /// Tanlangan guruhda o'qish boshlangan oydan joriy oygacha (joriy oy
  /// birinchi). Boshlanish sanasi topilmasa faqat joriy oy chiqadi.
  List<String> _monthOptionsFor(StudentGroupSummary? group) {
    if (group?.availableMonths.isNotEmpty == true) {
      return group!.availableMonths;
    }
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    final startDate = _parseDdMmYyyy(group?.myJoinDate ?? '');
    final leaveDate = _parseDdMmYyyy(group?.myLeaveDate ?? '');
    var start = startDate == null
        ? current
        : DateTime(startDate.year, startDate.month);
    var end = leaveDate == null
        ? current
        : DateTime(leaveDate.year, leaveDate.month);
    if (start.isAfter(current)) start = current;
    if (end.isAfter(current)) end = current;
    if (end.isBefore(start)) end = start;

    final months = <String>[];
    var cursor = end;
    while (!cursor.isBefore(start) && months.length < 24) {
      months.add('${cursor.year}-${cursor.month.toString().padLeft(2, '0')}');
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    return months;
  }

  String _monthForGroup(
    StudentGroupSummary group, {
    String? preferred,
  }) {
    final months = _monthOptionsFor(group);
    if (months.isEmpty) {
      return preferred != null && RegExp(r'^\d{4}-\d{2}$').hasMatch(preferred)
          ? preferred
          : _currentMonthKey();
    }
    if (preferred != null && months.contains(preferred)) {
      return preferred;
    }
    return months.first;
  }

  String _bestMonthForLessonReports(
    List<StudentLessonReport> reports, {
    String? preferred,
  }) {
    final reportMonths = <String>[];
    for (final report in reports) {
      final month = _monthFromLessonReport(report);
      if (month != null) {
        reportMonths.add(month);
      }
    }
    final uniqueMonths = reportMonths.toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    if (uniqueMonths.isEmpty) {
      return preferred != null &&
              RegExp(r'^\d{4}-\d{2}$').hasMatch(preferred)
          ? preferred
          : _currentMonthKey();
    }
    if (preferred != null && uniqueMonths.contains(preferred)) {
      return preferred;
    }
    return uniqueMonths.first;
  }

  static String? _monthFromLessonReport(StudentLessonReport report) {
    final parsed = _parseAnyDate(report.lessonDate);
    if (parsed == null) return null;
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDdMmYyyy(String value) {
    final parts = value.trim().replaceAll('/', '.').split('.');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12) return null;
    return DateTime(year, month, day);
  }

  static DateTime? _parseAnyDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }
    final normalized = text.replaceAll('/', '.');
    final parts = normalized.split('.');
    if (parts.length != 3) return null;
    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    final third = int.tryParse(parts[2]);
    if (first == null || second == null || third == null) return null;
    if (second < 1 || second > 12) return null;
    if (parts[0].length == 4) {
      return DateTime(first, second, third);
    }
    return DateTime(third, second, first);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Hisobot'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: AppTheme.brandColor,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            FutureBuilder<List<StudentGroupSummary>>(
              future: _groupsFuture,
              builder: (context, snapshot) {
                final groups = snapshot.data ?? const <StudentGroupSummary>[];
                final error = snapshot.error;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingCard(height: 140);
                }
                if (error != null) {
                  return _ErrorCard(
                    message: _readErrorMessage(error),
                    onRetry: _reload,
                  );
                }
                if (groups.isEmpty) {
                  return const _EmptyCard();
                }
                // Tanlangan guruh — oylar oralig'i shu guruhga qarab quriladi
                StudentGroupSummary? selectedGroup;
                for (final group in groups) {
                  if (group.groupId == _selectedGroupId) {
                    selectedGroup = group;
                    break;
                  }
                }
                final months = _monthOptionsFor(selectedGroup);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MonthHeader(monthLabel: _monthLabel(_selectedMonth)),
                    const SizedBox(height: 10),
                    // Guruh tanlash chiplari
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: groups.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final selected = group.groupId == _selectedGroupId;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _selectGroup(group),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.brandColor
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.brandColor
                                      : const Color(0xFFD6DDEA),
                                ),
                              ),
                              child: Text(
                                group.groupName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 8),
                    // Oy tanlash — o'tgan oylar hisobotini ko'rish uchun
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: months.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final month = months[index];
                          final selected = month == _selectedMonth;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _selectMonth(month),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.brandColor.withValues(
                                        alpha: 0.10,
                                      )
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.brandColor
                                      : const Color(0xFFD6DDEA),
                                ),
                              ),
                              child: Text(
                                _monthLabel(month),
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
                    const SizedBox(height: 12),
                    if (_reportsFuture == null)
                      const _EmptyCard()
                    else
                      FutureBuilder<StudentPointReportsData>(
                        future: _reportsFuture,
                        builder: (context, reportSnapshot) {
                          final reportError = reportSnapshot.error;
                          final report = reportSnapshot.data;
                          if (reportSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const _LoadingCard(height: 220);
                          }

                          final reportSection =
                              reportError != null || report == null
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _DailyStatsCard(
                                      dailyBreakdown: report.dailyBreakdown,
                                    ),
                                    const SizedBox(height: 12),
                                    _BreakdownCard(breakdown: report.breakdown),
                                  ],
                                );

                          if (_lessonReportsFuture == null) {
                            return reportSection;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              reportSection,
                              const SizedBox(height: 12),
                              FutureBuilder<StudentGroupDetails>(
                                future: _lessonReportsFuture,
                                builder: (context, lessonSnapshot) {
                                  final lessonError = lessonSnapshot.error;
                                  final lessonDetail = lessonSnapshot.data;
                                  if (lessonSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const _LoadingCard(height: 220);
                                  }
                                  if (lessonError != null ||
                                      lessonDetail == null) {
                                    return _ErrorCard(
                                      message: _readErrorMessage(lessonError),
                                      onRetry: _reload,
                                    );
                                  }
                                  final fallbackMonth = _bestMonthForLessonReports(
                                    lessonDetail.lessonReports,
                                    preferred: _selectedMonth,
                                  );
                                  if (fallbackMonth != _selectedMonth &&
                                      lessonDetail.lessonReports.isNotEmpty) {
                                    WidgetsBinding.instance.addPostFrameCallback((
                                      _,
                                    ) {
                                      if (!mounted) return;
                                      _selectMonth(fallbackMonth);
                                    });
                                  }
                                  final lessonReports = lessonDetail.lessonReports
                                      .where(
                                        (report) =>
                                            _monthFromLessonReport(report) ==
                                            _selectedMonth,
                                      )
                                      .toList();
                                  return _LessonReportsCard(
                                    reports: lessonReports,
                                    selectedMonth: _selectedMonth,
                                    subjectName: lessonDetail.subjectName,
                                    teacherName: lessonDetail.teacherName,
                                    currentStudentId: widget.session.user.id,
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _readErrorMessage(Object? error) {
    if (error is StudentGroupsException) {
      return error.message;
    }
    return 'Hisobot yuklanmadi';
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.monthLabel});

  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kunlik hisobot',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  monthLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyStatsCard extends StatelessWidget {
  const _DailyStatsCard({required this.dailyBreakdown});

  final List<StudentPointDailyBreakdown> dailyBreakdown;

  @override
  Widget build(BuildContext context) {
    final todayKey = _todayKey();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.calendar_month_rounded,
            title: 'Dars kunlari bo\'yicha hisobotlar',
          ),
          const SizedBox(height: 12),
          if (dailyBreakdown.isEmpty)
            const Text(
              'Hozircha bu oy uchun kunlik ma\'lumot yo\'q',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7B8495),
              ),
            )
          else
            for (var i = 0; i < dailyBreakdown.length; i++) ...[
              Builder(
                builder: (context) {
                  final day = dailyBreakdown[i];
                  final isToday = day.dayKey == todayKey;
                  final positive = day.totalPoints >= 0;
                  return Row(
                    children: [
                      // Sana kvadrati
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppTheme.brandColor.withValues(alpha: 0.08)
                              : const Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.circular(16),
                          border: isToday
                              ? Border.all(
                                  color: AppTheme.brandColor.withValues(
                                    alpha: 0.35,
                                  ),
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isToday ? 'Bugun' : _dayShortLabel(day.dayKey),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isToday ? 10 : 14,
                            fontWeight: FontWeight.w900,
                            color: isToday
                                ? AppTheme.brandColor
                                : const Color(0xFF445064),
                            height: 1.05,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDayKey(day.dayKey),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF182033),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${day.totalEvents} ta dars yozuvi',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8A93A5),
                              ),
                            ),
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
                          color: positive
                              ? const Color(0xFF16934F).withValues(alpha: 0.08)
                              : const Color(0xFFDC2626).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          positive
                              ? '+${day.totalPoints} ball'
                              : '${day.totalPoints} ball',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: positive
                                ? const Color(0xFF16934F)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (i < dailyBreakdown.length - 1) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFEDF1F7)),
                const SizedBox(height: 8),
              ],
            ],
        ],
      ),
    );
  }
}

/// Karta sarlavhasi: brend gradientli ikonka + matn
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF182033),
            ),
          ),
        ),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.breakdown});

  final List<StudentPointBreakdown> breakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.groups_rounded,
            title: 'Guruhlar bo\'yicha',
          ),
          const SizedBox(height: 12),
          if (breakdown.isEmpty)
            const Text(
              'Hozircha ma\'lumot yo\'q',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7B8495),
              ),
            )
          else
            for (final item in breakdown) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.groupName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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
                      color: AppTheme.brandColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${item.totalPoints} ball',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.brandColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _LessonReportsCard extends StatelessWidget {
  const _LessonReportsCard({
    required this.reports,
    required this.selectedMonth,
    required this.subjectName,
    required this.teacherName,
    required this.currentStudentId,
  });

  final List<StudentLessonReport> reports;
  final String selectedMonth;
  final String subjectName;
  final String teacherName;
  final int currentStudentId;

  @override
  Widget build(BuildContext context) {
    final visibleReports = reports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kunlik hisobotlar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              Text(
                '${visibleReports.length} ta',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A93A5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (visibleReports.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'Tanlangan oy uchun report topilmadi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < visibleReports.length; i++) ...[
                _LessonReportTile(
                  report: visibleReports[i],
                  subjectName: subjectName,
                  teacherName: teacherName,
                  currentStudentId: currentStudentId,
                ),
                if (i < visibleReports.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }
}

/// Talabaning o'ziga tegishli jadval qatorini ajratib ko'rsatish uchun fon.
/// Baholash tuslaridan (ko'k/yashil/qizil) ataylab farqli — chalkashmasin.
const Color _selfRowHighlight = Color(0xFFFFF3D6);

class _LessonReportTile extends StatelessWidget {
  const _LessonReportTile({
    required this.report,
    required this.subjectName,
    required this.teacherName,
    required this.currentStudentId,
  });

  final StudentLessonReport report;
  final String subjectName;
  final String teacherName;
  final int currentStudentId;

  @override
  Widget build(BuildContext context) {
    final visibleColumns = report.columns
        .where((column) => column.enabled)
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatLessonDate(report.lessonDate),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF182033),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'O\'qituvchi: $teacherName • Fan: $subjectName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5A6478),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              children: [
                if (report.rows.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE1E7F0)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 12,
                        horizontalMargin: 12,
                        headingRowHeight: 36,
                        dataRowMinHeight: 36,
                        dataRowMaxHeight: 48,
                        columns: [
                          const DataColumn(label: Text('Talaba')),
                          for (final column in visibleColumns)
                            DataColumn(label: Text(column.label)),
                          const DataColumn(label: Text('Jami')),
                          const DataColumn(label: Text('Foiz')),
                          const DataColumn(label: Text('Baho')),
                        ],
                        rows: report.rows
                            .map(
                              (row) {
                                final isMe = row.studentId == currentStudentId;
                                return DataRow(
                                color: isMe
                                    ? WidgetStateProperty.all(
                                        _selfRowHighlight,
                                      )
                                    : null,
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 130,
                                      child: Text(
                                        _formatStudentName(row.studentName),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: isMe
                                            ? const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  for (final column in visibleColumns)
                                    DataCell(
                                      Text('${row.valueForColumn(column.key)}'),
                                    ),
                                  DataCell(Text('${row.total}')),
                                  DataCell(Text('${row.percent}%')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _reportTone(
                                          row.feedback,
                                        ).badgeBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _reportTone(
                                            row.feedback,
                                          ).border,
                                        ),
                                      ),
                                      child: Text(
                                        _feedbackLabelUz(row.feedback),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: _reportTone(
                                            row.feedback,
                                          ).badgeFg,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                );
                              },
                            )
                            .toList(),
                      ),
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
}

String _feedbackLabelUz(String feedback) {
  final normalized = feedback.trim().toUpperCase();
  if (normalized.contains('BAD')) return 'Past';
  if (normalized.contains('PERFECT')) return 'A’lo';
  if (normalized.contains('GOOD')) return 'Yaxshi';
  return feedback.isEmpty ? 'Baholanmagan' : feedback;
}

class _ReportTone {
  const _ReportTone({
    required this.border,
    required this.header,
    required this.badgeBg,
    required this.badgeFg,
  });

  final Color border;
  final Color header;
  final Color badgeBg;
  final Color badgeFg;
}

_ReportTone _reportTone(String feedback) {
  switch (feedback.trim().toUpperCase()) {
    case 'PERFECT':
      return const _ReportTone(
        border: Color(0xFFB9D5FF),
        header: Color(0xFFEAF2FF),
        badgeBg: Color(0xFFDCEBFF),
        badgeFg: Color(0xFF275DDE),
      );
    case 'GOOD':
      return const _ReportTone(
        border: Color(0xFFB9E7C9),
        header: Color(0xFFEAF8EE),
        badgeBg: Color(0xFFDFF6E7),
        badgeFg: Color(0xFF118B50),
      );
    default:
      return const _ReportTone(
        border: Color(0xFFF3C0C0),
        header: Color(0xFFFCECEC),
        badgeBg: Color(0xFFFEE2E2),
        badgeFg: Color(0xFFC81E1E),
      );
  }
}

String _formatLessonDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  const months = [
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
  const weekdays = [
    'Dushanba',
    'Seshanba',
    'Chorshanba',
    'Payshanba',
    'Juma',
    'Shanba',
    'Yakshanba',
  ];
  final month = months[parsed.month - 1];
  final weekday = weekdays[(parsed.weekday - 1) % 7];
  return '${parsed.day.toString().padLeft(2, '0')} $month ${parsed.year} • $weekday';
}

String _formatStudentName(String value) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return 'Noma\'lum';
  final parts = text.split(' ');
  if (parts.length <= 1) return text;
  return '${parts.first}\n${parts.skip(1).join(' ')}';
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: const CircularProgressIndicator(color: AppTheme.brandColor),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.brandColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Qayta urinish'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: const Text(
        'Hozircha hisobot yo‘q',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7B8495),
        ),
      ),
    );
  }
}

String _currentMonthKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

String _monthLabel(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final year = int.tryParse(parts[0]) ?? DateTime.now().year;
  final month = int.tryParse(parts[1]) ?? DateTime.now().month;
  const months = [
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
  final monthName = month >= 1 && month <= months.length
      ? months[month - 1]
      : monthKey;
  return '$monthName $year';
}

String _todayKey() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String _formatDayKey(String dayKey) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dayKey.trim());
  if (match == null) return dayKey;
  final year = int.tryParse(match.group(1)!) ?? DateTime.now().year;
  final month = int.tryParse(match.group(2)!) ?? DateTime.now().month;
  final day = int.tryParse(match.group(3)!) ?? DateTime.now().day;
  const months = [
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
  if (month < 1 || month > months.length) return dayKey;
  return '$day ${months[month - 1]} $year';
}

String _dayShortLabel(String dayKey) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dayKey.trim());
  if (match == null) return dayKey;
  return match.group(3) ?? dayKey;
}
