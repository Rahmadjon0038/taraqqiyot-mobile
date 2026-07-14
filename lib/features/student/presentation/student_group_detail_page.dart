import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/weekday_pills_row.dart';
import '../../auth/models/auth_session.dart';
import '../../profile/presentation/widgets/profile_avatar.dart';
import '../data/student_groups_service.dart';

class StudentGroupDetailPage extends StatefulWidget {
  const StudentGroupDetailPage({
    super.key,
    required this.session,
    required this.groupId,
    this.initialScheduleDays = const [],
    this.initialScheduleTime = '',
  });

  final AuthSession session;
  final int groupId;

  /// Guruhlar ro'yxatidan uzatiladigan jadval — detail API'da schedule
  /// bo'lmasa (eski backend) shu qiymatlar ko'rsatiladi
  final List<String> initialScheduleDays;
  final String initialScheduleTime;

  @override
  State<StudentGroupDetailPage> createState() => _StudentGroupDetailPageState();
}

class _StudentGroupDetailPageState extends State<StudentGroupDetailPage> {
  final StudentGroupsService _service = StudentGroupsService();
  late Future<StudentGroupDetails> _detailFuture;
  late String _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _detailFuture = _service.fetchMyGroupInfo(
      widget.session,
      widget.groupId,
      month: _selectedMonth,
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _detailFuture = _service.fetchMyGroupInfo(
        widget.session,
        widget.groupId,
        month: _selectedMonth,
      );
    });
    await _detailFuture;
  }

  void _selectMonth(String monthKey) {
    if (monthKey == _selectedMonth) return;
    setState(() {
      _selectedMonth = monthKey;
      _detailFuture = _service.fetchMyGroupInfo(
        widget.session,
        widget.groupId,
        month: _selectedMonth,
      );
    });
  }

  /// Oy chiplarini guruhda dars boshlangan oydan joriy oygacha yasaydi.
  /// Boshlanish sanasi topilmasa faqat joriy oy chiqadi.
  static List<_MonthOption> _buildMonthOptions(StudentGroupDetails detail) {
    const monthNames = [
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

    final now = DateTime.now();
    final start = _parseDdMmYyyy(detail.startDate) ??
        _parseDdMmYyyy(detail.createdDate) ??
        _parseDdMmYyyy(detail.studentJoinedDate) ??
        now;

    // Nechta oy o'tganini hisoblaymiz (joriy oy ham kiradi)
    var totalMonths =
        (now.year - start.year) * 12 + (now.month - start.month) + 1;
    if (totalMonths < 1) totalMonths = 1;
    // Juda uzun ro'yxatdan saqlanish uchun 24 oy bilan cheklaymiz
    if (totalMonths > 24) totalMonths = 24;

    return List.generate(totalMonths, (i) {
      final date = DateTime(now.year, now.month - i);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final name = monthNames[date.month - 1];
      final label = date.year == now.year ? name : '$name ${date.year}';
      return _MonthOption(key: key, label: label);
    });
  }

  static DateTime? _parseDdMmYyyy(String value) {
    final parts = value.trim().replaceAll('/', '.').split('.');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12) return null;
    return DateTime(year, month, day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      body: SafeArea(
        child: FutureBuilder<StudentGroupDetails>(
          future: _detailFuture,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final error = snapshot.error;
            final detail = snapshot.data;

            var monthOptions = const <_MonthOption>[];
            Widget content;
            if (isLoading) {
              content = const Center(
                child: CircularProgressIndicator(color: AppTheme.brandColor),
              );
            } else if (error != null || detail == null) {
              content = _ErrorState(
                message: _readErrorMessage(error),
                onRetry: _reload,
              );
            } else {
              monthOptions = _buildMonthOptions(detail);
              final topMates = _topThreeMates(detail.groupmates);
              content = RefreshIndicator(
                onRefresh: _reload,
                color: AppTheme.brandColor,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (topMates.isNotEmpty) ...[
                      _PodiumCard(topMates: topMates),
                      const SizedBox(height: 10),
                    ],
                    _HeroCard(
                      detail: detail,
                      scheduleDays: detail.scheduleDays.isNotEmpty
                          ? detail.scheduleDays
                          : widget.initialScheduleDays,
                      scheduleTime: detail.scheduleTime.trim().isNotEmpty
                          ? detail.scheduleTime
                          : widget.initialScheduleTime,
                    ),
                    const SizedBox(height: 10),
                    _MembersCard(groupmates: detail.groupmates),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Ortga qaytish tugmasi + o'ng tarafida oy tanlash chiplari
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Row(
                    children: [
                      _CircleBackButton(
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: monthOptions.isEmpty
                            ? const SizedBox(height: 36)
                            : _MonthChipsRow(
                                options: monthOptions,
                                selectedKey: _selectedMonth,
                                onSelect: _selectMonth,
                              ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: content),
              ],
            );
          },
        ),
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

/// Ball bo'yicha eng yaxshi 3 talabani aniqlaydi (podium uchun)
List<StudentGroupMate> _topThreeMates(List<StudentGroupMate> groupmates) {
  final sorted = [...groupmates]
    ..sort((a, b) {
      final rankA = a.rankInGroup > 0 ? a.rankInGroup : 1 << 20;
      final rankB = b.rankInGroup > 0 ? b.rankInGroup : 1 << 20;
      if (rankA != rankB) return rankA.compareTo(rankB);
      return b.monthlyPoints.compareTo(a.monthlyPoints);
    });
  return sorted.take(3).toList();
}

/// Minimal guruh ma'lumoti kartasi: nom, o'qituvchi (telefon bilan)
/// va dars kunlari/vaqti — boshqa hech narsa yo'q
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.detail,
    required this.scheduleDays,
    required this.scheduleTime,
  });

  final StudentGroupDetails detail;
  final List<String> scheduleDays;
  final String scheduleTime;

  @override
  Widget build(BuildContext context) {
    final time = scheduleTime.trim();

    return Container(
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
                  detail.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // O'qituvchi va telefoni
          Row(
            children: [
              const Icon(
                Icons.person_rounded,
                size: 14,
                color: Color(0xFF7B8495),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  detail.teacherPhone.isEmpty
                      ? detail.teacherName
                      : '${detail.teacherName} • ${detail.teacherPhone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5A6478),
                  ),
                ),
              ),
            ],
          ),
          // Dars kunlari — faqat dars bor kunlar to'liq nomi bilan
          if (scheduleDays.isNotEmpty) ...[
            const SizedBox(height: 10),
            ActiveScheduleDaysWrap(
              scheduleDays: scheduleDays,
              color: AppTheme.brandColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFDDE3EE)),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          size: 20,
          color: Color(0xFF182033),
        ),
      ),
    );
  }
}

