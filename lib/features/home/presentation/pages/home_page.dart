import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/localization/app_language.dart';
import '../../../auth/models/auth_session.dart';
import '../../../auth/models/auth_user.dart';
import '../../../profile/presentation/avatar_picker_modal.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../student/presentation/student_attendance_page.dart';
import '../../../student/presentation/student_groups_page.dart';
import '../../../student/presentation/student_group_detail_page.dart';
import '../../../student/presentation/student_point_reports_page.dart';
import '../../../student/presentation/student_points_overview_page.dart';
import '../../../student/presentation/student_payments_page.dart';
import '../../../student/data/student_groups_service.dart';
import '../../../student/data/student_payments_service.dart';
import '../../data/home_content_service.dart';
import '../../../../core/services/notification_service.dart';
import '../widgets/home_bottom_navigation.dart';
import '../widgets/home_monthly_progress_chart.dart';
import '../widgets/home_news_carousel.dart';
import '../widgets/home_stories.dart';
import '../widgets/home_progress_card.dart';
import '../widgets/home_report_card.dart';
import 'settings_page.dart';
import '../../../notifications/presentation/notification_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.onSessionUpdated,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;
  final Future<void> Function(AuthSession session) onSessionUpdated;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppText.of(context);
    final user = widget.session.user;
    final displayName = user.fullName.isEmpty ? user.username : user.fullName;
    final firstName = displayName.split(' ').first;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: _TopHeader(
                firstName: firstName,
                user: user,
                session: widget.session,
                onSessionUpdated: widget.onSessionUpdated,
              ),
            ),
          ],
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: switch (_currentIndex) {
              0 => _HomeCenterContent(
                key: const ValueKey('home'),
                session: widget.session,
                onOpenPayments: () => setState(() => _currentIndex = 3),
              ),
              1 => StudentGroupsPage(
                key: const ValueKey('student-groups'),
                session: widget.session,
              ),
              2 => StudentAttendancePage(
                key: const ValueKey('student-attendance'),
                session: widget.session,
              ),
              3 => StudentPaymentsPage(
                key: const ValueKey('student-payments'),
                session: widget.session,
              ),
              4 => SettingsPage(
                key: const ValueKey('settings'),
                session: widget.session,
                onLogout: widget.onLogout,
                onSessionUpdated: widget.onSessionUpdated,
              ),
              _ => _SectionPlaceholderPage(
                key: ValueKey('section-$_currentIndex'),
                title: strings.studentTabTitles[_currentIndex],
              ),
            },
          ),
        ),
      ),
      bottomNavigationBar: HomeBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _currentIndex) return;
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.firstName,
    required this.user,
    required this.session,
    required this.onSessionUpdated,
  });

  final String firstName;
  final AuthUser user;
  final AuthSession session;
  final Future<void> Function(AuthSession session) onSessionUpdated;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D101828),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            ProfileAvatar(
              avatarKey: user.avatarKey,
              avatarUrl: user.avatarUrl,
              role: user.role,
              seed: user.username,
              size: 42,
              onTap: () {
                AvatarPickerModal.show(
                  context: context,
                  session: session,
                  onSessionUpdated: onSessionUpdated,
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF182033),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Joriy oyda to'plangan ball — bosilsa Ballarim sahifasi ochiladi
            _MonthlyPointsChip(session: session),
            const SizedBox(width: 6),
            ValueListenableBuilder<int>(
              valueListenable: NotificationService.instance.unreadCount,
              builder: (context, unreadCount, _) {
                return _TopActionButton(
                  icon: Icons.notifications_active_outlined,
                  badgeCount: unreadCount,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotificationPage(session: session),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Header'dagi joriy oy ball chipi (notification ikonasining chap tarafida).
/// Joriy oyda barcha guruhlar bo'yicha to'plangan umumiy ballni ko'rsatadi,
/// bosilganda "Ballarim" sahifasiga o'tadi va qaytishda qiymatni yangilaydi.
class _MonthlyPointsChip extends StatefulWidget {
  const _MonthlyPointsChip({required this.session});

  final AuthSession session;

  @override
  State<_MonthlyPointsChip> createState() => _MonthlyPointsChipState();
}

class _MonthlyPointsChipState extends State<_MonthlyPointsChip> {
  final StudentGroupsService _service = StudentGroupsService();
  int? _points;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // month berilmasa backend joriy oyni oladi — chip izohida aytilganidek
      // "joriy oyda to'plangan ball" ko'rsatilishi kerak, butun davr emas.
      final reports = await _service.fetchMyPointReports(widget.session);
      final points = reports.summary.totalPoints;
      if (!mounted) return;
      setState(() {
        _points = points;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _points = 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _openOverview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentPointsOverviewPage(session: widget.session),
      ),
    );
    // Sahifadan qaytgach ball o'zgargan bo'lishi mumkin — yangilaymiz
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openOverview,
      child: Container(
        height: 30,
        padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEA4C46), Color(0xFFC81B1B), Color(0xFF8A0B06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.30),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brandColor.withValues(alpha: 0.34),
              blurRadius: 9,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFFF0B8),
                    Color(0xFFFFD45C),
                    Color(0xFFF59E0B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Icon(
                  Icons.star_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 5),
            if (_isLoading)
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: Colors.white,
                ),
              )
            else
              Text(
                '$_points',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeCenterContent extends StatelessWidget {
  const _HomeCenterContent({
    super.key,
    required this.session,
    required this.onOpenPayments,
  });

  final AuthSession session;
  final VoidCallback onOpenPayments;

  @override
  Widget build(BuildContext context) {
    return _HomeFeed(session: session, onOpenPayments: onOpenPayments);
  }
}

class _HomeFeed extends StatefulWidget {
  const _HomeFeed({required this.session, required this.onOpenPayments});

  final AuthSession session;
  final VoidCallback onOpenPayments;

  @override
  State<_HomeFeed> createState() => _HomeFeedState();
}

class _HomeFeedState extends State<_HomeFeed> {
  final StudentGroupsService _groupsService = StudentGroupsService();
  final StudentPaymentsService _paymentsService = StudentPaymentsService();
  final HomeContentService _contentService = HomeContentService();
  late Future<List<StudentGroupSummary>> _groupsFuture;
  late Future<StudentPaymentsResponse> _paymentsFuture;
  late Future<HomeContent> _contentFuture;
  late String _month;
  final ScrollController _groupCardsController = ScrollController();
  final Map<int, Future<StudentGroupDetails>> _groupDetailsCache = {};

  final Set<String> _seenStories = <String>{};

  @override
  void initState() {
    super.initState();
    _groupsFuture = _groupsService.fetchMyGroups(widget.session);
    _contentFuture = _contentService.fetchAll(widget.session);
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _paymentsFuture = _paymentsService.fetchMyPayments(
      widget.session,
      month: _month,
    );
  }

  @override
  void dispose() {
    _groupsService.dispose();
    _paymentsService.dispose();
    _contentService.dispose();
    _groupCardsController.dispose();
    super.dispose();
  }

  /// > tugmasi bosilganda keyingi guruh kartasiga silliq o'tadi
  void _scrollToNextGroupCard(double cardWidth) {
    if (!_groupCardsController.hasClients ||
        !_groupCardsController.position.hasContentDimensions) {
      return;
    }
    final step = cardWidth + 24;
    final currentPage = (_groupCardsController.offset / step).round();
    final target = ((currentPage + 1) * step).clamp(
      0.0,
      _groupCardsController.position.maxScrollExtent,
    );
    _groupCardsController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<StudentGroupDetails> _groupDetailsFor(int groupId) {
    return _groupDetailsCache.putIfAbsent(
      groupId,
      () => _groupsService.fetchMyGroupInfo(
        widget.session,
        groupId,
        month: _month,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<List<StudentGroupSummary>>(
          future: _groupsFuture,
          builder: (context, snapshot) {
            final groups = snapshot.data ?? const <StudentGroupSummary>[];
            final featuredGroups = _featuredGroups(groups);
            final cardWidth = constraints.maxWidth - 24;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Storislar va yangiliklar — admin paneldan boshqariladi
                      FutureBuilder<HomeContent>(
                        future: _contentFuture,
                        builder: (context, contentSnapshot) {
                          final content = contentSnapshot.data;
                          if (content == null) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            children: [
                              if (content.stories.isNotEmpty) ...[
                                SizedBox(
                                  height: 76,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: content.stories.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final story = content.stories[index];
                                      final seen = _seenStories.contains(
                                        story.videoUrl,
                                      );
                                      return StoryCard(
                                        story: story,
                                        seen: seen,
                                        onTap: () async {
                                          setState(() {
                                            _seenStories.add(story.videoUrl);
                                          });
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => StoryViewerPage(
                                                stories: content.stories,
                                                initialIndex: index,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (content.news.isNotEmpty) ...[
                                HomeNewsCarousel(items: content.news),
                                const SizedBox(height: 12),
                              ],
                            ],
                          );
                        },
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: _HomeCardsLoading(),
                        )
                      else if (featuredGroups.isNotEmpty)
                        Stack(
                          children: [
                            // Reyting + kunlik hisobot juftligi birga suriladi.
                            // Keyingi karta ko'rinmaydi — o'ngdagi > belgisi
                            // yana karta borligini bildiradi.
                            SingleChildScrollView(
                              controller: _groupCardsController,
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (
                                    var i = 0;
                                    i < featuredGroups.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const SizedBox(width: 24),
                                    SizedBox(
                                      width: cardWidth,
                                      child: Column(
                                        children: [
                                          HomeProgressCard(
                                            points:
                                                featuredGroups[i].monthlyPoints,
                                            rank: featuredGroups[i].monthlyRank,
                                            subjectName:
                                                featuredGroups[i].subjectName,
                                            groupName:
                                                featuredGroups[i].groupName,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      StudentGroupDetailPage(
                                                        session: widget.session,
                                                        groupId:
                                                            featuredGroups[i]
                                                                .groupId,
                                                        initialScheduleDays:
                                                            featuredGroups[i]
                                                                .scheduleDays,
                                                        initialScheduleTime:
                                                            featuredGroups[i]
                                                                .scheduleTime,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          FutureBuilder<StudentGroupDetails>(
                                            future: _groupDetailsFor(
                                              featuredGroups[i].groupId,
                                            ),
                                            builder: (context, detailSnapshot) {
                                              final detail =
                                                  detailSnapshot.data;
                                              final report =
                                                  detail
                                                          ?.lessonReports
                                                          .isNotEmpty ==
                                                      true
                                                  ? detail!.lessonReports.first
                                                  : null;
                                              return HomeReportCard(
                                                monthLabel:
                                                    _lessonReportDateLabel(
                                                  report,
                                                  fallback: featuredGroups[i]
                                                      .lastPointDate,
                                                ),
                                                homework: report?.homework,
                                                vocabulary: report?.vocabulary,
                                                attendance: report?.attendance,
                                                participation:
                                                    report?.participation,
                                                totalScore: report?.total,
                                                percent: report?.percent,
                                                feedback: report?.feedback,
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          StudentPointReportsPage(
                                                            session:
                                                                widget.session,
                                                            initialGroupId:
                                                                featuredGroups[i]
                                                                    .groupId,
                                                            initialMonth:
                                                                _monthKeyFromLessonDate(
                                                                  report
                                                                      ?.lessonDate,
                                                                ),
                                                          ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (featuredGroups.length > 1)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  // Oxirgi kartaga yetganda tugma yashirinadi
                                  child: AnimatedBuilder(
                                    animation: _groupCardsController,
                                    builder: (context, child) {
                                      // Scroll hali o'lchamlarini olmagan
                                      // bo'lsa maxScrollExtent'ga teginmaymiz
                                      final position =
                                          _groupCardsController.hasClients
                                          ? _groupCardsController.position
                                          : null;
                                      final ready =
                                          position != null &&
                                          position.hasContentDimensions &&
                                          position.hasPixels;
                                      final atEnd =
                                          ready &&
                                          position.pixels >=
                                              position.maxScrollExtent - 4;
                                      return AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        opacity: atEnd ? 0 : 1,
                                        child: IgnorePointer(
                                          ignoring: atEnd,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: GestureDetector(
                                      onTap: () =>
                                          _scrollToNextGroupCard(cardWidth),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFE4E9F1),
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x2E000000),
                                              blurRadius: 10,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 22,
                                          color: Color(0xFF3A4454),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: _HomeCardsEmpty(),
                        ),
                      const SizedBox(height: 12),
                      // Keyingi dars va to'lov holati — kichik juft kartalar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _NextLessonCard(groups: featuredGroups),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PaymentStatusCard(
                                  future: _paymentsFuture,
                                  onTap: widget.onOpenPayments,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Oylik report charti — faqat English guruhlar bo'yicha
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: HomeMonthlyProgressChart(
                          groups: _englishFeaturedGroups(featuredGroups),
                          loadReports: (groupId) =>
                              _groupsService.fetchMyPointReports(
                                widget.session,
                                month: _month,
                                groupId: groupId,
                              ),
                          onTap: () {
                            final reportGroups = _englishFeaturedGroups(
                              featuredGroups,
                            );
                            if (reportGroups.isEmpty) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StudentGroupDetailPage(
                                  session: widget.session,
                                  groupId: reportGroups.first.groupId,
                                  initialScheduleDays:
                                      reportGroups.first.scheduleDays,
                                  initialScheduleTime:
                                      reportGroups.first.scheduleTime,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Bosh sahifada ko'rsatiladigan guruhlar: faol guruhlar hammasi,
  /// faol guruh bo'lmasa — birinchisi (eski xatti-harakat saqlanadi)
  List<StudentGroupSummary> _featuredGroups(List<StudentGroupSummary> groups) {
    if (groups.isEmpty) return const [];
    final active = groups.where((group) => group.isActive).toList();
    if (active.isNotEmpty) return active;
    return [groups.first];
  }

  List<StudentGroupSummary> _englishFeaturedGroups(
    List<StudentGroupSummary> groups,
  ) {
    final english = groups
        .where((group) => group.subjectName.trim().toLowerCase() == 'english')
        .toList();
    return english.isNotEmpty ? english : groups;
  }
}

/// Keyingi dars kartasi — har bir guruh (fan) uchun eng yaqin dars kunini
/// jadvaldan hisoblab ko'rsatadi
class _NextLessonCard extends StatelessWidget {
  const _NextLessonCard({required this.groups});

  final List<StudentGroupSummary> groups;

  static const Map<String, int> _uzDayToWeekday = {
    'dushanba': DateTime.monday,
    'seshanba': DateTime.tuesday,
    'chorshanba': DateTime.wednesday,
    'payshanba': DateTime.thursday,
    'juma': DateTime.friday,
    'shanba': DateTime.saturday,
    'yakshanba': DateTime.sunday,
  };

  static const List<String> _shortMonths = [
    'yan',
    'fev',
    'mar',
    'apr',
    'may',
    'iyn',
    'iyl',
    'avg',
    'sen',
    'okt',
    'noy',
    'dek',
  ];

  /// Guruh jadvalidan bugundan boshlab eng yaqin dars kunini topadi
  static String? _nextLessonLabel(StudentGroupSummary group) {
    if (group.scheduleDays.isEmpty) return null;
    final weekdays = group.scheduleDays
        .map((day) => _uzDayToWeekday[day.trim().toLowerCase()])
        .whereType<int>()
        .toSet();
    if (weekdays.isEmpty) return null;

    final now = DateTime.now();
    for (var offset = 0; offset < 7; offset++) {
      final date = now.add(Duration(days: offset));
      if (!weekdays.contains(date.weekday)) continue;
      if (offset == 0) return 'Bugun';
      if (offset == 1) return 'Ertaga';
      const names = [
        'Dushanba',
        'Seshanba',
        'Chorshanba',
        'Payshanba',
        'Juma',
        'Shanba',
        'Yakshanba',
      ];
      return '${names[date.weekday - 1]}, '
          '${date.day}-${_shortMonths[date.month - 1]}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // (fan, kun, vaqt) — kun va vaqt alohida qatorlarda, matn kesilmaydi
    final rows = <(String, String, String)>[];
    for (final group in groups) {
      final label = _nextLessonLabel(group);
      if (label != null) {
        rows.add((group.subjectName, label, group.scheduleTime.trim()));
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4E9F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            bottom: -16,
            child: Transform.rotate(
              angle: -0.18,
              child: Icon(
                Icons.calendar_month_rounded,
                size: 76,
                color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
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
                          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.event_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Keyingi dars',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF182033),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  const Text(
                    'Dars jadvali belgilanmagan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A93A5),
                    ),
                  )
                else
                  for (final row in rows) ...[
                    Text(
                      row.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF182033),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.event_available_rounded,
                          size: 12,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            row.$2,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5A6478),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (row.$3.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF4F46E5,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: Color(0xFF4F46E5),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                row.$3,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (row != rows.last) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0xFFEDF1F7)),
                      const SizedBox(height: 8),
                    ],
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// To'lov holati kartasi — joriy oy bo'yicha qancha to'lash kerakligi va holat.
/// Bosilganda to'lovlar sahifasi (pastki menyudagi To'lovlar) ochiladi.
class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard({required this.future, required this.onTap});

  final Future<StudentPaymentsResponse> future;
  final VoidCallback onTap;

  static String _money(double value) {
    final text = value.toStringAsFixed(0);
    final parts = <String>[];
    for (var i = text.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      parts.insert(0, text.substring(start, i));
    }
    return '${parts.join(' ')} so\'m';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE4E9F1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              bottom: -16,
              child: Transform.rotate(
                angle: 0.18,
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 76,
                  color: const Color(0xFF0F766E).withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
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
                            colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'To\'lov holati',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF182033),
                          ),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F4F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: Color(0xFF6B7386),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<StudentPaymentsResponse>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text(
                          'Yuklanmoqda...',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A93A5),
                          ),
                        );
                      }
                      final summary = snapshot.data?.summary;
                      if (snapshot.error != null || summary == null) {
                        return const Text(
                          'Ma\'lumot yuklanmadi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A93A5),
                          ),
                        );
                      }

                      final debt = summary.totalDebt;
                      final paid = summary.totalPaid;
                      final String statusText;
                      final Color statusColor;
                      if (summary.totalRequired <= 0) {
                        statusText = 'To\'lov belgilanmagan';
                        statusColor = const Color(0xFF8A93A5);
                      } else if (debt <= 0) {
                        statusText = 'To\'langan';
                        statusColor = const Color(0xFF14903B);
                      } else if (paid > 0) {
                        statusText = 'Qisman to\'langan';
                        statusColor = const Color(0xFFB45309);
                      } else {
                        statusText = 'To\'lanmagan';
                        statusColor = const Color(0xFFA70E07);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            debt > 0
                                ? _money(debt)
                                : _money(summary.totalRequired),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF182033),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            debt > 0 ? 'to\'lanishi kerak' : 'oylik to\'lov',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8A93A5),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCardsLoading extends StatelessWidget {
  const _HomeCardsLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 148,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 148,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ],
    );
  }
}

class _HomeCardsEmpty extends StatelessWidget {
  const _HomeCardsEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: const Text(
        'Ball va hisobotlar ko‘rinishi uchun guruh biriktirilishi kerak',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF7B8495),
        ),
      ),
    );
  }
}

/// Oxirgi hisobot sanasi: report bo'lsa uning lesson_date'i,
/// bo'lmasa fallback matnidan sana olinadi.
String _lessonReportDateLabel(
  StudentLessonReport? report, {
  required String fallback,
}) {
  final candidates = <String>[
    if (report != null) report.lessonDate,
    if (report != null) report.createdAtLabel,
    fallback,
  ];
  for (final candidate in candidates) {
    final parsed = _parseReportDate(candidate);
    if (parsed != null) return _dailyDateLabel(parsed);
  }
  return 'Ma\'lumot yo\'q';
}

String? _monthKeyFromLessonDate(String? value) {
  final parsed = _parseReportDate(value ?? '');
  if (parsed == null) return null;
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}';
}

DateTime? _parseReportDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;

  final iso = DateTime.tryParse(text);
  if (iso != null) {
    return DateTime(iso.year, iso.month, iso.day);
  }

  final normalized = text.replaceAll('/', '.');
  final parts = normalized.split('.');
  if (parts.length != 3) return null;
  final first = int.tryParse(parts[0]);
  final second = int.tryParse(parts[1]);
  final third = int.tryParse(parts[2]);
  if (first == null || second == null || third == null) return null;
  if (second < 1 || second > 12) return null;
  if (parts[0].length == 4) {
    return DateTime(first, second, third);
  }
  return DateTime(third, second, first);
}

/// Kunlik hisobot kartasi uchun to'liq sana: "payshanba, 10-iyul 2026"
String _dailyDateLabel(DateTime date) {
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
  const weekdays = [
    'dushanba',
    'seshanba',
    'chorshanba',
    'payshanba',
    'juma',
    'shanba',
    'yakshanba',
  ];
  final weekday = weekdays[date.weekday - 1];
  return '$weekday, ${date.day}-${months[date.month - 1]} ${date.year}';
}

class _SectionPlaceholderPage extends StatelessWidget {
  const _SectionPlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF182033),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hozircha bo‘lim sahifasi',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7B8497),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            icon: Icon(icon, color: const Color(0xFF182033), size: 22),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: 7,
            top: 7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.brandColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : badgeCount.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
