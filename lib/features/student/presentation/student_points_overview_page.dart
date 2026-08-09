import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/student_groups_service.dart';
import 'student_point_reports_page.dart';

/// Student ballari umumiy ko'rinishi:
/// - Joriy oyda to'plagan ball
/// - O'qishni boshlagandan beri umumiy ball
/// - Oylar bo'yicha ball + o'sha oyda qaysi teacher qancha ball qo'ygani
class StudentPointsOverviewPage extends StatefulWidget {
  const StudentPointsOverviewPage({
    super.key,
    required this.session,
    this.service,
  });

  final AuthSession session;

  /// Test uchun inject qilinadi; bo'lmasa ichki servis yaratiladi.
  final StudentGroupsService? service;

  @override
  State<StudentPointsOverviewPage> createState() =>
      _StudentPointsOverviewPageState();
}

class _StudentPointsOverviewPageState extends State<StudentPointsOverviewPage> {
  late final StudentGroupsService _service;
  late final bool _ownsService;
  late Future<StudentPointReportsData> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StudentGroupsService();
    _ownsService = widget.service == null;
    _future = _load();
  }

  @override
  void dispose() {
    if (_ownsService) _service.dispose();
    super.dispose();
  }

  Future<StudentPointReportsData> _load() {
    // month='all' — butun o'qish davri bo'yicha to'liq tarix
    return _service
        .fetchMyPointReports(widget.session, month: 'all')
        .then(_normalizeAllTimeHistory)
        .catchError((_) async {
      try {
        final groups = await _service.fetchMyGroups(widget.session);
        return _buildFallbackData(groups);
      } catch (_) {
        return _buildFallbackData(const <StudentGroupSummary>[]);
      }
    });
  }

  StudentPointReportsData _normalizeAllTimeHistory(
    StudentPointReportsData data,
  ) {
    if (data.events.isEmpty) return data;

    final breakdownMap = <String, _AggregateBucket>{};
    final monthlyMap = <String, _AggregateBucket>{};
    final dailyMap = <String, _DailyAggregateBucket>{};

    for (final event in data.events) {
      final monthKey = _eventMonthKey(event);
      final groupKey = '${event.groupId ?? 0}:${event.groupName.trim()}';
      final dayKey = event.dayKey.trim();

      breakdownMap
          .putIfAbsent(
            groupKey,
            () => _AggregateBucket(
              groupId: event.groupId,
              groupName:
                  event.groupName.trim().isEmpty ? 'Guruh' : event.groupName,
            ),
          )
          .add(event.points);

      monthlyMap
          .putIfAbsent(
            monthKey,
            () => _AggregateBucket(
              groupId: null,
              groupName: monthKey,
            ),
          )
          .add(event.points);

      dailyMap
          .putIfAbsent(
            dayKey,
            () => _DailyAggregateBucket(dayKey),
          )
          .add(event.points, event.createdTime);
    }

    final breakdown = breakdownMap.values
        .map(
          (bucket) => StudentPointBreakdown(
            groupId: bucket.groupId,
            groupName: bucket.groupName,
            totalPoints: bucket.totalPoints,
            totalEvents: bucket.totalEvents,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    final monthlyBreakdown = monthlyMap.values
        .map(
          (bucket) => StudentPointMonthlyBreakdown(
            monthName: bucket.groupName,
            totalPoints: bucket.totalPoints,
            totalEvents: bucket.totalEvents,
          ),
        )
        .toList()
      ..sort((a, b) => b.monthName.compareTo(a.monthName));

    final dailyBreakdown = dailyMap.values
        .map(
          (bucket) => StudentPointDailyBreakdown(
            dayKey: bucket.dayKey,
            totalPoints: bucket.totalPoints,
            totalEvents: bucket.totalEvents,
            firstTime: bucket.firstTime,
            lastTime: bucket.lastTime,
          ),
        )
        .toList()
      ..sort((a, b) => b.dayKey.compareTo(a.dayKey));

    return StudentPointReportsData(
      month: data.month,
      summary: data.summary,
      breakdown: breakdown,
      monthlyBreakdown: monthlyBreakdown,
      teacherBreakdown: data.teacherBreakdown,
      dailyBreakdown: dailyBreakdown,
      events: data.events,
    );
  }

  StudentPointReportsData _buildFallbackData(List<StudentGroupSummary> groups) {
    final visibleGroups = groups.toList();
    final totalPoints = visibleGroups.fold<int>(
      0,
      (sum, group) => sum + group.monthlyPoints,
    );
    final monthKey = _currentMonthKey();
    final totalEvents = visibleGroups.fold<int>(
      0,
      (sum, group) => sum + (group.monthlyPoints > 0 ? 1 : 0),
    );

    return StudentPointReportsData(
      month: monthKey,
      summary: StudentPointSummary(
        totalPoints: totalPoints,
        totalEvents: totalEvents,
        attendanceEvents: 0,
        manualEvents: totalEvents,
      ),
      breakdown: visibleGroups
          .map(
            (group) => StudentPointBreakdown(
              groupId: group.groupId,
              groupName: group.groupName,
              totalPoints: group.monthlyPoints,
              totalEvents: group.monthlyPoints > 0 ? 1 : 0,
            ),
          )
          .toList(),
      monthlyBreakdown: [
        StudentPointMonthlyBreakdown(
          monthName: monthKey,
          totalPoints: totalPoints,
          totalEvents: totalEvents,
        ),
      ],
      teacherBreakdown: visibleGroups
          .map(
            (group) => StudentPointTeacherBreakdown(
              monthName: monthKey,
              teacherId: null,
              teacherName: group.teacherName,
              totalPoints: group.monthlyPoints,
              totalEvents: group.monthlyPoints > 0 ? 1 : 0,
            ),
          )
          .toList(),
      dailyBreakdown: const <StudentPointDailyBreakdown>[],
      events: const <StudentPointEvent>[],
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Oylik ballar'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: AppTheme.brandColor,
        child: FutureBuilder<StudentPointReportsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: const [
                  _LoadingCard(height: 150),
                  SizedBox(height: 12),
                  _LoadingCard(height: 220),
                ],
              );
            }

            final error = snapshot.error;
            final data = snapshot.data;
            if (error != null || data == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  _ErrorCard(
                    message: error is StudentGroupsException
                        ? error.message
                        : 'Ballar yuklanmadi',
                    onRetry: _reload,
                  ),
                ],
              );
            }

            final currentMonthKey = _currentMonthKey();
            final currentMonthPoints = _pointsForMonth(data, currentMonthKey);
            final months = data.monthlyBreakdown;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _OverviewHero(
                  title: 'Umumiy ball',
                  currentMonthLabel: _monthLabel(currentMonthKey),
                  currentMonthPoints: currentMonthPoints,
                  totalPoints: data.summary.totalPoints,
                  sinceLabel: _sinceLabel(data.summary.firstEventDate),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: Color(0xFF182033),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Oylar bo\'yicha',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF182033),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (months.isNotEmpty)
                        Text(
                          '${months.length} oy',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A93A5),
                          ),
                        ),
                    ],
                  ),
                ),
                if (months.isEmpty)
                  const _EmptyCard()
                else
                  for (var i = 0; i < months.length; i++) ...[
                    _MonthCard(
                      month: months[i],
                      teachers: _teachersForMonth(data, months[i].monthName),
                      isCurrent: months[i].monthName == currentMonthKey,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StudentPointReportsPage(
                              session: widget.session,
                              initialMonth: months[i].monthName,
                            ),
                          ),
                        );
                      },
                    ),
                    if (i < months.length - 1) const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  static int _pointsForMonth(StudentPointReportsData data, String monthKey) {
    for (final month in data.monthlyBreakdown) {
      if (month.monthName == monthKey) return month.totalPoints;
    }
    return 0;
  }

  static List<StudentPointTeacherBreakdown> _teachersForMonth(
    StudentPointReportsData data,
    String monthKey,
  ) {
    final list = data.teacherBreakdown
        .where((teacher) => teacher.monthName == monthKey)
        .toList();
    list.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    return list;
  }

  static String _sinceLabel(String? firstEventDate) {
    final parsed = _parseIsoDate(firstEventDate);
    if (parsed == null) return 'O\'qishni boshlaganingizdan beri';
    return '${_fullDateLabel(parsed)} dan beri';
  }

  static String _eventMonthKey(StudentPointEvent event) {
    final month = event.monthName.trim();
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) return month;

    final dayDate = _parseIsoDate(event.dayKey);
    if (dayDate != null) {
      return '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}';
    }

    final createdDate = _parseIsoDate(event.createdAt);
    if (createdDate != null) {
      return '${createdDate.year}-${createdDate.month.toString().padLeft(2, '0')}';
    }

    return _currentMonthKey();
  }
}

