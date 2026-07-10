import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/student_groups_service.dart';

class StudentPointReportsPage extends StatefulWidget {
  const StudentPointReportsPage({
    super.key,
    required this.session,
    this.initialGroupId,
  });

  final AuthSession session;
  final int? initialGroupId;

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
    _selectedMonth = _currentMonthKey();
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

  void _selectGroup(int groupId) {
    if (_selectedGroupId == groupId) return;
    setState(() {
      _selectedGroupId = groupId;
      _reportsFuture = _service.fetchMyPointReports(
        widget.session,
        month: _selectedMonth,
        groupId: _selectedGroupId,
      );
    });
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MonthHeader(monthLabel: _monthLabel(_selectedMonth)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final group in groups)
                          ChoiceChip(
                            label: Text(group.groupName),
                            selected: group.groupId == _selectedGroupId,
                            onSelected: (_) => _selectGroup(group.groupId),
                          ),
                      ],
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
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Joriy oy hisobotlari',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            monthLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              label: 'Jami ball',
              value: '${report.summary.totalPoints}',
              color: const Color(0xFF6D4DF6),
            ),
          ),
          Expanded(
            child: _MiniStat(
              label: 'Davomat',
              value: '${report.summary.attendanceEvents}',
              color: const Color(0xFF0F766E),
            ),
          ),
          Expanded(
            child: _MiniStat(
              label: 'Qo‘shimcha',
              value: '${report.summary.manualEvents}',
              color: const Color(0xFFDB2777),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kunlik statistika',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF182033),
            ),
          ),
          const SizedBox(height: 10),
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
            for (final day in dailyBreakdown) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: day.dayKey == todayKey
                          ? const Color(0xFFECFDF3)
                          : const Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      day.dayKey == todayKey ? 'Bugun' : _dayShortLabel(day.dayKey),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: day.dayKey == todayKey ? 10.5 : 11,
                        fontWeight: FontWeight.w800,
                        color: day.dayKey == todayKey
                            ? const Color(0xFF0F766E)
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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF182033),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          day.dayKey == todayKey
                              ? 'Bugun ${day.totalPoints} ball oldi'
                              : '${day.totalPoints} ball oldi',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${day.totalPoints} ball',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7B8495),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guruhlar bo‘yicha',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF182033),
            ),
          ),
          const SizedBox(height: 10),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF182033),
                      ),
                    ),
                  ),
                  Text(
                    '${item.totalPoints} ball',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6D4DF6),
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
          const Text(
            'So‘nggi yozuvlar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF182033),
            ),
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            const Text(
              'Hozircha yozuv yo‘q',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7B8495),
              ),
            )
          else
            for (final event in events) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: event.points >= 0
                          ? const Color(0xFFEAF0FF)
                          : const Color(0xFFFFE4E6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      event.points >= 0 ? '+${event.points}' : '${event.points}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: event.points >= 0
                            ? const Color(0xFF4C63D2)
                            : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF182033),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (event.groupName.isNotEmpty) event.groupName,
                            if (event.description.isNotEmpty) event.description,
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.dayKey == _todayKey()
                              ? 'Bugun, ${event.createdTime}'
                              : '${_formatDayKey(event.dayKey)} • ${event.createdTime}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A93A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
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
