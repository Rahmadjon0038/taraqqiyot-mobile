import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/schedule_format.dart';
import '../../auth/models/auth_session.dart';
import '../data/student_attendance_service.dart';
import '../data/student_groups_service.dart';

String _monthKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

String _currentMonthKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}

DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

DateTime? _parseMonthKey(String key) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key.trim());
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return DateTime(year, month, 1);
}

DateTime? _parseMonthFromDateText(String text) {
  final value = text.trim();
  if (value.isEmpty) return null;

  final iso = DateTime.tryParse(value);
  if (iso != null) {
    return DateTime(iso.year, iso.month, 1);
  }

  final match = RegExp(r'^(\d{2})[./](\d{2})[./](\d{4})$').firstMatch(value);
  if (match != null) {
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (month != null && year != null) {
      return DateTime(year, month, 1);
    }
  }

  return null;
}

List<String> _monthsDescending({
  required String startMonthKey,
  String? endMonthKey,
}) {
  final start = _parseMonthKey(startMonthKey);
  final end = _parseMonthKey(endMonthKey ?? _currentMonthKey());
  if (start == null || end == null) {
    return <String>[_currentMonthKey()];
  }

  final startMonth = _monthStart(start);
  final endMonth = _monthStart(end);
  if (endMonth.isBefore(startMonth)) {
    return <String>[_monthKey(endMonth)];
  }

  final months = <String>[];
  var cursor = endMonth;
  while (!cursor.isBefore(startMonth)) {
    months.add(_monthKey(cursor));
    cursor = DateTime(cursor.year, cursor.month - 1, 1);
  }
  return months;
}

String _clampMonthKey(String monthKey, String? minMonthKey) {
  final selected = _parseMonthKey(monthKey);
  final minMonth = minMonthKey == null ? null : _parseMonthKey(minMonthKey);
  if (selected == null) return minMonthKey ?? _currentMonthKey();
  if (minMonth != null && selected.isBefore(minMonth)) {
    return _monthKey(minMonth);
  }
  return _monthKey(selected);
}

