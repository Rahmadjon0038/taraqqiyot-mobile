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

  Future<void> _openPointSheet(TeacherGroupStudent student) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PointSheet(
        session: widget.session,
        service: _service,
        groupId: widget.groupId,
        student: student,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${student.fullName}ga ball qo\'shildi'),
          backgroundColor: const Color(0xFF16934F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Yangi ball va o'rinlar darhol ko'rinishi uchun ro'yxatni yangilaymiz
      await _reload();
    }
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
                      onGivePoint: () => _openPointSheet(students[i]),
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
    required this.onGivePoint,
  });

  final int rank;

  /// Faqat haqiqiy 1-2-3 o'rinlar uchun true — shulargina ajralib turadi
  final bool medal;
  final TeacherGroupStudent student;
  final VoidCallback onGivePoint;

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
          const SizedBox(width: 8),
          Material(
            color: AppTheme.brandColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onGivePoint,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: AppTheme.brandColor,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Ball',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brandColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ball qo'yish bottom sheet: tez tanlash tugmalari, sarlavha va izoh.
class _PointSheet extends StatefulWidget {
  const _PointSheet({
    required this.session,
    required this.service,
    required this.groupId,
    required this.student,
  });

  final AuthSession session;
  final TeacherService service;
  final int groupId;
  final TeacherGroupStudent student;

  @override
  State<_PointSheet> createState() => _PointSheetState();
}

class _PointSheetState extends State<_PointSheet> {
  static const List<int> _quickPoints = [1, 2, 5, 10, -1, -5];

  int _points = 5;
  final TextEditingController _titleController = TextEditingController(
    text: 'Darsdagi faollik',
  );
  final TextEditingController _descriptionController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Sarlavha kiritilishi kerak');
      return;
    }
    if (_points == 0) {
      setState(() => _error = 'Ball 0 bo\'lishi mumkin emas');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.service.createPointEvent(
        widget.session,
        studentId: widget.student.id,
        groupId: widget.groupId,
        points: _points,
        title: title,
        description: _descriptionController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on TeacherServiceException catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Ball qo\'shilmadi, qayta urinib ko\'ring';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ball qo\'yish',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF182033),
                        ),
                      ),
                      Text(
                        widget.student.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Tez tanlash tugmalari
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in _quickPoints)
                  _QuickPointChip(
                    value: value,
                    selected: _points == value,
                    onTap: () => setState(() => _points = value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Aniq qiymat: +/- stepper
            Row(
              children: [
                const Text(
                  'Ball:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF182033),
                  ),
                ),
                const SizedBox(width: 12),
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onTap: () => setState(() => _points -= 1),
                ),
                Container(
                  width: 56,
                  alignment: Alignment.center,
                  child: Text(
                    _points > 0 ? '+$_points' : '$_points',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _points >= 0
                          ? const Color(0xFF16934F)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onTap: () => setState(() => _points += 1),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration('Sarlavha (majburiy)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: _inputDecoration('Izoh (ixtiyoriy)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Saqlash',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF7B8497),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.brandColor, width: 1.4),
      ),
    );
  }
}

class _QuickPointChip extends StatelessWidget {
  const _QuickPointChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final positive = value > 0;
    final baseColor = positive
        ? const Color(0xFF16934F)
        : const Color(0xFFDC2626);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? baseColor : baseColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          positive ? '+$value' : '$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : baseColor,
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F4F9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: const Color(0xFF182033)),
        ),
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