class _MonthOption {
  const _MonthOption({required this.key, required this.label});

  final String key; // YYYY-MM
  final String label;
}

class _MonthChipsRow extends StatelessWidget {
  const _MonthChipsRow({
    required this.options,
    required this.selectedKey,
    required this.onSelect,
  });

  final List<_MonthOption> options;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option.key == selectedKey;
          return GestureDetector(
            onTap: () => onSelect(option.key),
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
                      : const Color(0xFFDDE3EE),
                ),
              ),
              child: Text(
                option.label,
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

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.topMates});

  /// Eng yaxshi natijali talabalar (birinchisi — 1-o'rin), 1-3 ta
  final List<StudentGroupMate> topMates;

  @override
  Widget build(BuildContext context) {
    final first = topMates.isNotEmpty ? topMates[0] : null;
    final second = topMates.length > 1 ? topMates[1] : null;
    final third = topMates.length > 2 ? topMates[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C0A05), Color(0xFFA70E07), Color(0xFFD32F2F)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x337C0A05),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second == null
                ? const SizedBox.shrink()
                : _PodiumColumn(mate: second, place: 2),
          ),
          Expanded(
            child: first == null
                ? const SizedBox.shrink()
                : _PodiumColumn(mate: first, place: 1),
          ),
          Expanded(
            child: third == null
                ? const SizedBox.shrink()
                : _PodiumColumn(mate: third, place: 3),
          ),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({required this.mate, required this.place});

  final StudentGroupMate mate;
  final int place;

  /// O'rin balandligi — 1-o'rin eng yuqorida turadi
  static const Map<int, double> _lifts = {1: 34, 2: 14, 3: 0};
  static const Map<int, Color> _badgeColors = {
    1: Color(0xFFF2A93B),
    2: Color(0xFFBFC5CF),
    3: Color(0xFFCB7A43),
  };

  @override
  Widget build(BuildContext context) {
    final isFirst = place == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst)
          const Text('👑', style: TextStyle(fontSize: 20))
        else
          const SizedBox(height: 24),
        const SizedBox(height: 4),
        // Avatar + pastiga yopishgan medal raqami
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _badgeColors[place]!,
                  width: isFirst ? 2.5 : 2,
                ),
              ),
              child: ProfileAvatar(
                avatarKey: mate.avatarKey.isEmpty ? null : mate.avatarKey,
                avatarUrl: mate.avatarUrl.isEmpty ? null : mate.avatarUrl,
                role: 'student',
                seed: mate.displayName,
                size: isFirst ? 58 : 46,
                showBorder: false,
              ),
            ),
            Positioned(
              bottom: -9,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _badgeColors[place],
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '$place',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Ism-familiya to'liq ko'rinadi — kesilmaydi, kerak bo'lsa 2 qatorga o'tadi
        Text(
          mate.displayName,
          textAlign: TextAlign.center,
          softWrap: true,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${mate.monthlyPoints} ball',
          style: TextStyle(
            fontSize: isFirst ? 14 : 12,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFFE9A8),
          ),
        ),
        SizedBox(height: _lifts[place]),
      ],
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
          Row(
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
                  Icons.groups_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Guruhdoshlar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              Text(
                '${groupmates.length} ta',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A93A5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

  /// Top-3 o'rin uchun medal ranglari: oltin, kumush, bronza
  static const Map<int, Color> _rankColors = {
    1: Color(0xFFD4A017),
    2: Color(0xFF8E9AAB),
    3: Color(0xFFB4691E),
  };

  @override
  Widget build(BuildContext context) {
    final hasRank = mate.rankInGroup > 0;
    final rankColor = _rankColors[mate.rankInGroup] ?? const Color(0xFF4C63D2);

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mate.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF182033),
                        ),
                      ),
                    ),
                    // O'rin pilli — top-3 medal rangida
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: hasRank
                            ? rankColor.withValues(alpha: 0.12)
                            : const Color(0xFFF1F4F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_rankColors.containsKey(mate.rankInGroup)) ...[
                            Icon(
                              Icons.emoji_events_rounded,
                              size: 11,
                              color: rankColor,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            hasRank ? '${mate.rankInGroup}-o\'rin' : '—',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: hasRank
                                  ? rankColor
                                  : const Color(0xFF8A93A5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${mate.monthlyPoints} ball',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFA70E07),
                      ),
                    ),
                    const SizedBox(width: 10),
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
              ],
            ),
          ),
        ],
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