class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({super.key, required this.session});

  final AuthSession session;

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  final StudentGroupsService _groupsService = StudentGroupsService();
  final StudentAttendanceService _attendanceService =
      StudentAttendanceService();

  List<StudentGroupSummary> _groups = const [];
  bool _loading = true;
  String? _errorText;
  late String _selectedMonth;
  int? _selectedGroupId;
  Future<StudentAttendanceDetail>? _selectedDetailFuture;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _currentMonthKey();
    _load();
  }

  @override
  void dispose() {
    _groupsService.dispose();
    _attendanceService.dispose();
    super.dispose();
  }

  /// Berilgan oyda talaba a'zo bo'lgan guruhlar.
  /// Joriy oy uchun — haqiqatan HOZIR faol (myStatus == active) guruhlar,
  /// chunki guruhdan chiqarilganda ba'zan left_at sanasi qo'yilmay
  /// qolishi mumkin — shunda faqat sanaga (availableMonths) qarab
  /// filtrlash yetarli emas.
  /// O'tgan oylar uchun — availableMonths (tarix) asosida, hozirgi
  /// holatidan qat'iy nazar, chunki o'sha paytda a'zo bo'lgan.
  List<StudentGroupSummary> _groupsForMonth(String month) {
    final isCurrentMonth = month == _currentMonthKey();
    return _groups.where((group) {
      if (!group.availableMonths.contains(month)) return false;
      if (isCurrentMonth) return group.isActive;
      return true;
    }).toList();
  }

  StudentGroupSummary? _preferredGroupFor(String month, {int? preferredId}) {
    final visible = _groupsForMonth(month);
    final pool = visible.isNotEmpty ? visible : _groups;
    if (pool.isEmpty) return null;
    if (preferredId != null) {
      for (final group in pool) {
        if (group.groupId == preferredId) return group;
      }
    }
    return pool.first;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final groups = await _groupsService.fetchMyGroups(widget.session);
      _groups = groups;
      if (_groups.isNotEmpty) {
        final preferred = _preferredGroupFor(
          _selectedMonth,
          preferredId: _selectedGroupId,
        );
        _selectedGroupId = preferred?.groupId;
        _selectedMonth = _clampMonthKey(
          _selectedMonth,
          _groupStartMonthKey(_selectedGroupId),
        );
        _refreshSelectedDetail();
      } else {
        _selectedGroupId = null;
        _selectedDetailFuture = null;
      }
    } catch (error) {
      _errorText = _readErrorMessage(error);
      _groups = const [];
      _selectedGroupId = null;
      _selectedDetailFuture = null;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    await _load();
  }

  void _refreshSelectedDetail() {
    final groupId = _selectedGroupId;
    if (groupId == null) {
      _selectedDetailFuture = null;
      return;
    }

    _selectedDetailFuture = _attendanceService.fetchAttendanceDetail(
      widget.session,
      groupId: groupId,
      month: _selectedMonth,
      studentId: widget.session.user.id,
    );
  }

  StudentGroupSummary? _groupById(int? groupId) {
    if (groupId == null) return null;
    for (final group in _groups) {
      if (group.groupId == groupId) {
        return group;
      }
    }
    return null;
  }

  String _groupStartMonthKey(int? groupId) {
    final group = _groupById(groupId);
    if (group?.availableMonths.isNotEmpty == true) {
      return group!.availableMonths.last;
    }
    final parsed =
        group == null ? null : _parseMonthFromDateText(group.myJoinDate);
    return parsed == null ? _currentMonthKey() : _monthKey(parsed);
  }

  List<String> _availableMonthsForGroup(StudentGroupSummary? group) {
    if (group == null) {
      return <String>[_currentMonthKey()];
    }
    if (group.availableMonths.isNotEmpty) {
      return group.availableMonths;
    }
    return _monthsDescending(startMonthKey: _groupStartMonthKey(group.groupId));
  }

  void _selectGroup(int groupId) {
    if (_selectedGroupId == groupId) return;
    setState(() {
      _selectedGroupId = groupId;
      _selectedMonth = _clampMonthKey(
        _selectedMonth,
        _groupStartMonthKey(groupId),
      );
      _refreshSelectedDetail();
    });
  }

  void _selectMonth(String month) {
    if (_selectedMonth == month) return;
    final group = _groupById(_selectedGroupId);
    final minMonthKey =
        group == null ? null : _groupStartMonthKey(group.groupId);
    final selected = _parseMonthKey(month);
    final minMonth = minMonthKey == null ? null : _parseMonthKey(minMonthKey);
    if (selected != null && minMonth != null && selected.isBefore(minMonth)) {
      return;
    }
    setState(() {
      _selectedMonth = month;
      // Tanlangan guruh shu oyda mavjud bo'lmasa (masalan guruhdan
      // chiqib ketgan bo'lsa-yu, boshqa oyga o'tilsa), shu oyda mavjud
      // birinchi guruhga almashtiramiz.
      final visible = _groupsForMonth(_selectedMonth);
      if (visible.isNotEmpty &&
          !visible.any((group) => group.groupId == _selectedGroupId)) {
        _selectedGroupId = visible.first.groupId;
      }
      _refreshSelectedDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = _groupById(_selectedGroupId);
    final months = _availableMonthsForGroup(selectedGroup);
    // Tanlangan oyda mavjud guruhlar — joriy oy uchun bu "hozir
    // o'qiyotgan" guruhlar bilan bir xil, o'tgan oy uchun esa o'sha
    // paytdagi tarix saqlanib qoladi.
    final visibleGroups = _groupsForMonth(_selectedMonth);
    final chipGroups = visibleGroups.isNotEmpty ? visibleGroups : _groups;

    return RefreshIndicator(
      color: AppTheme.brandColor,
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _AttendanceHeroCard(
            title: 'Mening davomatim',
            subtitle: _formatMonthLabel(_selectedMonth),
          ),
          const SizedBox(height: 12),
          _MonthSelect(
            months: months,
            selectedMonth: _selectedMonth,
            onSelected: _selectMonth,
          ),
          const SizedBox(height: 12),
          if (chipGroups.isNotEmpty) ...[
            _GroupChips(
              groups: chipGroups,
              selectedGroupId: _selectedGroupId,
              onSelected: _selectGroup,
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
            const SizedBox(height: 12),
          ],
          if (_loading)
            const _AttendanceLoadingSkeleton()
          else if (_errorText != null)
            _AttendanceErrorState(message: _errorText!, onRetry: _reload)
          else if (_groups.isEmpty)
            const _AttendanceEmptyState()
          else
            _selectedDetailFuture == null
                ? const _AttendanceEmptyState()
                : FutureBuilder<StudentAttendanceDetail>(
                    future: _selectedDetailFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _AttendanceLoadingSkeleton();
                      }

                      if (snapshot.error != null || snapshot.data == null) {
                        return _AttendanceErrorCard(
                          message: _readErrorMessage(
                            snapshot.error ??
                                'Davomat ma\'lumotlari yuklanmadi',
                          ),
                        );
                      }

                      final detail = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SelectedGroupSummaryCard(detail: detail),
                          const SizedBox(height: 12),
                          _AttendanceLessonList(detail: detail),
                        ],
                      );
                    },
                  ),
        ],
      ),
    );
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String _readErrorMessage(Object error) {
    if (error is StudentGroupsException) {
      return error.message;
    }
    return 'Davomat ma\'lumotlari yuklanmadi';
  }
}

