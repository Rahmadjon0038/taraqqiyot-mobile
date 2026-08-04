import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../../profile/presentation/widgets/profile_avatar.dart';
import '../data/teacher_service.dart';

/// Guruh ichi: o'quvchilar ro'yxati va har biriga ball qo'yish.
class TeacherGroupDetailPage extends StatefulWidget {
  const TeacherGroupDetailPage({
    super.key,
    required this.session,
    required this.groupId,
    required this.groupName,
  });

  final AuthSession session;
  final int groupId;
  final String groupName;

  @override
  State<TeacherGroupDetailPage> createState() => _TeacherGroupDetailPageState();
}

class _TeacherGroupDetailPageState extends State<TeacherGroupDetailPage> {
  final TeacherService _service = TeacherService();
  late Future<TeacherGroupDetail> _detailFuture;

  /// Yangilash paytida ekran miltillamasligi uchun oxirgi ma'lumot
  TeacherGroupDetail? _lastDetail;

  @override
  void initState() {
    super.initState();
    _detailFuture = _service.fetchGroupDetail(widget.session, widget.groupId);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _detailFuture = _service.fetchGroupDetail(widget.session, widget.groupId);
    });
    await _detailFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.groupName,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF182033),
          ),
        ),
      ),
      body: FutureBuilder<TeacherGroupDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _lastDetail = snapshot.data;
          }
          final detail = snapshot.data ?? _lastDetail;
          if (snapshot.connectionState == ConnectionState.waiting &&
              detail == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.brandColor),
            );
          }
          if (detail == null) {
            return _CenteredError(
              message: snapshot.error is TeacherServiceException
                  ? (snapshot.error as TeacherServiceException).message
                  : 'Guruh ma\'lumotlari yuklanmadi',
              onRetry: _reload,
            );
          }

          // Ball bo'yicha kamayish tartibida; teng ball — bir xil o'rin
          final students = [...detail.students]
            ..sort((a, b) => b.monthlyPoints.compareTo(a.monthlyPoints));
          final ranks = <int, int>{};
          var rank = 0;
          int? previousPoints;
          for (var i = 0; i < students.length; i++) {
            if (previousPoints == null ||
                students[i].monthlyPoints != previousPoints) {
              rank = i + 1;
              previousPoints = students[i].monthlyPoints;
            }
            ranks[students[i].id] = rank;
          }
          final activeCount = students.where((s) => s.isActive).length;

          return RefreshIndicator(
            onRefresh: _reload,
            color: AppTheme.brandColor,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _GroupHeaderCard(detail: detail, activeCount: activeCount),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'O\'quvchilar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF182033),
                    ),
                  ),
                ),
                if (students.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE4E9F1)),
                    ),
                    child: const Center(
                      child: Text(
                        'Guruhda o\'quvchilar yo\'q',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < students.length; i++) ...[
                    _StudentRow(
                      rank: ranks[students[i].id] ?? 0,
                      // Medal faqat ro'yxatdagi birinchi uchtaga va
                      // haqiqatan ball to'plaganlarga beriladi
                      medal: i < 3 && students[i].monthlyPoints > 0,
                      student: students[i],
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupHeaderCard extends StatelessWidget {
  const _GroupHeaderCard({required this.detail, required this.activeCount});

  final TeacherGroupDetail detail;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
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
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -20,
            child: Icon(
              Icons.school_rounded,
              size: 100,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.groupName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail.subjectName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _HeroChip(
                      icon: Icons.people_alt_rounded,
                      label: '${detail.students.length} o\'quvchi',
                    ),
                    _HeroChip(
                      icon: Icons.check_circle_rounded,
                      label: '$activeCount faol',
                    ),
                    if (detail.roomNumber.isNotEmpty)
                      _HeroChip(
                        icon: Icons.meeting_room_rounded,
                        label: '${detail.roomNumber}-xona',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.rank,
    required this.medal,
    required this.student,
  });

  final int rank;

  /// Faqat haqiqiy 1-2-3 o'rinlar uchun true — shulargina ajralib turadi
  final bool medal;
  final TeacherGroupStudent student;

  bool get _isTopThree => medal && rank >= 1 && rank <= 3;

  static const _medalColors = {
    1: Color(0xFFD4A017), // oltin
    2: Color(0xFF8E9AAB), // kumush
    3: Color(0xFFB4691E), // bronza
  };

  @override
  Widget build(BuildContext context) {
    final active = student.isActive;
    final medalColor = _isTopThree ? _medalColors[rank] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isTopThree
              ? medalColor!.withValues(alpha: 0.45)
              : const Color(0xFFE4E9F1),
          width: _isTopThree ? 1.4 : 1,
        ),
        boxShadow: _isTopThree
            ? [
                BoxShadow(
                  color: medalColor!.withValues(alpha: 0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // O'rin: 1-2-3 uchun medal, qolganlarga raqam
          if (_isTopThree)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [medalColor!, medalColor.withValues(alpha: 0.72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 15,
                color: Colors.white,
              ),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F4F9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  rank > 0 ? '$rank' : '-',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5A6478),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          ProfileAvatar(
            avatarKey: student.avatarKey,
            avatarUrl: student.avatarUrl,
            role: 'student',
            seed: student.fullName,
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _isTopThree ? medalColor : const Color(0xFF182033),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: Color(0xFFD4A017),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${student.monthlyPoints} ball',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5A6478),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      active ? 'Faol' : 'Nofaol',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? const Color(0xFF16934F)
                            : const Color(0xFF9AA2B2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredError extends StatelessWidget {
  const _CenteredError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: AppTheme.brandColor,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF182033),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => onRetry(),
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
}
