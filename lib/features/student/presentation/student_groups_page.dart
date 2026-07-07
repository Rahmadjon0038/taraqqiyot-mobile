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
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF0F2F7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 20,
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
                  _GroupMonogram(label: _monogram(group.groupName)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.groupName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF182033),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _MiniPill(
                              label: group.subjectName,
                              background: const Color(0xFFEAF0FF),
                              foreground: const Color(0xFF4C63D2),
                            ),
                            _MiniPill(
                              label: group.teacherName,
                              background: const Color(0xFFF4F6FA),
                              foreground: const Color(0xFF5C6474),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEFF2F7)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Narx',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7B8495),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatMoney(group.price),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF14903B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Yaratilgan sana',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7B8495),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formatDate(group.createdDate),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF182033),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupMonogram extends StatelessWidget {
  const _GroupMonogram({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF6B5CF6), Color(0xFF4A7BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A5A64F5),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
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

String _monogram(String value) {
  final words = value.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return 'G';
  if (words.length == 1) {
    final text = words.first;
    return text.length >= 2 ? text.substring(0, 2).toUpperCase() : text.toUpperCase();
  }
  final first = words.first.isNotEmpty ? words.first[0] : 'G';
  final second = words[1].isNotEmpty ? words[1][0] : '';
  return (first + second).toUpperCase();
}

String _formatMoney(double value) {
  final text = value.toStringAsFixed(0);
  final parts = <String>[];
  for (var i = text.length; i > 0; i -= 3) {
    final start = i - 3 < 0 ? 0 : i - 3;
    parts.insert(0, text.substring(start, i));
  }
  return '${parts.join(' ')} so\'m';
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
      height: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonBox(width: 68, height: 68, radius: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 170, height: 18, radius: 10),
                    const SizedBox(height: 8),
                    _SkeletonBox(width: 100, height: 12, radius: 999),
                    const SizedBox(height: 8),
                    _SkeletonBox(width: 130, height: 12, radius: 999),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SkeletonBox(width: double.infinity, height: 56, radius: 20),
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
