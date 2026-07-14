import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/teacher_service.dart';

/// Dars ichida o'quvchilarni keldi/kelmadi/kechikdi deb belgilash.
class TeacherLessonMarkPage extends StatefulWidget {
  const TeacherLessonMarkPage({
    super.key,
    required this.session,
    required this.lessonId,
    required this.lessonLabel,
  });

  final AuthSession session;
  final int lessonId;
  final String lessonLabel;

  @override
  State<TeacherLessonMarkPage> createState() => _TeacherLessonMarkPageState();
}

class _TeacherLessonMarkPageState extends State<TeacherLessonMarkPage> {
  static const List<(String, String, Color, IconData)> _statuses = [
    ('keldi', 'Keldi', Color(0xFF16934F), Icons.check_rounded),
    ('kelmadi', 'Kelmadi', Color(0xFFDC2626), Icons.close_rounded),
  ];

  final TeacherService _service = TeacherService();
  late Future<List<LessonStudent>> _studentsFuture;

  /// attendance_id -> tanlangan status (draft)
  final Map<int, String> _draft = {};
  bool _saving = false;
  bool _changedAnything = false;

  /// Saqlanmagan tanlovlar qurilmada eslab qolinadigan kalit
  String get _draftPrefsKey => 'teacher_attendance_draft_${widget.lessonId}';

  @override
  void initState() {
    super.initState();
    _studentsFuture = _loadStudents();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  /// O'quvchilarni yuklaydi va saqlanmagan draft tanlovlarni tiklaydi —
  /// teacher "Saqlash"ni bosmay chiqib ketsa ham holat yo'qolmaydi
  Future<List<LessonStudent>> _loadStudents() async {
    final students = await _service.fetchLessonStudents(
      widget.session,
      widget.lessonId,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final markableIds = {
            for (final student in students)
              if (student.canMark) student.attendanceId,
          };
          const allowed = {'keldi', 'kelmadi', 'kechikdi'};
          decoded.forEach((key, value) {
            final id = int.tryParse(key.toString());
            final status = value.toString();
            if (id != null &&
                markableIds.contains(id) &&
                allowed.contains(status)) {
              _draft[id] = status;
            }
          });
        }
      }
    } catch (_) {
      // Draft tiklanmasa ham sahifa ishlayveradi
    }
    return students;
  }

  Future<void> _persistDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_draft.isEmpty) {
        await prefs.remove(_draftPrefsKey);
      } else {
        await prefs.setString(
          _draftPrefsKey,
          jsonEncode({
            for (final entry in _draft.entries)
              entry.key.toString(): entry.value,
          }),
        );
      }
    } catch (_) {
      // Saqlab bo'lmasa jim o'tamiz
    }
  }

  Future<void> _clearPersistedDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftPrefsKey);
    } catch (_) {}
  }

  Future<void> _reload() async {
    setState(() {
      _draft.clear();
      _studentsFuture = _loadStudents();
    });
    await _studentsFuture;
  }

  /// Hamma faol o'quvchiga bitta statusni belgilash (tez to'ldirish)
  void _markAll(List<LessonStudent> students, String status) {
    setState(() {
      for (final student in students) {
        if (student.canMark) {
          _draft[student.attendanceId] = status;
        }
      }
    });
    _persistDraft();
  }

  Future<void> _submit() async {
    if (_draft.isEmpty) return;
    setState(() => _saving = true);

    try {
      final message = await _service.markAttendance(
        widget.session,
        widget.lessonId,
        _draft,
      );
      _changedAnything = true;
      // Serverga yozildi — endi lokal draft kerak emas
      await _clearPersistedDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF16934F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _reload();
    } on TeacherServiceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Davomat saqlanmadi, qayta urinib ko\'ring'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_changedAnything);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF6F7FB),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Davomat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF182033),
                ),
              ),
              Text(
                widget.lessonLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7B8497),
                ),
              ),
            ],
          ),
        ),
        body: FutureBuilder<List<LessonStudent>>(
          future: _studentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.brandColor),
              );
            }
            final students = snapshot.data ?? const <LessonStudent>[];
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.error is TeacherServiceException
                            ? (snapshot.error as TeacherServiceException)
                                  .message
                            : 'O\'quvchilar yuklanmadi',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _reload,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.brandColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Qayta urinish'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (students.isEmpty) {
              return const Center(
                child: Text(
                  'Darsda o\'quvchilar topilmadi',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              );
            }

            final markable = students.where((s) => s.canMark).length;

            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _reload,
                    color: AppTheme.brandColor,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        // Tez to'ldirish: hammani bitta status bilan belgilash
                        Row(
                          children: [
                            const Text(
                              'Hammasi:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF5A6478),
                              ),
                            ),
                            const SizedBox(width: 8),
                            for (final (value, label, color, _)
                                in _statuses) ...[
                              GestureDetector(
                                onTap: () => _markAll(students, value),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final student in students) ...[
                          _StudentMarkRow(
                            student: student,
                            statuses: _statuses,
                            selectedStatus:
                                _draft[student.attendanceId] ?? student.status,
                            onSelect: (status) {
                              if (!student.canMark) return;
                              setState(() {
                                _draft[student.attendanceId] = status;
                              });
                              _persistDraft();
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                // Saqlash paneli
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE4E9F1))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_draft.length}/$markable o\'zgartirildi',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: _saving || _draft.isEmpty ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.brandColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Saqlash',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bosilganda qo'ng'iroq oynasini ochadigan telefon chip
class _PhoneChip extends StatelessWidget {
  const _PhoneChip({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri(scheme: 'tel', path: phone.trim())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_rounded, size: 11, color: Color(0xFF2563EB)),
            const SizedBox(width: 4),
            Text(
              phone.trim(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentMarkRow extends StatelessWidget {
  const _StudentMarkRow({
    required this.student,
    required this.statuses,
    required this.selectedStatus,
    required this.onSelect,
  });

  final LessonStudent student;
  final List<(String, String, Color, IconData)> statuses;
  final String selectedStatus;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final readonly = !student.canMark;

    return Opacity(
      opacity: readonly ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    student.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF182033),
                    ),
                  ),
                ),
                if (student.phone.trim().isNotEmpty)
                  _PhoneChip(phone: student.phone),
                if (readonly)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: Color(0xFF9AA2B2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (value, label, color, icon) in statuses) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: readonly ? null : () => onSelect(value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: EdgeInsets.only(
                          right: value != statuses.last.$1 ? 6 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selectedStatus == value
                              ? color
                              : color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 14,
                              color: selectedStatus == value
                                  ? Colors.white
                                  : color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: selectedStatus == value
                                    ? Colors.white
                                    : color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
