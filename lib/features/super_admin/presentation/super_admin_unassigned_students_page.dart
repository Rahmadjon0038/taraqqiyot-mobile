import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/super_admin_service.dart';

/// Guruhsiz (hech qanday guruhga biriktirilmagan) talabalar ro'yxati —
/// fanlar kesimida guruhlangan holda.
class SuperAdminUnassignedStudentsPage extends StatefulWidget {
  const SuperAdminUnassignedStudentsPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<SuperAdminUnassignedStudentsPage> createState() =>
      _SuperAdminUnassignedStudentsPageState();
}

class _SuperAdminUnassignedStudentsPageState
    extends State<SuperAdminUnassignedStudentsPage> {
  final SuperAdminService _service = SuperAdminService();
  late Future<List<UnassignedStudent>> _future;
  String _query = '';
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchUnassignedStudents(widget.session);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.fetchUnassignedStudents(widget.session);
    });
    await _future;
  }

  Map<String, List<UnassignedStudent>> _groupBySubject(
    List<UnassignedStudent> students,
  ) {
    final grouped = <String, List<UnassignedStudent>>{};
    for (final student in students) {
      final key = student.subjectName.isEmpty
          ? 'Fan belgilanmagan'
          : student.subjectName;
      grouped.putIfAbsent(key, () => []).add(student);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => a == 'Fan belgilanmagan'
          ? 1
          : (b == 'Fan belgilanmagan' ? -1 : a.compareTo(b)));
    return {for (final key in sortedKeys) key: grouped[key]!};
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
          'Guruhsiz talabalar',
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
        child: FutureBuilder<List<UnassignedStudent>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.brandColor),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    snapshot.error is SuperAdminServiceException
                        ? (snapshot.error as SuperAdminServiceException)
                              .message
                        : 'Guruhsiz talabalar yuklanmadi',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }

            final students = snapshot.data ?? const <UnassignedStudent>[];
            final subjectCounts = _groupBySubject(students);
            final query = _query.trim().toLowerCase();

            List<UnassignedStudent> filtered;
            if (query.isNotEmpty) {
              filtered = students
                  .where((s) => s.fullName.toLowerCase().contains(query))
                  .toList();
            } else if (_selectedSubject != null) {
              filtered = students
                  .where(
                    (s) =>
                        (s.subjectName.isEmpty
                            ? 'Fan belgilanmagan'
                            : s.subjectName) ==
                        _selectedSubject,
                  )
                  .toList();
            } else {
              filtered = students;
            }
            final grouped = _groupBySubject(filtered);

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: "Ism bo'yicha qidirish",
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9AA2B2),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF9AA2B2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(color: Color(0xFFD6DDEA)),
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
                if (subjectCounts.length > 1) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _SubjectChip(
                          label: 'Hammasi',
                          count: students.length,
                          selected: _selectedSubject == null,
                          onTap: () =>
                              setState(() => _selectedSubject = null),
                        ),
                        for (final entry in subjectCounts.entries) ...[
                          const SizedBox(width: 8),
                          _SubjectChip(
                            label: entry.key,
                            count: entry.value.length,
                            selected: _selectedSubject == entry.key,
                            onTap: () => setState(
                              () => _selectedSubject = entry.key,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Jami: ${filtered.length} ta talaba',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A93A5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (grouped.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: Center(
                      child: Text(
                        'Guruhsiz talabalar topilmadi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  )
                else
                  for (final entry in grouped.entries) ...[
                    _SubjectGroupTile(
                      subjectName: entry.key,
                      students: entry.value,
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.brandColor : const Color(0xFFD6DDEA),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$label · $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : const Color(0xFF5A6478),
          ),
        ),
      ),
    );
  }
}

class _SubjectGroupTile extends StatefulWidget {
  const _SubjectGroupTile({required this.subjectName, required this.students});

  final String subjectName;
  final List<UnassignedStudent> students;

  @override
  State<_SubjectGroupTile> createState() => _SubjectGroupTileState();
}

class _SubjectGroupTileState extends State<_SubjectGroupTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
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
                    Icons.menu_book_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF182033),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.brandColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${widget.students.length} ta',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.brandColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
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
          if (_expanded) ...[
            const SizedBox(height: 10),
            for (final student in widget.students) ...[
              _UnassignedStudentCard(student: student),
              if (student != widget.students.last)
                const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _UnassignedStudentCard extends StatelessWidget {
  const _UnassignedStudentCard({required this.student});

  final UnassignedStudent student;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
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
                  color: const Color(0xFF8A93A5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  student.name.isNotEmpty
                      ? student.name[0].toUpperCase()
                      : 'T',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5A6478),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF182033),
                      ),
                    ),
                    if (student.age != null)
                      Text(
                        '${student.age} yosh',
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
          const SizedBox(height: 8),
          _InfoLine(icon: Icons.call_rounded, label: student.phone),
          if (student.phone2.isNotEmpty)
            _InfoLine(icon: Icons.call_rounded, label: student.phone2),
          if (student.fatherName.isNotEmpty || student.fatherPhone.isNotEmpty)
            _InfoLine(
              icon: Icons.family_restroom_rounded,
              label: [
                if (student.fatherName.isNotEmpty) student.fatherName,
                if (student.fatherPhone.isNotEmpty) student.fatherPhone,
              ].join(' • '),
            ),
          if (student.address.isNotEmpty)
            _InfoLine(
              icon: Icons.location_on_outlined,
              label: student.address,
            ),
          if (student.registrationDate.isNotEmpty)
            _InfoLine(
              icon: Icons.event_available_rounded,
              label: "Ro'yxatdan o'tgan: ${student.registrationDateLabel}",
            ),
          if (student.unassignedReason.isNotEmpty)
            _InfoLine(
              icon: Icons.info_outline_rounded,
              label: student.unassignedReason,
              color: const Color(0xFFB45309),
            ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color ?? const Color(0xFF8A93A5)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color ?? const Color(0xFF5A6478),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