class _AggregateBucket {
  _AggregateBucket({
    required this.groupId,
    required this.groupName,
  });

  final int? groupId;
  final String groupName;
  int totalPoints = 0;
  int totalEvents = 0;

  void add(int points) {
    totalPoints += points;
    totalEvents += 1;
  }
}

class _DailyAggregateBucket {
  _DailyAggregateBucket(this.dayKey);

  final String dayKey;
  int totalPoints = 0;
  int totalEvents = 0;
  String firstTime = '';
  String lastTime = '';

  void add(int points, String createdTime) {
    totalPoints += points;
    totalEvents += 1;
    if (firstTime.isEmpty || createdTime.compareTo(firstTime) < 0) {
      firstTime = createdTime;
    }
    if (lastTime.isEmpty || createdTime.compareTo(lastTime) > 0) {
      lastTime = createdTime;
    }
  }
}

/// Ikkita katta ko'rsatkichli hero: joriy oy va umumiy ball
class _OverviewHero extends StatelessWidget {
  const _OverviewHero({
    required this.title,
    required this.currentMonthLabel,
    required this.currentMonthPoints,
    required this.totalPoints,
    required this.sinceLabel,
  });

  final String title;
  final String currentMonthLabel;
  final int currentMonthPoints;
  final int totalPoints;
  final String sinceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C0A05), Color(0xFFA70E07), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33A70E07),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _HeroStat(
                    label: currentMonthLabel,
                    caption: 'Joriy oy ballari',
                    value: currentMonthPoints,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                Expanded(
                  child: _HeroStat(
                    label: sinceLabel,
                    caption: 'Barcha vaqt',
                    value: totalPoints,
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.caption,
    required this.value,
  });

  final String label;
  final String caption;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Text(
                'ball',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// Bitta oy kartasi: jami ball + o'sha oyda ball qo'ygan teacherlar ro'yxati
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.teachers,
    required this.isCurrent,
    required this.onTap,
  });

  final StudentPointMonthlyBreakdown month;
  final List<StudentPointTeacherBreakdown> teachers;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final positive = month.totalPoints >= 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF7C0A05), Color(0xFFA70E07), Color(0xFFD32F2F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isCurrent ? 0.55 : 0.14),
              width: isCurrent ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandColor.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _monthShort(month.monthName),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _monthLabel(month.monthName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'Joriy oy',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${month.totalEvents} ta yozuv',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.80),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      positive
                          ? '+${month.totalPoints} ball'
                          : '${month.totalPoints} ball',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (teachers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.20)),
                const SizedBox(height: 10),
                for (var i = 0; i < teachers.length; i++) ...[
                  _TeacherRow(teacher: teachers[i]),
                  if (i < teachers.length - 1) const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bitta teacher qatori: ism + o'sha oyda qo'ygan balli
class _TeacherRow extends StatelessWidget {
  const _TeacherRow({required this.teacher});

  final StudentPointTeacherBreakdown teacher;

  @override
  Widget build(BuildContext context) {
    final name = teacher.teacherName.trim().isEmpty
        ? 'Noma\'lum'
        : teacher.teacherName.trim();
    final positive = teacher.totalPoints >= 0;

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 15,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'O\'qituvchi',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          positive ? '+${teacher.totalPoints}' : '${teacher.totalPoints}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          'ball',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
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
        'Hozircha ball tarixi yo\'q',
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

const List<String> _monthNames = [
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

const List<String> _monthShortNames = [
  'Yan',
  'Fev',
  'Mar',
  'Apr',
  'May',
  'Iyn',
  'Iyl',
  'Avg',
  'Sen',
  'Okt',
  'Noy',
  'Dek',
];

String _currentMonthKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

String _monthLabel(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return monthKey;
  final name = _monthNames[month - 1];
  return '${name[0].toUpperCase()}${name.substring(1)} $year';
}

String _monthShort(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return monthKey;
  return _monthShortNames[month - 1];
}

DateTime? _parseIsoDate(String? value) {
  final text = value?.trim() ?? '';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12) return null;
  return DateTime(year, month, day);
}

String _fullDateLabel(DateTime date) {
  return '${date.day}-${_monthNames[date.month - 1]} ${date.year}';
}
