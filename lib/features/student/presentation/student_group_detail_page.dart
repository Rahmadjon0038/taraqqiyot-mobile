import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../../profile/presentation/widgets/profile_avatar.dart';
import '../data/student_groups_service.dart';

class StudentGroupDetailPage extends StatefulWidget {
  const StudentGroupDetailPage({
    super.key,
    required this.session,
    required this.groupId,
  });

  final AuthSession session;
  final int groupId;

  @override
  State<StudentGroupDetailPage> createState() => _StudentGroupDetailPageState();
}

class _StudentGroupDetailPageState extends State<StudentGroupDetailPage> {
  final StudentGroupsService _service = StudentGroupsService();
  late Future<StudentGroupDetails> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _service.fetchMyGroupInfo(widget.session, widget.groupId);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _detailFuture = _service.fetchMyGroupInfo(widget.session, widget.groupId);
    });
    await _detailFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      appBar: AppBar(
        title: const Text('Guruh tafsilotlari'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<StudentGroupDetails>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final error = snapshot.error;
          final detail = snapshot.data;

          if (isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.brandColor),
            );
          }

          if (error != null || detail == null) {
            return _ErrorState(
              message: _readErrorMessage(error),
              onRetry: _reload,
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            color: AppTheme.brandColor,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _HeroCard(detail: detail),
                const SizedBox(height: 8),
                _InfoPairCard(
                  leftLabel: 'Narx',
                  leftValue: _formatMoney(detail.price),
                  rightLabel: 'Yaratilgan sana',
                  rightValue: _formatDate(detail.createdDate),
                  leftValueColor: const Color(0xFF0E8C45),
                ),
                const SizedBox(height: 8),
                _MembersCard(groupmates: detail.groupmates),
              ],
            ),
          );
        },
      ),
    );
  }

  String _readErrorMessage(Object? error) {
    if (error is StudentGroupsException) {
      return error.message;
    }
    return 'Guruh ma\'lumotlari yuklanmadi';
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.detail});

  final StudentGroupDetails detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E9F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 36,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupMonogram(label: _monogram(detail.groupName)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.groupName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
                const SizedBox(height: 5),
                _TinyPill(
                  label: detail.subjectName,
                  background: const Color(0xFFEAF0FF),
                  foreground: const Color(0xFF4C63D2),
                ),
                const SizedBox(height: 8),
                Text(
                  'Teacher: ${detail.teacherName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3A4454),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail.teacherPhone.isEmpty ? '-' : detail.teacherPhone,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B8495),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Azolar: ${detail.totalMembers}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6D4DF6),
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

class _InfoPairCard extends StatelessWidget {
  const _InfoPairCard({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    this.leftValueColor,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final Color? leftValueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E7F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7B8495),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  leftValue,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: leftValueColor ?? const Color(0xFF182033),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rightLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7B8495),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  rightValue,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF182033),
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

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.groupmates});

  final List<StudentGroupMate> groupmates;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E7F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guruhdoshlar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF182033),
            ),
          ),
          const SizedBox(height: 6),
          for (final mate in groupmates) ...[
            _MateRow(mate: mate),
            if (mate != groupmates.last)
              const Divider(height: 14, thickness: 1, color: Color(0xFFE7ECF4)),
          ],
        ],
      ),
    );
  }
}

class _MateRow extends StatelessWidget {
  const _MateRow({required this.mate});

  final StudentGroupMate mate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          ProfileAvatar(
            avatarKey: mate.avatarKey.isEmpty ? null : mate.avatarKey,
            avatarUrl: mate.avatarUrl.isEmpty ? null : mate.avatarUrl,
            role: 'student',
            seed: mate.displayName,
            size: 40,
            showBorder: false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mate.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF182033),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(mate.joinDate),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A93A5),
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

class _GroupMonogram extends StatelessWidget {
  const _GroupMonogram({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
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
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFA70E07), size: 42),
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
      ),
    );
  }
}
