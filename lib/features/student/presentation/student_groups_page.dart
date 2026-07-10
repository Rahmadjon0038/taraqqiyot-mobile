import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../data/student_groups_service.dart';
import 'student_group_detail_page.dart';

class StudentGroupsPage extends StatefulWidget {
  const StudentGroupsPage({
    super.key,
    required this.session,
  });

  final AuthSession session;

  @override
  State<StudentGroupsPage> createState() => _StudentGroupsPageState();
}

class _StudentGroupsPageState extends State<StudentGroupsPage> {
  final StudentGroupsService _service = StudentGroupsService();
  late Future<List<StudentGroupSummary>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _service.fetchMyGroups(widget.session);
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
    await _groupsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudentGroupSummary>>(
      future: _groupsFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.error;
        final groups = snapshot.data ?? const <StudentGroupSummary>[];

        return RefreshIndicator(
          onRefresh: _reload,
          color: AppTheme.brandColor,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (isLoading)
                const _GroupsLoadingSkeleton()
              else if (error != null)
                _ErrorState(
                  message: _readErrorMessage(error),
                  onRetry: _reload,
                )
              else if (groups.isEmpty)
                const _EmptyState()
              else
                for (final group in groups) ...[
                  _StudentGroupCard(
                    group: group,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentGroupDetailPage(
                            session: widget.session,
                            groupId: group.groupId,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }

  String _readErrorMessage(Object error) {
    if (error is StudentGroupsException) {
      return error.message;
    }
    return 'Guruhlar yuklanmadi';
  }
}

class _StudentGroupCard extends StatelessWidget {
  const _StudentGroupCard({
    required this.group,
    required this.onTap,
  });

  final StudentGroupSummary group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4E9F1)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0E000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF182033),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MiniPill(
                    label: group.subjectName,
                    background: const Color(0xFFFBEAE9),
                    foreground: AppTheme.brandColor,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Ustoz: ${group.teacherName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3A4454),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Wrap — chiplar sig'masa ellipsis o'rniga pastki qatorga tushadi
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MiniPill(
                          label: 'Ball: ${group.monthlyPoints}',
                          background: const Color(0xFFFBEAE9),
                          foreground: AppTheme.brandColor,
                        ),
                        _MiniPill(
                          label: group.monthlyRank > 0
                              ? 'Guruhdagi o‘rningiz: ${group.monthlyRank}'
                              : 'Guruhdagi o‘rningiz: -',
                          background: const Color(0xFFF4F6FA),
                          foreground: const Color(0xFF5C6474),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: Color(0xFF8A93A5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(group.createdDate),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7B8495),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MasteryProgressBar(percent: group.masteryPercent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir oylik o'zlashtirish ko'rsatkichi — brend qizil rangdagi progress bar
class _MasteryProgressBar extends StatelessWidget {
  const _MasteryProgressBar({required this.percent});

  /// 0..100 oralig'idagi foiz
  final double percent;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100).toDouble();
    final label = '${clamped.round()}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFFBEAE9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              size: 18,
              color: AppTheme.brandColor,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'O\'zlashtirish',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7B8495),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.brandColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(color: const Color(0xFFE9E2E1)),
                    FractionallySizedBox(
                      widthFactor: clamped / 100,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFA70E07), Color(0xFF7C0A05)],
                          ),
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

String _formatDate(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '-';

  final normalized = raw.replaceAll('/', '.');
  final parts = normalized.split('.');
  if (parts.length != 3) return raw;

  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return raw;

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
  if (month < 1 || month > months.length) return raw;

  return '$day ${months[month - 1]} $year';
}

class _GroupsLoadingSkeleton extends StatelessWidget {
  const _GroupsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
          child: const _LoadingCard(),
        );
      }),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: 170, height: 18, radius: 10),
          const SizedBox(height: 8),
          _SkeletonBox(width: 130, height: 12, radius: 999),
          const SizedBox(height: 12),
          _SkeletonBox(width: 100, height: 22, radius: 999),
          const SizedBox(height: 12),
          _SkeletonBox(width: double.infinity, height: 44, radius: 14),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF3),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD2CF)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFA70E07), size: 40),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: const Column(
        children: [
          Icon(Icons.groups_outlined, color: Color(0xFFA1A8B6), size: 44),
          SizedBox(height: 10),
          Text(
            'Hozircha guruhlaringiz yo\'q',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF182033),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Siz a\'zo bo\'lgan guruhlar shu yerda kartalar ko\'rinishida chiqadi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: Color(0xFF748091),
            ),
          ),
        ],
      ),
    );
  }
}