class StudentAttendanceDetailPage extends StatefulWidget {
  const StudentAttendanceDetailPage({
    super.key,
    required this.session,
    required this.groupId,
    required this.initialMonth,
    required this.startMonthKey,
    this.initialDetail,
  });

  final AuthSession session;
  final int groupId;
  final String initialMonth;
  final String startMonthKey;
  final StudentAttendanceDetail? initialDetail;

  @override
  State<StudentAttendanceDetailPage> createState() =>
      _StudentAttendanceDetailPageState();
}

class _StudentAttendanceDetailPageState
    extends State<StudentAttendanceDetailPage> {
  final StudentAttendanceService _service = StudentAttendanceService();
  late String _selectedMonth;
  StudentAttendanceDetail? _detail;
  bool _loading = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _clampMonthKey(widget.initialMonth, widget.startMonthKey);
    _detail = widget.initialDetail;
    _loading = widget.initialDetail == null;
    if (widget.initialDetail == null) {
      _load();
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final detail = await _service.fetchAttendanceDetail(
        widget.session,
        groupId: widget.groupId,
        month: _selectedMonth,
        studentId: widget.session.user.id,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
      });
    } catch (error) {
      _errorText = _readErrorMessage(error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    await _load();
  }

  void _selectMonth(String month) {
    final selected = _parseMonthKey(month);
    final minMonth = _parseMonthKey(widget.startMonthKey);
    if (selected != null && minMonth != null && selected.isBefore(minMonth)) {
      return;
    }
    if (_selectedMonth == month) return;
    setState(() {
      _selectedMonth = month;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final months = _availableMonths();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Mening davomatim'),
      ),
      body: RefreshIndicator(
        color: AppTheme.brandColor,
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _MonthSelect(
              months: months,
              selectedMonth: _selectedMonth,
              onSelected: _selectMonth,
            ),
            const SizedBox(height: 12),
            if (_loading && detail == null)
              const _AttendanceLoadingSkeleton()
            else if (_errorText != null && detail == null)
              _AttendanceErrorState(message: _errorText!, onRetry: _reload)
            else if (detail == null)
              const _AttendanceEmptyState()
            else ...[
              _AttendanceDetailHeroCard(detail: detail),
              const SizedBox(height: 12),
              _AttendanceSummaryCards(detail: detail),
              const SizedBox(height: 12),
              _AttendanceLegend(detail: detail),
              const SizedBox(height: 12),
              _AttendanceTable(detail: detail),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _availableMonths() {
    return _monthsDescending(startMonthKey: widget.startMonthKey);
  }

  String _readErrorMessage(Object error) {
    if (error is StudentAttendanceException) {
      return error.message;
    }
    return 'Davomat ma\'lumotlari yuklanmadi';
  }
}

class _AttendanceHeroCard extends StatelessWidget {
  const _AttendanceHeroCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: AppTheme.brandColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B8495),
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

class _MonthSelect extends StatelessWidget {
  const _MonthSelect({
    required this.months,
    required this.selectedMonth,
    required this.onSelected,
  });

  final List<String> months;
  final String selectedMonth;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: months.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final month = months[index];
          final selected = month == selectedMonth;
          return InkWell(
            onTap: () => onSelected(month),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppTheme.brandColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      selected ? AppTheme.brandColor : const Color(0xFFD4DAE6),
                ),
              ),
              child: Text(
                _formatMonthLabel(month),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF4A5468),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.groups,
    required this.selectedGroupId,
    required this.onSelected,
  });

  final List<StudentGroupSummary> groups;
  final int? selectedGroupId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = groups[index];
          final selected = group.groupId == selectedGroupId;
          return InkWell(
            onTap: () => onSelected(group.groupId),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppTheme.brandColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      selected ? AppTheme.brandColor : const Color(0xFFD4DAE6),
                ),
              ),
              child: Text(
                group.groupName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF445066),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SelectedGroupSummaryCard extends StatelessWidget {
  const _SelectedGroupSummaryCard({required this.detail});

  final StudentAttendanceDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupBadge(label: _monogram(detail.groupInfo.name), size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.groupInfo.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniPill(
                      label: detail.groupInfo.subject,
                      background: const Color(0xFFEAF0FF),
                      foreground: const Color(0xFF4C63D2),
                    ),
                    _MiniPill(
                      label: detail.monthlyStatusLabel,
                      background: detail.statusBackground,
                      foreground: detail.statusForeground,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Teacher: ${detail.groupInfo.teacher}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A4454),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail.studentInfo.fullName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B8495),
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

class _AttendanceLessonList extends StatelessWidget {
  const _AttendanceLessonList({required this.detail});

  final StudentAttendanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final rows = detail.dailyAttendance;
    if (rows.isEmpty) {
      return const _AttendanceEmptyState();
    }

    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          _AttendanceLessonCard(lesson: rows[index]),
          if (index != rows.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AttendanceLessonCard extends StatelessWidget {
  const _AttendanceLessonCard({required this.lesson});

  final StudentAttendanceDailyLesson lesson;

  @override
  Widget build(BuildContext context) {
    final status = (lesson.status ?? '').toLowerCase();
    final bool isHoliday = lesson.isHoliday;
    final lessonDate = _parseLessonDate(lesson.lessonDate);
    final today = DateTime.now();
    final isFutureLesson = lessonDate != null &&
        DateTime(
          lessonDate.year,
          lessonDate.month,
          lessonDate.day,
        ).isAfter(DateTime(today.year, today.month, today.day));
    final Color statusColor;
    final String statusLabel;
    final IconData icon;

    if (isHoliday) {
      statusColor = const Color(0xFF2563EB);
      statusLabel = 'Dam olish';
      icon = Icons.beach_access_rounded;
    } else if (status == 'keldi' || status == 'present') {
      statusColor = const Color(0xFF16A34A);
      statusLabel = 'Keldi';
      icon = Icons.check_circle_rounded;
    } else if (status == 'kelmadi' || status == 'absent') {
      if (isFutureLesson) {
        statusColor = const Color(0xFF94A3B8);
        statusLabel = '-';
        icon = Icons.remove_rounded;
      } else {
        statusColor = const Color(0xFFEF4444);
        statusLabel = 'Kelmadi';
        icon = Icons.cancel_rounded;
      }
    } else if (status == 'kechikdi' || status == 'late') {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Kechikdi';
      icon = Icons.access_time_filled_rounded;
    } else if (status.isEmpty || isFutureLesson) {
      statusColor = const Color(0xFF94A3B8);
      statusLabel = '-';
      icon = Icons.remove_rounded;
    } else {
      statusColor = const Color(0xFF94A3B8);
      statusLabel = '-';
      icon = Icons.remove_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withAlpha((0.12 * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateHeader(lesson.lessonDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _weekdayLabel(lesson.lessonDate),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B8495),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MiniPill(
            label: statusLabel,
            background: statusColor.withAlpha((0.12 * 255).round()),
            foreground: statusColor,
          ),
        ],
      ),
    );
  }
}

class _AttendanceDetailHeroCard extends StatelessWidget {
  const _AttendanceDetailHeroCard({required this.detail});

  final StudentAttendanceDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GroupBadge(label: _monogram(detail.groupInfo.name)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.groupInfo.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF182033),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniPill(
                          label: detail.groupInfo.subject,
                          background: const Color(0xFFEAF0FF),
                          foreground: const Color(0xFF4C63D2),
                        ),
                        _MiniPill(
                          label: detail.monthlyStatusLabel,
                          background: detail.statusBackground,
                          foreground: detail.statusForeground,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Teacher: ${detail.groupInfo.teacher}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3A4454),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail.studentInfo.fullName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7B8495),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceSummaryCards extends StatelessWidget {
  const _AttendanceSummaryCards({required this.detail});

  final StudentAttendanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final stats = detail.statistics;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Jami dars',
                value: stats.totalLessons.toString(),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Keldi',
                value: stats.attendedLessons.toString(),
                valueColor: const Color(0xFF0E8C45),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Yo‘q',
                value: stats.missedLessons.toString(),
                valueColor: const Color(0xFFEF4444),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Foiz',
                value: '${stats.attendancePercentage}%',
                valueColor: const Color(0xFF6D4DF6),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AttendanceLegend extends StatelessWidget {
  const _AttendanceLegend({required this.detail});

  final StudentAttendanceDetail detail;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MiniPill(
          label: 'Faol: ${detail.breakdown.keldi}',
          background: const Color(0xFFEAF8EE),
          foreground: const Color(0xFF0E8C45),
        ),
        _MiniPill(
          label: 'Kelmadi: ${detail.breakdown.kelmadi}',
          background: const Color(0xFFFEE2E2),
          foreground: const Color(0xFFB91C1C),
        ),
        _MiniPill(
          label: 'Kechikdi: ${detail.breakdown.kechikdi}',
          background: const Color(0xFFFFF4D6),
          foreground: const Color(0xFFB45309),
        ),
        _MiniPill(
          label: 'Belgilanmagan: ${detail.breakdown.kelmagan}',
          background: const Color(0xFFF1F5F9),
          foreground: const Color(0xFF64748B),
        ),
      ],
    );
  }
}

class _AttendanceTable extends StatelessWidget {
  const _AttendanceTable({required this.detail});

  final StudentAttendanceDetail detail;

  @override
  Widget build(BuildContext context) {
    final rows = detail.dailyAttendance;

    if (rows.isEmpty) {
      return const _AttendanceEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kunlik davomat',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF182033),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(color: const Color(0xFFD7DDE8), width: 1),
              defaultColumnWidth: const FixedColumnWidth(112),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                  children: rows.map((lesson) {
                    return _TableCell(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatDateHeader(lesson.lessonDate),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF182033),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _weekdayLabel(lesson.lessonDate),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7B8495),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                TableRow(
                  children: rows.map((lesson) {
                    return _TableCell(
                      child: Center(child: _AttendanceMark(lesson: lesson)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceMark extends StatelessWidget {
  const _AttendanceMark({required this.lesson});

  final StudentAttendanceDailyLesson lesson;

  @override
  Widget build(BuildContext context) {
    if (lesson.isHoliday) {
      return const Icon(
        Icons.beach_access_rounded,
        size: 28,
        color: Color(0xFF2563EB),
      );
    }

    final status = (lesson.status ?? '').toLowerCase();
    if (status == 'keldi' || status == 'present') {
      return const Icon(
        Icons.check_circle_rounded,
        size: 32,
        color: Color(0xFF16A34A),
      );
    }
    if (status == 'kelmadi' || status == 'absent') {
      return const Icon(
        Icons.cancel_rounded,
        size: 32,
        color: Color(0xFFEF4444),
      );
    }
    if (status == 'kechikdi' || status == 'late') {
      return const Icon(
        Icons.access_time_filled_rounded,
        size: 30,
        color: Color(0xFFF59E0B),
      );
    }

    return const Text(
      '-',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

class _AttendanceLoadingSkeleton extends StatelessWidget {
  const _AttendanceLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
          height: 144,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E9F1)),
          ),
          child: const SizedBox.expand(child: _ShimmerLine()),
        );
      }),
    );
  }
}

class _AttendanceErrorState extends StatelessWidget {
  const _AttendanceErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9F1239),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Qayta urinish'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceErrorCard extends StatelessWidget {
  const _AttendanceErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AttendanceEmptyState extends StatelessWidget {
  const _AttendanceEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_busy_rounded, size: 38, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text(
            'Davomat ma\'lumotlari topilmadi',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    this.valueColor,
  });

  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7B8495),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: valueColor ?? const Color(0xFF182033),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 122,
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );
  }
}

class _GroupBadge extends StatelessWidget {
  const _GroupBadge({required this.label, this.size = 56});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF6B5CF6), Color(0xFF4A7BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _ShimmerLine extends StatefulWidget {
  const _ShimmerLine();

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (_controller.value * 2), -0.3),
              end: Alignment(1.0 + (_controller.value * 2), 0.3),
              colors: const [
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _monogram(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return 'G';
  final words = normalized.split(RegExp(r'\s+'));
  if (words.length == 1) {
    return words.first.isNotEmpty ? words.first[0].toUpperCase() : 'G';
  }
  final first = words.first.isNotEmpty ? words.first[0].toUpperCase() : 'G';
  final second = words[1].isNotEmpty ? words[1][0].toUpperCase() : 'G';
  return '$first$second';
}

String _formatMonthLabel(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final year = parts[0];
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
  return '$monthName $year';
}

String _formatDateHeader(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return '-';
  final parsed = _parseLessonDate(value);
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
  final monthName =
      parsed.month >= 1 && parsed.month <= 12 ? months[parsed.month - 1] : '';
  return '${parsed.day}- $monthName';
}

String _weekdayLabel(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return '';
  final parsed = _parseLessonDate(value);
  if (parsed == null) return '';
  const weekdays = [
    'Yakshanba',
    'Dushanba',
    'Seshanba',
    'Chorshanba',
    'Payshanba',
    'Juma',
    'Shanba',
  ];
  return weekdays[parsed.weekday % 7];
}

DateTime? _parseLessonDate(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return null;

  final direct = DateTime.tryParse(value);
  if (direct != null) {
    return DateTime(direct.year, direct.month, direct.day);
  }

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (match != null) {
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  final fallback = value.split('T').first;
  final parts = fallback.split('-');
  if (parts.length >= 3) {
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }

  return null;
}
