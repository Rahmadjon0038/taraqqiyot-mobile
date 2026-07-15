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
  State<StudentPointReportsPage> createState() => _StudentPointReportsPageState();
}

class _StudentPointReportsPageState extends State<StudentPointReportsPage> {
  final StudentGroupsService _service = StudentGroupsService();
  late Future<List<StudentGroupSummary>> _groupsFuture;
  Future<StudentPointReportsData>? _reportsFuture;
  int? _selectedGroupId;
  late String _selectedMonth;

  @override
  void initState() {
    super.initState();
    final initialMonth = widget.initialMonth?.trim();
    _selectedMonth =
        (initialMonth != null && RegExp(r'^\d{4}-\d{2}$').hasMatch(initialMonth))
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
      });
      return;
    }
    final selected = groups.any((group) => group.groupId == _selectedGroupId)
        ? _selectedGroupId
        : groups.first.groupId;
    setState(() {
      _selectedGroupId = selected;
      _reportsFuture = _service.fetchMyPointReports(
        widget.session,
        month: _selectedMonth,
        groupId: _selectedGroupId,
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
        });
        return;
      }
      final initialGroup = widget.initialGroupId;
      final selected = groups.any((group) => group.groupId == initialGroup)
          ? initialGroup
          : groups.first.groupId;
      setState(() {
        _selectedGroupId = selected;
        _reportsFuture = _service.fetchMyPointReports(
          widget.session,
          month: _selectedMonth,
          groupId: _selectedGroupId,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reportsFuture = null;
      });
    }
  }

  void _selectGroup(StudentGroupSummary group) {
    if (_selectedGroupId == group.groupId) return;
    setState(() {
      _selectedGroupId = group.groupId;
      // Yangi guruhning oylar oralig'iga sig'masa joriy oyga qaytamiz
      if (!_monthOptionsFor(group).contains(_selectedMonth)) {
        _selectedMonth = _currentMonthKey();
      }
      _reportsFuture = _service.fetchMyPointReports(
        widget.session,
        month: _selectedMonth,
        groupId: _selectedGroupId,
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
      }
    });
  }

  /// Tanlangan guruhda o'qish boshlangan oydan joriy oygacha (joriy oy
  /// birinchi). Boshlanish sanasi topilmasa faqat joriy oy chiqadi.
  List<String> _monthOptionsFor(StudentGroupSummary? group) {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    final startDate =
        _parseDdMmYyyy(group?.startDate ?? '') ??
        _parseDdMmYyyy(group?.myJoinDate ?? '');
    var start = startDate == null
        ? current
        : DateTime(startDate.year, startDate.month);
    if (start.isAfter(current)) start = current;

    final months = <String>[];
    var cursor = current;
    while (!cursor.isBefore(start) && months.length < 24) {
      months.add('${cursor.year}-${cursor.month.toString().padLeft(2, '0')}');
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    return months;
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
                                borderRadius: BorderRadius.circular(999),
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
                                borderRadius: BorderRadius.circular(999),
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
                          if (reportSnapshot.connectionState == ConnectionState.waiting) {
                            return const _LoadingCard(height: 220);
                          }
                          if (reportError != null || report == null) {
                            return _ErrorCard(
                              message: _readErrorMessage(reportError),
                              onRetry: _reload,
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SummaryCard(report: report),
                              const SizedBox(height: 12),
                              _DailyStatsCard(dailyBreakdown: report.dailyBreakdown),
                              const SizedBox(height: 12),
                              _BreakdownCard(breakdown: report.breakdown),
                              const SizedBox(height: 12),
                              _EventsCard(events: report.events),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});

  final StudentPointReportsData report;

  @override
  Widget build(BuildContext context) {
    // Ball yig'indilari manba bo'yicha: davomat uchun avtomatik berilgan
    // balllar va teacher qo'lda qo'ygan qo'shimcha balllar
    var attendancePoints = 0;
    var manualPoints = 0;
    for (final event in report.events) {
      if (event.sourceType == 'attendance') {
        attendancePoints += event.points;
      } else {
        manualPoints += event.points;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Row(
        children: [
          _MiniStat(
            icon: Icons.star_rounded,
            label: 'Jami ball',
            value: '${report.summary.totalPoints}',
            color: AppTheme.brandColor,
          ),
          const _MiniStatDivider(),
          _MiniStat(
            icon: Icons.how_to_reg_rounded,
            label: 'Davomat balli',
            value: '$attendancePoints',
            color: const Color(0xFF0F766E),
          ),
          const _MiniStatDivider(),
          _MiniStat(
            icon: Icons.auto_awesome_rounded,
            label: 'Qo\'shimcha ball',
            value: '$manualPoints',
            color: const Color(0xFFD4A017),
          ),
        ],
      ),
    );
  }
}

class _MiniStatDivider extends StatelessWidget {
  const _MiniStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFE4E9F1),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.calendar_month_rounded,
            title: 'Dars kunlari bo\'yicha',
          ),
          const SizedBox(height: 12),
          if (dailyBreakdown.isEmpty)
            const Text(
              'Hozircha kunlik ma\'lumot yo\'q',
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
                          borderRadius: BorderRadius.circular(13),
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
                              '${day.totalEvents} ta yozuv',
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
                          borderRadius: BorderRadius.circular(999),
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
            borderRadius: BorderRadius.circular(10),
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            textAlign: TextAlign.center,
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

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.breakdown});

  final List<StudentPointBreakdown> breakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                      borderRadius: BorderRadius.circular(999),
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

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events});

  final List<StudentPointEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.history_rounded,
            title: 'So\'nggi yozuvlar',
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const Text(
              'Hozircha yozuv yo\'q',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7B8495),
              ),
            )
          else
            for (var i = 0; i < events.length; i++) ...[
              _EventRow(event: events[i]),
              if (i < events.length - 1) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFEDF1F7)),
                const SizedBox(height: 10),
              ],
            ],
        ],
      ),
    );
  }
}

/// Bitta ball yozuvi: ball belgisi, sarlavha, teacher izohi va vaqt
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final StudentPointEvent event;

  @override
  Widget build(BuildContext context) {
    final positive = event.points >= 0;
    final color = positive ? const Color(0xFF16934F) : const Color(0xFFDC2626);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            positive ? '+${event.points}' : '${event.points}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF182033),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    event.dayKey == _todayKey()
                        ? 'Bugun, ${event.createdTime}'
                        : '${_dayShortLabel(event.dayKey)}-kun, ${event.createdTime}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A93A5),
                    ),
                  ),
                ],
              ),
              if (event.groupName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  event.groupName,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A93A5),
                  ),
                ),
              ],
              // Teacher yozgan izoh — alohida ajralib turadigan blok
              if (event.description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FB),
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(
                      left: BorderSide(color: Color(0xFFA70E07), width: 3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 13,
                        color: Color(0xFF7B8495),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.description.trim(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3A4454),
                            height: 1.35,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: const CircularProgressIndicator(color: AppTheme.brandColor),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.circular(18),
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
  final monthName = month >= 1 && month <= months.length ? months[month - 1] : monthKey;
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
