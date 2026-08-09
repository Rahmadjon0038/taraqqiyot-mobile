import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/schedule_format.dart';
import '../../auth/models/auth_session.dart';
import '../data/teacher_service.dart';
import 'teacher_lesson_mark_page.dart';

/// Davomat oqimi: guruh tanlash -> oylik darslar -> dars ichida belgilash.
class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({super.key, required this.session});

  final AuthSession session;

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  final TeacherService _service = TeacherService();
  late Future<List<TeacherGroup>> _groupsFuture;
  Future<List<TeacherLesson>>? _lessonsFuture;
  int? _selectedGroupId;
  late String _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _groupsFuture = _service.fetchMyGroups(widget.session);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _selectGroup(TeacherGroup group) {
    setState(() {
      _selectedGroupId = group.id;
      // Yangi guruhning oylar oralig'iga sig'masa, joriy oyga qaytamiz
      if (!_monthsForGroup(group).contains(_month)) {
        _month = _monthKey(DateTime.now());
      }
      _lessonsFuture = _service.fetchGroupLessons(
        widget.session,
        group.id,
        month: _month,
      );
    });
  }

  void _selectMonth(String month) {
    if (month == _month) return;
    setState(() {
      _month = month;
      final groupId = _selectedGroupId;
      if (groupId != null) {
        _lessonsFuture = _service.fetchGroupLessons(
          widget.session,
          groupId,
          month: month,
        );
      }
    });
  }

  /// Guruhda dars boshlangan oydan joriy oygacha (joriy oy birinchi).
  /// Boshlanish sanasi noma'lum bo'lsa faqat joriy oy ko'rsatiladi.
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
  }

  Future<void> _openLesson(TeacherLesson lesson) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TeacherLessonMarkPage(
          session: widget.session,
          lessonId: lesson.id,
          lessonLabel:
              '${lesson.formattedDate}'
              '${lesson.weekdayName.isEmpty ? '' : ' • ${lesson.weekdayName}'}'
              ' • ${lesson.startTime}-${lesson.endTime}',
        ),
      ),
    );
    if (changed == true) {
      await _reloadLessons();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TeacherGroup>>(
      future: _groupsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.brandColor),
          );
        }
        final groups = snapshot.data ?? const <TeacherGroup>[];
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

        // Birinchi ochilishda birinchi guruhni avtomatik tanlaymiz
        if (_selectedGroupId == null && groups.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedGroupId == null) {
              _selectGroup(groups.first);
            }
          });
        }

        // Tanlangan guruhning oylar ro'yxati (dars boshlangan oydan boshlab)
        TeacherGroup? selectedGroup;
        for (final group in groups) {
          if (group.id == _selectedGroupId) {
            selectedGroup = group;
            break;
          }
        }
        final months = _monthsForGroup(selectedGroup);

        return RefreshIndicator(
          onRefresh: _reloadLessons,
          color: AppTheme.brandColor,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Oy tanlash — o'tgan oylar davomatini ko'rish uchun
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: months.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final month = months[index];
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
              const SizedBox(height: 8),
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
                    final selected = group.id == _selectedGroupId;
                    return GestureDetector(
                      onTap: () {
                        if (!selected) _selectGroup(group);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.brandColor : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? AppTheme.brandColor
                                : const Color(0xFFD6DDEA),
                          ),
                        ),
                        child: Text(
                          group.name,
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
              // Tanlangan guruhning dars kunlari va vaqti
              if (selectedGroup != null &&
                  formatScheduleLabel(
                    selectedGroup.scheduleDays,
                    selectedGroup.scheduleTime,
                  ).isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        formatScheduleLabel(
                          selectedGroup.scheduleDays,
                          selectedGroup.scheduleTime,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              if (_lessonsFuture != null)
                FutureBuilder<List<TeacherLesson>>(
                  future: _lessonsFuture,
                  builder: (context, lessonSnapshot) {
                    if (lessonSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.brandColor,
                          ),
                        ),
                      );
                    }
                    final lessons =
                        lessonSnapshot.data ?? const <TeacherLesson>[];
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
                    // Oy boshi tepada, oy oxiri pastda
                    final sorted = [...lessons]
                      ..sort((a, b) {
                        final byDate = a.date.compareTo(b.date);
                        if (byDate != 0) return byDate;
                        return a.startTime.compareTo(b.startTime);
                      });
                    return Column(
                      children: [
                        for (final lesson in sorted) ...[
                          _LessonCard(
                            lesson: lesson,
                            onTap: () => _openLesson(lesson),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.onTap});

  final TeacherLesson lesson;
  final VoidCallback onTap;

  static (Color, String, IconData) _stateInfo(String state) {
    switch (state) {
      case 'completed':
        return (
          const Color(0xFF16934F),
          'Yakunlangan',
          Icons.check_circle_rounded,
        );
      case 'marked':
        return (const Color(0xFF2563EB), 'Belgilangan', Icons.task_alt_rounded);
      case 'partial':
        return (
          const Color(0xFFB45309),
          'Qisman',
          Icons.hourglass_bottom_rounded,
        );
      default:
        return (
          const Color(0xFF8A93A5),
          'Belgilanmagan',
          Icons.radio_button_unchecked_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (stateColor, stateLabel, stateIcon) = _stateInfo(
      lesson.attendanceState,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E9F1)),
          ),
          child: Row(
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
                      lesson.weekdayName.isEmpty
                          ? lesson.formattedDate
                          : '${lesson.formattedDate} • ${lesson.weekdayName}',
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
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF9AA2B2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
