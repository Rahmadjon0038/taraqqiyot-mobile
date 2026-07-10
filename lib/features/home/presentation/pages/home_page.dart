import 'dart:async';

import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../auth/models/auth_session.dart';
import '../../../auth/models/auth_user.dart';
import '../../../profile/presentation/avatar_picker_modal.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../student/presentation/student_attendance_page.dart';
import '../../../student/presentation/student_groups_page.dart';
import '../../../student/presentation/student_group_detail_page.dart';
import '../../../student/presentation/student_point_reports_page.dart';
import '../../../student/presentation/student_payments_page.dart';
import '../../../student/data/student_groups_service.dart';
import '../../../student/data/student_payments_service.dart';
import '../../../../core/services/notification_service.dart';
import '../widgets/home_bottom_navigation.dart';
import '../widgets/home_news_carousel.dart';
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

  static const _sectionTitles = [
    'Asosiy',
    'Mening guruhlarim',
    'Davomat',
    "To'lovlarim",
    'Sozlamalar',
  ];

  @override
  Widget build(BuildContext context) {
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
                title: _sectionTitles[_currentIndex],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
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
              size: 48,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF182033),
                ),
              ),
            ),
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
  late Future<List<StudentGroupSummary>> _groupsFuture;
  late Future<StudentPaymentsResponse> _paymentsFuture;
  final ScrollController _groupCardsController = ScrollController();

  static const List<_StoryData> _stories = [
    _StoryData(
      title: 'Kraven',
      assetPath: 'assets/kraven.mp4',
      accentStart: Color(0xFF38E0A3),
      accentEnd: Color(0xFF1FB6FF),
    ),
    _StoryData(
      title: 'Car 1',
      assetPath: 'assets/car1.mp4',
      accentStart: Color(0xFF58D68D),
      accentEnd: Color(0xFF2E86DE),
    ),
    _StoryData(
      title: 'Edit',
      assetPath: 'assets/edit.mp4',
      accentStart: Color(0xFF7F7CFF),
      accentEnd: Color(0xFF3CC8A8),
    ),
    _StoryData(
      title: 'Trent',
      assetPath: 'assets/trent.mp4',
      accentStart: Color(0xFFFFC857),
      accentEnd: Color(0xFFFF7A59),
    ),
    _StoryData(
      title: 'Enolla',
      assetPath: 'assets/enolla.mp4',
      accentStart: Color(0xFF4FD1C5),
      accentEnd: Color(0xFF22C55E),
    ),
    _StoryData(
      title: 'Kraven 2',
      assetPath: 'assets/kraven2.mp4',
      accentStart: Color(0xFF8B5CF6),
      accentEnd: Color(0xFFEC4899),
    ),
  ];

  final Set<String> _seenStories = <String>{};

  @override
  void initState() {
    super.initState();
    _groupsFuture = _groupsService.fetchMyGroups(widget.session);
    final now = DateTime.now();
    _paymentsFuture = _paymentsService.fetchMyPayments(
      widget.session,
      month: '${now.year}-${now.month.toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _groupsService.dispose();
    _paymentsService.dispose();
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
    final target = ((currentPage + 1) * step)
        .clamp(0.0, _groupCardsController.position.maxScrollExtent);
    _groupCardsController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
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
                      SizedBox(
                        height: 98,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          scrollDirection: Axis.horizontal,
                          itemCount: _stories.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final story = _stories[index];
                            final seen = _seenStories.contains(story.assetPath);
                            return _StoryCard(
                              story: story,
                              seen: seen,
                              onTap: () async {
                                setState(() {
                                  _seenStories.add(story.assetPath);
                                });
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => _StoryViewerPage(
                                      stories: _stories,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                                if (!mounted) return;
                                setState(() {
                                  _seenStories.add(story.assetPath);
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Yangiliklar karuseli — hozircha mock, keyin API'ga ulanadi
                      const HomeNewsCarousel(),
                      const SizedBox(height: 12),
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
                                  horizontal: 12),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  for (var i = 0;
                                      i < featuredGroups.length;
                                      i++) ...[
                                    if (i > 0)
                                      const SizedBox(width: 24),
                                    SizedBox(
                                      width: cardWidth,
                                      child: Column(
                                        children: [
                                          HomeProgressCard(
                                            points: featuredGroups[i]
                                                .monthlyPoints,
                                            rank: featuredGroups[i]
                                                .monthlyRank,
                                            subjectName:
                                                featuredGroups[i]
                                                    .subjectName,
                                            groupName: featuredGroups[i]
                                                .groupName,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      StudentGroupDetailPage(
                                                    session:
                                                        widget.session,
                                                    groupId:
                                                        featuredGroups[i]
                                                            .groupId,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          HomeReportCard(
                                            summaryText: featuredGroups[
                                                        i]
                                                    .lastPointDate
                                                    .isEmpty
                                                ? 'Hali ball qo‘yilmagan'
                                                : '${featuredGroups[i].lastDayPoints} ball olingan',
                                            monthLabel: _reportDateLabel(
                                                featuredGroups[i]
                                                    .lastPointDate),
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
                                                  ),
                                                ),
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
                                      final position = _groupCardsController
                                              .hasClients
                                          ? _groupCardsController.position
                                          : null;
                                      final ready = position != null &&
                                          position.hasContentDimensions &&
                                          position.hasPixels;
                                      final atEnd = ready &&
                                          position.pixels >=
                                              position.maxScrollExtent - 4;
                                      return AnimatedOpacity(
                                        duration: const Duration(
                                            milliseconds: 180),
                                        opacity: atEnd ? 0 : 1,
                                        child: IgnorePointer(
                                          ignoring: atEnd,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: GestureDetector(
                                      onTap: () => _scrollToNextGroupCard(
                                          cardWidth),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        margin: const EdgeInsets.only(
                                            right: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                const Color(0xFFE4E9F1),
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
                                child:
                                    _NextLessonCard(groups: featuredGroups),
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
    'yan', 'fev', 'mar', 'apr', 'may', 'iyn',
    'iyl', 'avg', 'sen', 'okt', 'noy', 'dek',
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
        'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba',
        'Juma', 'Shanba', 'Yakshanba',
      ];
      return '${names[date.weekday - 1]}, '
          '${date.day}-${_shortMonths[date.month - 1]}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    for (final group in groups) {
      final label = _nextLessonLabel(group);
      if (label != null) {
        final time = group.scheduleTime.isEmpty ? '' : ' ${group.scheduleTime}';
        rows.add((group.subjectName, '$label$time'));
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFFBEAE9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_rounded,
                  size: 15,
                  color: AppTheme.brandColor,
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
          const SizedBox(height: 8),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF3A4454),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                row.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7B8495),
                ),
              ),
              if (row != rows.last) const SizedBox(height: 6),
            ],
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4E9F1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBEAE9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    size: 15,
                    color: AppTheme.brandColor,
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
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Color(0xFF9AA2B2),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                      debt > 0 ? _money(debt) : _money(summary.totalRequired),
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
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryData {
  const _StoryData({
    required this.title,
    required this.assetPath,
    required this.accentStart,
    required this.accentEnd,
  });

  final String title;
  final String assetPath;
  final Color accentStart;
  final Color accentEnd;
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
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 148,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.circular(18),
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

/// Kunlik hisobot sanasi: oxirgi ball qo'yilgan kun bo'yicha yozuv.
/// Bugun ball qo'yilgan bo'lsa — "Bugun, ...", oldinroq bo'lsa —
/// "Oxirgi dars: ..." (o'quvchi bugun darsi yo'qligini tushunishi uchun).
/// Sana kelmasa (hali ball yo'q) joriy oy ko'rsatiladi.
String _reportDateLabel(String lastPointDate) {
  final parsed = _parseDdMmYyyyDate(lastPointDate);
  if (parsed == null) return _dailyDateLabel(DateTime.now());

  final now = DateTime.now();
  final isToday = parsed.year == now.year &&
      parsed.month == now.month &&
      parsed.day == now.day;
  if (isToday) return 'Bugun, ${_dailyDateLabel(parsed)}';
  return 'Oxirgi dars: ${_dailyDateLabel(parsed)}';
}

DateTime? _parseDdMmYyyyDate(String value) {
  final parts = value.trim().replaceAll('/', '.').split('.');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12) return null;
  return DateTime(year, month, day);
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

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.seen,
    required this.onTap,
  });

  final _StoryData story;
  final bool seen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColors = seen
        ? const [Color(0xFFB8C0CC), Color(0xFF7F8A98)]
        : [story.accentStart, story.accentEnd];

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: ringColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ringColors.first.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0F172A),
                ),
                child: _StoryPreviewFrame(assetPath: story.assetPath),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              story.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: seen ? FontWeight.w600 : FontWeight.w800,
                color: seen ? const Color(0xFF667085) : const Color(0xFF182033),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryPreviewFrame extends StatefulWidget {
  const _StoryPreviewFrame({required this.assetPath});

  final String assetPath;

  @override
  State<_StoryPreviewFrame> createState() => _StoryPreviewFrameState();
}

class _StoryPreviewFrameState extends State<_StoryPreviewFrame> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = _controller;
      if (controller == null) return;

      await controller.initialize();
      await controller.seekTo(Duration.zero);
      await controller.pause();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const ColoredBox(color: Color(0xFF111827));
    }

    if (_errorMessage != null || !controller.value.isInitialized) {
      return const ColoredBox(color: Color(0xFF111827));
    }

    final size = controller.value.size;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.width > 0 ? size.width : 1,
        height: size.height > 0 ? size.height : 1,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _StoryViewerPage extends StatefulWidget {
  const _StoryViewerPage({required this.stories, required this.initialIndex});

  final List<_StoryData> stories;
  final int initialIndex;

  @override
  State<_StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<_StoryViewerPage> {
  static const String _telegramUrl = 'https://t.me/taraqqiyot_namangan_rasmiy';
  static const String _instagramUrl =
      'https://www.instagram.com/taraqqiyot_namangan/';

  VideoPlayerController? _controller;
  late int _currentIndex;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showControls = true;
  bool _showFollowOverlay = false;
  bool _autoAdvanceTriggered = false;
  Timer? _controlsHideTimer;

  Future<void> _openExternalLink(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Havola ochilmasa jim o'tamiz — storis ko'rishni buzmaydi
    }
  }

  _StoryData get _currentStory => widget.stories[_currentIndex];
  bool get _hasPreviousStory => _currentIndex > 0;
  bool get _hasNextStory => _currentIndex < widget.stories.length - 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _initialize();
  }

  Future<void> _initialize() async {
    _cancelControlsHideTimer();
    final previousController = _controller;
    _controller = null;
    await previousController?.dispose();
    final controller = VideoPlayerController.asset(_currentStory.assetPath);
    _controller = controller;

    _autoAdvanceTriggered = false;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _showControls = true;
        _showFollowOverlay = false;
      });
    }

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1.0);
      controller.addListener(() {
        if (!mounted || _controller != controller) return;
        final value = controller.value;
        final ended =
            value.isInitialized &&
            value.duration > Duration.zero &&
            value.position >= value.duration &&
            !value.isPlaying;
        if (ended && !_autoAdvanceTriggered) {
          _autoAdvanceTriggered = true;
          if (_hasNextStory) {
            // Video tugagach avtomatik keyingi storisga o'tamiz
            _switchStory(1);
          } else if (!_showFollowOverlay) {
            // Oxirgi storis tugaganda "Bizni kuzatib boring" oynasini ochamiz
            setState(() {
              _showFollowOverlay = true;
            });
          }
        }
      });
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _showControls = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          if (!mounted) return;
          await controller.play();
          _scheduleControlsHide();
        } catch (error) {
          if (!mounted) return;
          setState(() {
            _errorMessage = error.toString();
          });
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _switchStory(int direction) async {
    final nextIndex = _currentIndex + direction;
    if (nextIndex < 0 || nextIndex >= widget.stories.length) return;
    setState(() {
      _currentIndex = nextIndex;
    });
    await _initialize();
  }

  void _cancelControlsHideTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
  }

  void _scheduleControlsHide() {
    _cancelControlsHideTimer();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showControls = false;
      });
    });
  }

  void _showControlsTemporarily() {
    if (!mounted) return;
    setState(() {
      _showControls = true;
    });
    _scheduleControlsHide();
  }

  @override
  void dispose() {
    _cancelControlsHideTimer();
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildStoryProgressSegment(
    int index,
    VideoPlayerController? controller,
  ) {
    const double barHeight = 3;
    final BorderRadius radius = BorderRadius.circular(2);
    final Color trackColor = Colors.white.withValues(alpha: 0.28);

    // Ko'rib bo'lingan storislar to'liq oq, keyingilari xira chiziq
    if (index != _currentIndex) {
      return Container(
        height: barHeight,
        decoration: BoxDecoration(
          color: index < _currentIndex ? Colors.white : trackColor,
          borderRadius: radius,
        ),
      );
    }

    if (controller == null) {
      return Container(
        height: barHeight,
        decoration: BoxDecoration(color: trackColor, borderRadius: radius),
      );
    }

    // Joriy storis — video pozitsiyasiga qarab to'ladi
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.value;
        double progress = 0;
        if (value.isInitialized && value.duration.inMilliseconds > 0) {
          progress = (value.position.inMilliseconds /
                  value.duration.inMilliseconds)
              .clamp(0.0, 1.0);
        }
        return Container(
          height: barHeight,
          decoration: BoxDecoration(color: trackColor, borderRadius: radius),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: radius,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final controller = _controller;

            return GestureDetector(
              // Chapga surish — keyingi storis, o'ngga surish — oldingisi
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -150) {
                  _switchStory(1);
                } else if (velocity > 150) {
                  _switchStory(-1);
                }
              },
              child: Stack(
              children: [
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0xFF050816)),
                      if (!_isLoading &&
                          _errorMessage == null &&
                          controller != null &&
                          controller.value.isInitialized)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _showControlsTemporarily();
                          },
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: controller.value.aspectRatio > 0
                                  ? controller.value.aspectRatio
                                  : 9 / 16,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  VideoPlayer(controller),
                                  if (_showControls)
                                    Positioned(
                                      left: 12,
                                      right: 12,
                                      bottom: 14,
                                      child: _StoryControlsBar(
                                        controller: controller,
                                        onUserAction: _showControlsTemporarily,
                                        onPlayPause: () {
                                          setState(() {
                                            if (controller.value.isPlaying) {
                                              controller.pause();
                                            } else {
                                              final ended =
                                                  controller.value.position >=
                                                  controller.value.duration;
                                              if (ended) {
                                                controller.seekTo(
                                                  Duration.zero,
                                                );
                                              }
                                              controller.play();
                                            }
                                          });
                                          _showControlsTemporarily();
                                        },
                                        onToggleMute: () {
                                          setState(() {
                                            final isMuted =
                                                controller.value.volume == 0;
                                            controller.setVolume(
                                              isMuted ? 1.0 : 0.0,
                                            );
                                          });
                                          _showControlsTemporarily();
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                    ],
                  ),
                ),
                if (_hasPreviousStory)
                  Positioned(
                    left: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _StorySideButton(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => _switchStory(-1),
                      ),
                    ),
                  ),
                if (_hasNextStory)
                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _StorySideButton(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => _switchStory(1),
                      ),
                    ),
                  ),
                if (_showFollowOverlay)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.85),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              image: const DecorationImage(
                                image: AssetImage('assets/logo.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Bizni kuzatib boring!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SocialCircleButton(
                                icon: FontAwesomeIcons.instagram,
                                gradient: const LinearGradient(
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                  colors: [
                                    Color(0xFF515BD4),
                                    Color(0xFF8134AF),
                                    Color(0xFFDD2A7B),
                                    Color(0xFFF58529),
                                  ],
                                ),
                                onTap: () =>
                                    _openExternalLink(_instagramUrl),
                              ),
                              const SizedBox(width: 28),
                              _SocialCircleButton(
                                icon: FontAwesomeIcons.telegram,
                                color: const Color(0xFF229ED9),
                                onTap: () =>
                                    _openExternalLink(_telegramUrl),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Segmentli progress: har bir storis uchun bitta chiziq
                      Row(
                        children: [
                          for (int i = 0; i < widget.stories.length; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Expanded(
                              child: _buildStoryProgressSegment(i, controller),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              // Logo va nom bosilganda Instagram sahifamiz ochiladi
                              onTap: () => _openExternalLink(_instagramUrl),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        width: 1.5,
                                      ),
                                      image: const DecorationImage(
                                        image: AssetImage('assets/logo.png'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Flexible(
                                    child: Text(
                                      'Taraqqiyot teaching center',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x99000000),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            splashRadius: 22,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 24,
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
          },
        ),
      ),
    );
  }
}

class _SocialCircleButton extends StatelessWidget {
  const _SocialCircleButton({
    required this.icon,
    required this.onTap,
    this.color,
    this.gradient,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: gradient == null ? color : null,
          gradient: gradient,
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: FaIcon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

class _StorySideButton extends StatelessWidget {
  const _StorySideButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.44),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white, size: 34),
        ),
      ),
    );
  }
}

class _StoryControlsBar extends StatelessWidget {
  const _StoryControlsBar({
    required this.controller,
    required this.onUserAction,
    required this.onPlayPause,
    required this.onToggleMute,
  });

  final VideoPlayerController controller;
  final VoidCallback onUserAction;
  final VoidCallback onPlayPause;
  final VoidCallback onToggleMute;

  static const Color _accentRed = Color(0xFFE0304E);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isPlaying = controller.value.isPlaying;
        final isMuted = controller.value.volume == 0;
        final duration = controller.value.duration;
        final position = controller.value.position;
        final maxMs = duration.inMilliseconds > 0
            ? duration.inMilliseconds
            : 1;

        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    onUserAction();
                    onPlayPause();
                  },
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: _accentRed,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatDuration(position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6.5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: _accentRed,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: position.inMilliseconds
                        .clamp(0, maxMs)
                        .toDouble(),
                    min: 0,
                    max: maxMs.toDouble(),
                    onChanged: (value) {
                      onUserAction();
                      controller.seekTo(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                padding: EdgeInsets.zero,
                splashRadius: 20,
                onPressed: () {
                  onUserAction();
                  onToggleMute();
                },
                icon: Icon(
                  isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
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
                borderRadius: BorderRadius.circular(999),
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
