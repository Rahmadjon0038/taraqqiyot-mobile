import 'dart:async';

import 'package:flutter/gestures.dart';
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
  PageController? _groupCardsController;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_groupCardsController == null) {
      // Yangiliklar karuseli bilan bir xil formula — karta deyarli
      // to'liq ekranni egallaydi, keyingi karta chekkasi juda ozgina
      // ko'rinadi (bo'sh joy qolmaydi).
      final width = MediaQuery.of(context).size.width;
      final fraction =
          width > 48 ? ((width - 16) / width).clamp(0.5, 1.0) : 0.96;
      _groupCardsController = PageController(
        viewportFraction: fraction.toDouble(),
      );
    }
  }

  @override
  void dispose() {
    _groupsService.dispose();
    _paymentsService.dispose();
    _contentService.dispose();
    _groupCardsController?.dispose();
    super.dispose();
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
                        // Yangiliklar karuseli kabi haqiqiy PageView —
                        // bitta surish aynan bitta keyingi/oldingi
                        // kartaga to'liq o'tkazadi, ikkitasi orasida
                        // qolib ketmaydi. Balandligi karta mazmuniga
                        // qarab avtomatik moslashadi (hisobot yuklanguncha
                        // bir necha kadr davomida o'zgarishi mumkin).
                        _AutoHeightPageView(
                          controller: _groupCardsController!,
                          itemCount: featuredGroups.length,
                          itemBuilder: (context, i) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Column(
                                children: [
                                  HomeProgressCard(
                                    points: featuredGroups[i].monthlyPoints,
                                    rank: featuredGroups[i].monthlyRank,
                                    subjectName: featuredGroups[i].subjectName,
                                    groupName: featuredGroups[i].groupName,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              StudentGroupDetailPage(
                                            session: widget.session,
                                            groupId: featuredGroups[i].groupId,
                                            initialScheduleDays:
                                                featuredGroups[i].scheduleDays,
                                            initialScheduleTime:
                                                featuredGroups[i].scheduleTime,
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
                                      final detail = detailSnapshot.data;
                                      final report =
                                          detail?.lessonReports.isNotEmpty ==
                                                  true
                                              ? detail!.lessonReports.first
                                              : null;
                                      final myRow = _rowForStudent(
                                        report,
                                        widget.session.user.id,
                                      );
                                      final metrics = report == null
                                          ? const <HomeReportMetric>[]
                                          : report.columns
                                              .where(
                                                (column) => column.enabled,
                                              )
                                              .map(
                                                (column) => HomeReportMetric(
                                                  key: column.key,
                                                  label: column.label,
                                                  value: myRow?.valueForColumn(
                                                        column.key,
                                                      ) ??
                                                      0,
                                                  maxValue: column.maxValue,
                                                ),
                                              )
                                              .toList();
                                      return HomeReportCard(
                                        monthLabel: _lessonReportDateLabel(
                                          report,
                                          fallback:
                                              featuredGroups[i].lastPointDate,
                                        ),
                                        metrics: metrics,
                                        totalScore:
                                            myRow?.total ?? report?.total,
                                        percent:
                                            myRow?.percent ?? report?.percent,
                                        feedback:
                                            myRow?.feedback ?? report?.feedback,
                                        gradingEnabled:
                                            report?.gradingEnabled ?? true,
                                        onTap: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  StudentPointReportsPage(
                                                session: widget.session,
                                                initialGroupId:
                                                    featuredGroups[i].groupId,
                                                initialMonth:
                                                    _monthKeyFromLessonDate(
                                                  report?.lessonDate,
                                                ),
                                              ),
                                            ),
                                          );
                                          // Batafsil sahifada
                                          // hisobot o'zgargan bo'lishi
                                          // mumkin — kartani yangilash
                                          // uchun keshni tozalaymiz.
                                          if (mounted) {
                                            setState(() {
                                              _groupDetailsCache.remove(
                                                featuredGroups[i].groupId,
                                              );
                                            });
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: _HomeCardsEmpty(),
                        ),
                      // Bir nechta guruh bo'lsa, qaysi kartada turganini
                      // ko'rsatadigan nuqtalar — surish mumkinligini
                      // yana ham yaqqol qiladi.
                      if (featuredGroups.length > 1) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: AnimatedBuilder(
                            animation: _groupCardsController!,
                            builder: (context, child) {
                              final currentPage =
                                  _groupCardsController!.hasClients
                                      ? (_groupCardsController!.page ?? 0)
                                          .round()
                                          .clamp(0, featuredGroups.length - 1)
                                      : 0;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0;
                                      i < featuredGroups.length;
                                      i++) ...[
                                    if (i > 0) const SizedBox(width: 5),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: i == currentPage ? 16 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: i == currentPage
                                            ? const Color(0xFFA70E07)
                                            : const Color(0xFFC9D0DC),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ],
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
                      // Oylik ballar charti — fan bo'yicha
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: HomeMonthlyProgressChart(
                          groups: _chartFeaturedGroups(featuredGroups),
                          loadReports: (groupId) =>
                              _groupsService.fetchMyPointReports(
                            widget.session,
                            month: _month,
                            groupId: groupId,
                          ),
                          onTapGroup: (group) {
                            if (group == null) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StudentGroupDetailPage(
                                  session: widget.session,
                                  groupId: group.groupId,
                                  initialScheduleDays: group.scheduleDays,
                                  initialScheduleTime: group.scheduleTime,
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

  List<StudentGroupSummary> _chartFeaturedGroups(
    List<StudentGroupSummary> groups,
  ) {
    if (groups.isEmpty) return const [];

    // Bir nechta guruh bir xil fan uchun bo'lsa, chartda fan bo'yicha bitta
    // chip ko'rsatamiz. Faol guruh bo'lsa, o'sha tanlanadi.
    final bySubject = <String, StudentGroupSummary>{};
    for (final group in groups) {
      final key = group.subjectName.trim().isNotEmpty
          ? group.subjectName.trim().toLowerCase()
          : 'group-${group.groupId}';
      final existing = bySubject[key];
      if (existing == null) {
        bySubject[key] = group;
        continue;
      }
      if (_preferChartGroup(existing, group)) {
        bySubject[key] = group;
      }
    }

    return bySubject.values.toList();
  }

  bool _preferChartGroup(
      StudentGroupSummary current, StudentGroupSummary next) {
    if (current.isActive != next.isActive) {
      return next.isActive;
    }

    final currentJoin = DateTime.tryParse(current.myJoinDate);
    final nextJoin = DateTime.tryParse(next.myJoinDate);
    if (currentJoin != null && nextJoin != null && currentJoin != nextJoin) {
      return nextJoin.isAfter(currentJoin);
    }

    final currentCreated = DateTime.tryParse(current.createdDate);
    final nextCreated = DateTime.tryParse(next.createdDate);
    if (currentCreated != null &&
        nextCreated != null &&
        currentCreated != nextCreated) {
      return nextCreated.isAfter(currentCreated);
    }

    return false;
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
                color: const Color(0xFFA70E07).withValues(alpha: 0.06),
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
                          colors: [Color(0xFFA70E07), Color(0xFFDC2626)],
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
                          color: Color(0xFFA70E07),
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
                            0xFFA70E07,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: Color(0xFFA70E07),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                row.$3,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFA70E07),
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
                  color: const Color(0xFFA70E07).withValues(alpha: 0.06),
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
                            colors: [Color(0xFFA70E07), Color(0xFFDC2626)],
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
                      final enrollments = snapshot.data?.enrollments;
                      if (snapshot.error != null || enrollments == null) {
                        return const Text(
                          'Ma\'lumot yuklanmadi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A93A5),
                          ),
                        );
                      }

                      final bySubject = _groupBySubject(enrollments);
                      if (bySubject.isEmpty) {
                        return const Text(
                          'To\'lov belgilanmagan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A93A5),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < bySubject.length; i++) ...[
                            _SubjectPaymentRow(summary: bySubject[i]),
                            if (i < bySubject.length - 1) ...[
                              const SizedBox(height: 8),
                              const Divider(
                                height: 1,
                                color: Color(0xFFEDF1F7),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
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

/// Bitta fan bo'yicha jamlangan to'lov holati (bir fanda bir nechta
/// guruh bo'lsa, summalar qo'shib hisoblanadi).
class _SubjectPaymentSummary {
  const _SubjectPaymentSummary({
    required this.subjectName,
    required this.totalRequired,
    required this.totalPaid,
    required this.totalDebt,
    required this.groupCount,
    required this.stoppedGroupCount,
  });

  final String subjectName;
  final double totalRequired;
  final double totalPaid;
  final double totalDebt;
  final int groupCount;
  final int stoppedGroupCount;

  /// Shu fandagi barcha guruhlar davomatdan to'xtatilgan bo'lsa true —
  /// shunda to'lov holati o'rniga "To'xtatgan" ko'rsatiladi.
  bool get allStopped => groupCount > 0 && stoppedGroupCount == groupCount;
}

/// Talabaning to'lov yozuvlarini (enrollments) fan nomi bo'yicha
/// guruhlab, har bir fan uchun jami kerak/to'langan/qarz summasini
/// hisoblaydi — "To'lov holati" kartasida umumiy summa emas, fanlar
/// kesimida ko'rsatilishi uchun.
List<_SubjectPaymentSummary> _groupBySubject(
  List<StudentPaymentEnrollment> enrollments,
) {
  final order = <String>[];
  final totals = <String, _SubjectPaymentSummary>{};
  for (final enrollment in enrollments) {
    final key = enrollment.subjectName.trim().isNotEmpty
        ? enrollment.subjectName.trim()
        : enrollment.groupName.trim();
    if (key.isEmpty) continue;
    final isStopped = enrollment.monthlyStatus == 'stopped';
    final existing = totals[key];
    if (existing == null) {
      order.add(key);
      totals[key] = _SubjectPaymentSummary(
        subjectName: key,
        totalRequired: enrollment.requiredAmount,
        totalPaid: enrollment.paidAmount,
        totalDebt: enrollment.debtAmount,
        groupCount: 1,
        stoppedGroupCount: isStopped ? 1 : 0,
      );
    } else {
      totals[key] = _SubjectPaymentSummary(
        subjectName: key,
        totalRequired: existing.totalRequired + enrollment.requiredAmount,
        totalPaid: existing.totalPaid + enrollment.paidAmount,
        totalDebt: existing.totalDebt + enrollment.debtAmount,
        groupCount: existing.groupCount + 1,
        stoppedGroupCount: existing.stoppedGroupCount + (isStopped ? 1 : 0),
      );
    }
  }
  return [for (final key in order) totals[key]!];
}

/// "To'lov holati" kartasidagi bitta fan qatori — fan nomi, qarz/oylik
/// summa va holat belgisi.
class _SubjectPaymentRow extends StatelessWidget {
  const _SubjectPaymentRow({required this.summary});

  final _SubjectPaymentSummary summary;

  @override
  Widget build(BuildContext context) {
    final debt = summary.totalDebt;
    final paid = summary.totalPaid;
    final String statusText;
    final Color statusColor;
    if (summary.allStopped) {
      // Guruh(lar) shu oyda davomatdan to'xtatilgan — bu holat
      // to'langan/to'lanmagan belgisidan ustun turadi.
      statusText = 'To\'xtatgan';
      statusColor = const Color(0xFFB45309);
    } else if (summary.totalRequired <= 0) {
      statusText = 'Belgilanmagan';
      statusColor = const Color(0xFF8A93A5);
    } else if (debt <= 0) {
      statusText = 'To\'langan';
      statusColor = const Color(0xFF14903B);
    } else if (paid > 0) {
      statusText = 'Qisman';
      statusColor = const Color(0xFFB45309);
    } else {
      statusText = 'To\'lanmagan';
      statusColor = const Color(0xFFA70E07);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary.subjectName,
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
            Expanded(
              child: Text(
                debt > 0
                    ? _PaymentStatusCard._money(debt)
                    : _PaymentStatusCard._money(summary.totalRequired),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF182033),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Yangiliklar karuseli kabi haqiqiy `PageView`, lekin har bir sahifa
/// (karta) balandligi mazmuniga qarab o'zgarishi mumkin bo'lgan hollar
/// uchun — masalan hisobot kartasi async yuklanguncha balandligi
/// noma'lum. Har bir sahifaning tabiiy balandligi o'lchab olinadi va
/// tashqi konteyner o'sha balandlikka silliq moslashadi.
class _AutoHeightPageView extends StatefulWidget {
  const _AutoHeightPageView({
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
  });

  final PageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_AutoHeightPageView> createState() => _AutoHeightPageViewState();
}

class _AutoHeightPageViewState extends State<_AutoHeightPageView> {
  final Map<int, double> _heights = {};
  int _currentPage = 0;

  void _reportHeight(int index, double height) {
    if (!mounted) return;
    if ((_heights[index] ?? -1) == height) return;
    setState(() => _heights[index] = height);
  }

  @override
  Widget build(BuildContext context) {
    final height = _heights[_currentPage] ?? 420.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: height,
      // Standart holatda faqat barmoq (touch) bilan surish yoqilgan —
      // sichqoncha/trackpad bilan ham ishlashi uchun kengaytiramiz.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: PageView.builder(
          controller: widget.controller,
          itemCount: widget.itemCount,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) {
            return _MeasureSize(
              onChange: (size) => _reportHeight(index, size),
              child: widget.itemBuilder(context, index),
            );
          },
        ),
      ),
    );
  }
}

/// Farzand widgetning TABIIY (parent tomonidan cheklanmagan) balandligini
/// o'lchab, `onChange` orqali xabar beradi — o'zi esa parentning bergan
/// joyiga (masalan PageView sahifasiga) moslashib qoladi.
class _MeasureSize extends StatefulWidget {
  const _MeasureSize({required this.onChange, required this.child});

  final ValueChanged<double> onChange;
  final Widget child;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final GlobalKey _key = GlobalKey();

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        widget.onChange(box.size.height);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _MeasureSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      minHeight: 0,
      maxHeight: double.infinity,
      alignment: Alignment.topCenter,
      child: SizedBox(key: _key, child: widget.child),
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

/// Hisobotdagi qatorlar orasidan joriy studentga tegishlisini topadi —
/// karta shu studentning shaxsiy natijasini ko'rsatishi uchun.
StudentLessonReportRow? _rowForStudent(
  StudentLessonReport? report,
  int studentId,
) {
  if (report == null) return null;
  for (final row in report.rows) {
    if (row.studentId == studentId) return row;
  }
  return null;
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
