import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../student/data/student_groups_service.dart';

/// Oylik ballar kartasi — tanlangan fan/guruh bo'yicha studentning
/// jamlangan ballari line chart'da ko'rsatiladi. Har bir nuqta o'sha kunning
/// jami ballini bildiradi. Bir nechta fan bo'lsa, chiplar orqali fan tanlanadi.
class HomeMonthlyProgressChart extends StatefulWidget {
  const HomeMonthlyProgressChart({
    super.key,
    required this.groups,
    required this.loadReports,
    this.onTapGroup,
  });

  final List<StudentGroupSummary> groups;

  /// Tanlangan guruh (fan) uchun ball hisobotini yuklaydi.
  /// groupId null bo'lsa — barcha fanlar bo'yicha umumiy.
  final Future<StudentPointReportsData> Function(int? groupId) loadReports;

  final ValueChanged<StudentGroupSummary?>? onTapGroup;

  @override
  State<HomeMonthlyProgressChart> createState() =>
      _HomeMonthlyProgressChartState();
}

class _HomeMonthlyProgressChartState extends State<HomeMonthlyProgressChart> {
  static const _indigo = Color(0xFFA70E07);
  static const _indigoLight = Color(0xFFDC2626);

  int? _selectedGroupId;

  /// Fan almashtirilganda qayta so'rov ketmasligi uchun kesh
  final Map<int?, Future<StudentPointReportsData>> _reportsCache = {};

  @override
  void initState() {
    super.initState();
    _selectedGroupId =
        _displayGroups.isNotEmpty ? _displayGroups.first.groupId : null;
  }

  @override
  void didUpdateWidget(covariant HomeMonthlyProgressChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Guruhlar keyin yuklanib kelsa, birinchi fanni tanlaymiz
    final ids = _displayGroups.map((g) => g.groupId).toSet();
    if (_selectedGroupId == null || !ids.contains(_selectedGroupId)) {
      _selectedGroupId =
          _displayGroups.isNotEmpty ? _displayGroups.first.groupId : null;
    }
  }

  List<StudentGroupSummary> get _displayGroups {
    if (widget.groups.isEmpty) return const [];

    final bySubject = <String, StudentGroupSummary>{};
    for (final group in widget.groups) {
      final key = group.subjectName.trim().isNotEmpty
          ? group.subjectName.trim().toLowerCase()
          : 'group-${group.groupId}';
      final existing = bySubject[key];
      if (existing == null) {
        bySubject[key] = group;
        continue;
      }

      final preferNext = _preferGroup(existing, group);
      if (preferNext) {
        bySubject[key] = group;
      }
    }

    return bySubject.values.toList();
  }

  bool _preferGroup(StudentGroupSummary current, StudentGroupSummary next) {
    if (current.isActive != next.isActive) {
      return next.isActive;
    }

    final currentJoin = DateTime.tryParse(current.myJoinDate);
    final nextJoin = DateTime.tryParse(next.myJoinDate);
    if (currentJoin != null && nextJoin != null && currentJoin != nextJoin) {
      return nextJoin.isAfter(currentJoin);
    }

    final currentCreated = DateTime.tryParse(current.createdDate);
    final nextCreated = DateTime.tryParse(next.createdDate);
    if (currentCreated != null &&
        nextCreated != null &&
        currentCreated != nextCreated) {
      return nextCreated.isAfter(currentCreated);
    }

    return false;
  }

  Future<StudentPointReportsData> _reportsFor(int? groupId) {
    return _reportsCache.putIfAbsent(
      groupId,
      () => widget.loadReports(groupId),
    );
  }

  StudentGroupSummary? get _selectedGroup {
    for (final group in _displayGroups) {
      if (group.groupId == _selectedGroupId) return group;
    }
    return null;
  }

