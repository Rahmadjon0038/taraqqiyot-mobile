import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/super_admin_service.dart';

/// O'qituvchilar ro'yxati: qidiruv va holat bo'yicha filtrlash bilan.
class SuperAdminTeachersPage extends StatefulWidget {
  const SuperAdminTeachersPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<SuperAdminTeachersPage> createState() =>
      _SuperAdminTeachersPageState();
}

class _SuperAdminTeachersPageState extends State<SuperAdminTeachersPage> {
  final SuperAdminService _service = SuperAdminService();
  late Future<List<TeacherDirectoryEntry>> _teachersFuture;
  String _status = 'all';
  String _query = '';

  static const _statusOptions = [
    (value: 'all', label: 'Hammasi'),
    (value: 'active', label: 'Faol'),
    (value: 'on_leave', label: "Ta'tilda"),
    (value: 'terminated', label: "Bo'shatilgan"),
  ];

  @override
  void initState() {
    super.initState();
    _teachersFuture = _service.fetchTeachers(widget.session);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _selectStatus(String status) {
    if (status == _status) return;
    setState(() {
      _status = status;
      _teachersFuture = _service.fetchTeachers(
        widget.session,
        status: status == 'all' ? null : status,
      );
    });
  }

  Future<void> _reload() async {
    setState(() {
      _teachersFuture = _service.fetchTeachers(
        widget.session,
        status: _status == 'all' ? null : _status,
      );
    });
    await _teachersFuture;
  }

  List<TeacherDirectoryEntry> _filter(List<TeacherDirectoryEntry> source) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return source;
    return source.where((teacher) {
      final fullName = teacher.fullName.toLowerCase();
      final subjects = teacher.subjectsList.toLowerCase();
      return fullName.contains(query) || subjects.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: AppTheme.brandColor,
      child: FutureBuilder<List<TeacherDirectoryEntry>>(
        future: _teachersFuture,
        builder: (context, snapshot) {
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting;
          final teachers = _filter(
            snapshot.data ?? const <TeacherDirectoryEntry>[],
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF182033).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF182033),
                  ),
                  decoration: InputDecoration(
                    hintText: "Ism yoki fan bo'yicha qidirish",
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
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(color: Color(0xFFD6DDEA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: const BorderSide(
                        color: AppTheme.brandColor,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _statusOptions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final option = _statusOptions[index];
                    final selected = option.value == _status;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectStatus(option.value),
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
                          option.label,
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
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 70),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.brandColor,
                    ),
                  ),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: Center(
                    child: Text(
                      snapshot.error is SuperAdminServiceException
                          ? (snapshot.error as SuperAdminServiceException)
                                .message
                          : "O'qituvchilar yuklanmadi",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else if (teachers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: Center(
                    child: Text(
                      "O'qituvchilar topilmadi",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else
                for (final teacher in teachers) ...[
                  _TeacherCard(teacher: teacher),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  const _TeacherCard({required this.teacher});

  final TeacherDirectoryEntry teacher;

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final String statusLabel;
    if (teacher.isActive) {
      statusColor = const Color(0xFF16934F);
      statusLabel = 'Faol';
    } else if (teacher.isOnLeave) {
      statusColor = const Color(0xFFB45309);
      statusLabel = "Ta'tilda";
    } else {
      statusColor = const Color(0xFF8A93A5);
      statusLabel = "Bo'shatilgan";
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Text(
              teacher.name.isNotEmpty ? teacher.name[0].toUpperCase() : 'O',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teacher.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  teacher.subjectsList.isEmpty
                      ? 'Fan belgilanmagan'
                      : teacher.subjectsList,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B8495),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (teacher.phone.isNotEmpty) teacher.phone,
                    '${teacher.activeStudentCount} ta faol talaba',
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A93A5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
