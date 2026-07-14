import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../../profile/presentation/widgets/profile_avatar.dart';
import '../data/teacher_service.dart';

/// Guruh kattaligiga qarab nechta "eng yaxshi" o'quvchi ko'rsatilishi:
/// 3 tagacha o'quvchi -> 1 ta, 4-5 ta -> 2 ta, undan ko'p -> 3 ta.
int topCountForGroupSize(int totalStudents) {
  if (totalStudents <= 3) return 1;
  if (totalStudents <= 5) return 2;
  return 3;
}

/// Bitta guruhning tanlangan oydagi eng yaxshi o'quvchilari
class GroupTopStudents {
  const GroupTopStudents({
    required this.groupId,
    required this.groupName,
    required this.activeStudentsCount,
    required this.students,
  });

  final int groupId;
  final String groupName;
  final int activeStudentsCount;
  final List<TopStudentEntry> students;
}

class TopStudentEntry {
  const TopStudentEntry({
    required this.name,
    required this.groupName,
    required this.points,
    required this.avatarKey,
    required this.avatarUrl,
  });

  final String name;
  final String groupName;
  final int points;
  final String avatarKey;
  final String avatarUrl;
}

/// Guruh tafsilotidan guruh kattaligi qoidasi bo'yicha eng yaxshilarni ajratadi
GroupTopStudents buildGroupTop(TeacherGroupDetail detail) {
  final active = detail.students.where((s) => s.isActive).toList();
  final take = topCountForGroupSize(active.length);
  final scored = active.where((s) => s.monthlyPoints > 0).toList()
    ..sort((a, b) => b.monthlyPoints.compareTo(a.monthlyPoints));
  return GroupTopStudents(
    groupId: detail.groupId,
    groupName: detail.groupName,
    activeStudentsCount: active.length,
    students: [
      for (final student in scored.take(take))
        TopStudentEntry(
          name: student.fullName,
          groupName: detail.groupName,
          points: student.monthlyPoints,
          avatarKey: student.avatarKey,
          avatarUrl: student.avatarUrl,
        ),
    ],
  );
}

/// Barcha guruhlar bo'yicha tanlangan oyning eng yaxshi o'quvchilari,
/// oy bo'yicha filter bilan.
class TeacherTopStudentsPage extends StatefulWidget {
  const TeacherTopStudentsPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<TeacherTopStudentsPage> createState() => _TeacherTopStudentsPageState();
}

class _TeacherTopStudentsPageState extends State<TeacherTopStudentsPage> {
  final TeacherService _service = TeacherService();
  Future<List<GroupTopStudents>>? _topsFuture;
  List<TeacherGroup> _groups = const [];
  List<String> _months = const [];
  late String _month;

  @override
  void initState() {
    super.initState();
    _month = _monthKey(DateTime.now());
    _months = [_month];
    _topsFuture = _loadInitial();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  static String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  static String _formatMonthLabel(String monthKey) {
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

  /// Eng erta guruh boshlangan oydan joriy oygacha (joriy oy birinchi)
  List<String> _buildMonths(List<TeacherGroup> groups) {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    DateTime? earliest;
    for (final group in groups) {
      final start = group.classStartMonth;
      if (start == null) continue;
      if (earliest == null || start.isBefore(earliest)) {
        earliest = start;
      }
    }
    if (earliest == null || earliest.isAfter(current)) {
      return [_monthKey(current)];
    }
    final months = <String>[];
    var cursor = current;
    while (!cursor.isBefore(earliest) && months.length < 24) {
      months.add(_monthKey(cursor));
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    return months;
  }

  Future<List<GroupTopStudents>> _loadInitial() async {
    _groups = await _service.fetchMyGroups(widget.session);
    final months = _buildMonths(_groups);
    if (mounted) {
      setState(() => _months = months);
    } else {
      _months = months;
    }
    return _loadTops(_month);
  }

  Future<List<GroupTopStudents>> _loadTops(String month) async {
    final details = await Future.wait(
      _groups.map(
        (group) => _service
            .fetchGroupDetail(widget.session, group.id, month: month)
            .then<TeacherGroupDetail?>((detail) => detail)
            .catchError((_) => null),
      ),
    );
    return [
      for (final detail in details)
        if (detail != null) buildGroupTop(detail),
    ];
  }

  void _selectMonth(String month) {
    if (month == _month) return;
    setState(() {
      _month = month;
      _topsFuture = _loadTops(month);
    });
  }

  Future<void> _reload() async {
    setState(() {
      _topsFuture = _groups.isEmpty ? _loadInitial() : _loadTops(_month);
    });
    await _topsFuture;
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
          'Eng yaxshi o\'quvchilar',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF182033),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: AppTheme.brandColor,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Oy tanlash chiplari
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
            const SizedBox(height: 14),
            FutureBuilder<List<GroupTopStudents>>(
              future: _topsFuture,
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
                final tops = snapshot.data ?? const <GroupTopStudents>[];
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'Ma\'lumotlar yuklanmadi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }
                if (tops.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        'Guruhlar topilmadi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final groupTop in tops) ...[
                      _GroupTopCard(groupTop: groupTop),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Bitta guruh kartasi: nomi + eng yaxshi o'quvchilar (medal bilan)
class _GroupTopCard extends StatelessWidget {
  const _GroupTopCard({required this.groupTop});

  final GroupTopStudents groupTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text(
                  groupTop.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              Text(
                '${groupTop.activeStudentsCount} o\'quvchi',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7B8495),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (groupTop.students.isEmpty)
            const Text(
              'Bu oyda ball qo\'yilmagan',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9AA2B2),
              ),
            )
          else
            for (var i = 0; i < groupTop.students.length; i++) ...[
              TopStudentRow(student: groupTop.students[i], rank: i),
              if (i < groupTop.students.length - 1) ...[
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

/// Medal + avatar + ism + ball qatori (dashboard kartada ham ishlatiladi)
class TopStudentRow extends StatelessWidget {
  const TopStudentRow({
    super.key,
    required this.student,
    required this.rank,
    this.showGroupName = false,
  });

  final TopStudentEntry student;

  /// 0 - oltin, 1 - kumush, 2 - bronza
  final int rank;
  final bool showGroupName;

  static const _medalColors = [
    Color(0xFFD4A017), // oltin
    Color(0xFF8E9AAB), // kumush
    Color(0xFFB4691E), // bronza
  ];

  @override
  Widget build(BuildContext context) {
    final color = _medalColors[rank.clamp(0, _medalColors.length - 1)];

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.72)],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.emoji_events_rounded,
            size: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        ProfileAvatar(
          avatarKey: student.avatarKey,
          avatarUrl: student.avatarUrl,
          role: 'student',
          seed: student.name,
          size: 34,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (showGroupName)
                Text(
                  student.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B8495),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${student.points} ball',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