  /// Oxirgi ball olingan kundan orqaga qarab ketma-ket kunlarni sanaydi
  static int _streak(List<StudentPointDailyBreakdown> daily) {
    final days = daily
        .where((d) => d.totalPoints > 0)
        .map((d) => DateTime.tryParse(d.dayKey))
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort();
    if (days.isEmpty) return 0;
    var streak = 1;
    for (var i = days.length - 1; i > 0; i--) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Har bir report kuni uchun nuqta: oy boshidan bugungacha
  /// report yuborilgan kunlar. Ballar bo'lmasa chart bo'sh qoladi.
  List<FlSpot> _dailySpots(List<StudentPointDailyBreakdown> daily) {
    final now = DateTime.now();

    // Ball olingan kunlar: kun -> jami ball (faqat joriy oy)
    final pointsByDay = <int, int>{};
    for (final d in daily) {
      final date = DateTime.tryParse(d.dayKey);
      if (date == null || date.year != now.year || date.month != now.month) {
        continue;
      }
      pointsByDay[date.day] = (pointsByDay[date.day] ?? 0) + d.totalPoints;
    }

    final sortedDays = pointsByDay.keys.toList()..sort();
    return [
      for (final day in sortedDays)
        FlSpot(day.toDouble(), (pointsByDay[day] ?? 0).toDouble()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E9F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 6),
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
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_indigo, _indigoLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Oylik o\'sish grafigi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF182033),
                        ),
                      ),
                      if (_selectedGroup != null)
                        Text(
                          'Ballar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: _indigo,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_displayGroups.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _displayGroups.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final group = _displayGroups[index];
                    final selected = group.groupId == _selectedGroupId;
                    return _SubjectChip(
                      label: group.subjectName.trim().isNotEmpty
                          ? group.subjectName.trim()
                          : group.groupName,
                      selected: selected,
                      onTap: () {
                        if (!selected) {
                          setState(() => _selectedGroupId = group.groupId);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            FutureBuilder<StudentPointReportsData>(
              future: _reportsFor(_selectedGroupId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _ChartPlaceholder(text: 'Yuklanmoqda...');
                }
                final data = snapshot.data;
                if (snapshot.hasError || data == null) {
                  return const _ChartPlaceholder(text: 'Ma\'lumot yuklanmadi');
                }

                final spots = _dailySpots(data.dailyBreakdown);
                final streak = _streak(data.dailyBreakdown);
                final totalPoints = data.summary.totalPoints;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _indigo.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            '$totalPoints ball',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _indigo,
                            ),
                          ),
                        ),
                        if (streak >= 2) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEA580C,
                              ).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 13,
                                  color: Color(0xFFEA580C),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$streak kun ketma-ket',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Faqat haqiqatan HECH qanday ball bo'lmasa placeholder
                    // ko'rsatamiz — bitta kunlik ball bo'lsa ham (chiziq
                    // chizish uchun 2 nuqta kerak bo'lsa ham) buni "ball
                    // yo'q" deb noto'g'ri ko'rsatmasligimiz kerak, chunki
                    // yuqoridagi chipda ball soni allaqachon ko'rinib turibdi.
                    if (spots.isEmpty)
                      const _ChartPlaceholder(text: 'Bu oyda hali ball yo\'q')
                    else
                      SizedBox(
                        height: 130,
                        child: _ProgressLineChart(spots: spots),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );

    if (widget.onTapGroup == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onTapGroup?.call(_selectedGroup),
        borderRadius: BorderRadius.circular(24),
        child: card,
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _indigo = Color(0xFFA70E07);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _indigo : const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : const Color(0xFF5A6478),
          ),
        ),
      ),
    );
  }
}

class _ProgressLineChart extends StatelessWidget {
  const _ProgressLineChart({required this.spots});

  final List<FlSpot> spots;

  static const _indigo = Color(0xFFA70E07);
  static const _indigoLight = Color(0xFFDC2626);

  static const List<String> _uzMonths = [
    'yanvar',
    'fevral',
    'mart',
    'aprel',
    'may',
    'iyun',
    'iyul',
    'avgust',
    'sentyabr',
    'oktyabr',
    'noyabr',
    'dekabr',
  ];

  @override
  Widget build(BuildContext context) {
    final monthName = _uzMonths[DateTime.now().month - 1];
    // Bitta kunlik ball bo'lsa ham nuqta chapga/o'ngga yopishib
    // qolmasligi uchun X o'qiga sun'iy joy beriladi.
    final minX = spots.length == 1 ? spots.first.x - 1 : spots.first.x;
    final maxX = spots.length == 1 ? spots.first.x + 1 : spots.last.x;
    var maxY = 0.0;
    for (final spot in spots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    // Hamma kun 0 bo'lsa ham chart tekis va chiroyli ko'rinsin
    if (maxY < 5) maxY = 5;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: maxY * 1.18 + 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 3).clamp(1.0, double.infinity),
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: Color(0xFFEDF1F7), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF182033),
            tooltipBorderRadius: BorderRadius.circular(16),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) => touchedSpots
                .map(
                  (spot) => LineTooltipItem(
                    '${spot.x.toInt()}-$monthName • ${spot.y.toInt()} ball',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
            barWidth: 3,
            isStrokeCapRound: true,
            gradient: const LinearGradient(colors: [_indigo, _indigoLight]),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 2.6,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: _indigo,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  _indigo.withValues(alpha: 0.18),
                  _indigoLight.withValues(alpha: 0.02),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8A93A5),
          ),
        ),
      ),
    );
  }
}
