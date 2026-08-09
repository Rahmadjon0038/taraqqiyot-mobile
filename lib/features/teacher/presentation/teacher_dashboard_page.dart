import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/navigation/app_route_observer.dart';
import '../../auth/models/auth_session.dart';
import '../../home/data/home_content_service.dart';
import '../../home/presentation/widgets/home_news_carousel.dart';
import '../../home/presentation/widgets/home_stories.dart';
import '../data/teacher_service.dart';
import 'teacher_payments_page.dart';
import 'teacher_statistics_page.dart';
import 'teacher_top_students_page.dart';

/// Teacher bosh sahifasi: storislar, yangiliklar, to'lov statistikasi,
/// ball bo'yicha eng yaxshi o'quvchilar va davomat ko'rsatkichlari.
class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({
    super.key,
    required this.session,
    this.onOpenPayments,
  });

  final AuthSession session;
  final VoidCallback? onOpenPayments;

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage>
    with RouteAware {
  final TeacherService _service = TeacherService();
  final HomeContentService _contentService = HomeContentService();
  late Future<_DashboardData> _dashboardFuture;
  late Future<HomeContent> _contentFuture;
  final Set<String> _seenStories = <String>{};
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
    _contentFuture = _contentService.fetchAll(widget.session);
  }

  @override
  void dispose() {
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }
    _service.dispose();
    _contentService.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && _route != route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  Future<_DashboardData> _loadDashboard() async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // To'lov va davomat ko'rsatkichlari snapshotlardan
    final payments = await _service.fetchPaymentSnapshots(
      widget.session,
      month: month,
      limit: 200,
    );

    // Ball bo'yicha eng yaxshilar — har bir guruhdan guruh kattaligiga
    // qarab ajratiladi (3 tagacha -> 1 ta, 4-5 -> 2 ta, ko'p bo'lsa -> 3 ta)
    final groupTops = <GroupTopStudents>[];
    List<TeacherGroup> groups = const <TeacherGroup>[];
    try {
      groups = await _service.fetchMyGroups(widget.session);
      final details = await Future.wait(
        groups.map(
          (group) => _service
              .fetchGroupDetail(widget.session, group.id)
              .then<TeacherGroupDetail?>((detail) => detail)
              .catchError((_) => null),
        ),
      );
      for (final detail in details) {
        if (detail == null) continue;
        groupTops.add(buildGroupTop(detail));
      }
    } catch (_) {
      // Guruhlar yuklanmasa ball bo'limi bo'sh qoladi
    }

    return _DashboardData(
      paymentSummary: payments.summary,
      snapshots: payments.snapshots,
      groups: groups,
      groupTops: groupTops,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _dashboardFuture = _loadDashboard();
      _contentFuture = _contentService.fetchAll(widget.session);
    });
    await _dashboardFuture;
  }

  @override
  void didPopNext() {
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: AppTheme.brandColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Storislar va yangiliklar — admin paneldan boshqariladi
          FutureBuilder<HomeContent>(
            future: _contentFuture,
            builder: (context, contentSnapshot) {
              final content = contentSnapshot.data;
              if (content == null) return const SizedBox.shrink();
              return Column(
                children: [
                  if (content.stories.isNotEmpty) ...[
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: content.stories.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final story = content.stories[index];
                          final seen = _seenStories.contains(story.videoUrl);
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
                    const SizedBox(height: 14),
                  ],
                  if (content.news.isNotEmpty) ...[
                    // Yangiliklar karuseli — chetki masofa karusel ichida
                    HomeNewsCarousel(items: content.news),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FutureBuilder<_DashboardData>(
              future: _dashboardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.brandColor,
                      ),
                    ),
                  );
                }
                final data = snapshot.data;
                if (snapshot.hasError || data == null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Center(
                      child: Column(
                        children: [
                          const Text(
                            'Statistika yuklanmadi',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _reload,
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TeacherDailyStatisticsCard(
                      groups: data.groups,
                      onOpen: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TeacherStatisticsPage(session: widget.session),
                          ),
                        );
                      },
                      onOpenGroup: (groupId) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TeacherStatisticsPage(
                              session: widget.session,
                              initialGroupId: groupId,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _PaymentStatsCard(
                      summary: data.paymentSummary,
                      onTap: () {
                        if (widget.onOpenPayments != null) {
                          widget.onOpenPayments!.call();
                          return;
                        }

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TeacherPaymentsPage(
                              session: widget.session,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (data.groupTops.any(
                      (groupTop) => groupTop.students.isNotEmpty,
                    )) ...[
                      _TopStudentsCard(
                        groupTops: data.groupTops,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TeacherTopStudentsPage(
                                session: widget.session,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    _AttendanceStatsCard(snapshots: data.snapshots),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.paymentSummary,
    required this.snapshots,
    required this.groups,
    required this.groupTops,
  });

  final TeacherPaymentsSummary paymentSummary;
  final List<PaymentSnapshot> snapshots;
  final List<TeacherGroup> groups;
  final List<GroupTopStudents> groupTops;
}

/// To'lov statistikasi — necha foiz o'quvchi to'lagan
class _PaymentStatsCard extends StatelessWidget {
  const _PaymentStatsCard({
    required this.summary,
    required this.onTap,
  });

  final TeacherPaymentsSummary summary;
  final VoidCallback onTap;

  static const _paidColor = Colors.white;
  static const _partialColor = Color(0xFFFFC857);
  static const _unpaidColor = Color(0x59FFFFFF);

  @override
  Widget build(BuildContext context) {
    final total = summary.totalStudents;
    final paidRatio = total > 0 ? summary.paidStudents / total : 0.0;
    final percent = (paidRatio * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
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
                  Icons.pie_chart_rounded,
                  size: 96,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Bu oy to\'lovlar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _StatPill(label: 'Jami: $total'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 30,
                                  startDegreeOffset: -90,
                                  sections: total == 0
                                      ? [
                                          PieChartSectionData(
                                            value: 1,
                                            color: _unpaidColor,
                                            radius: 14,
                                            showTitle: false,
                                          ),
                                        ]
                                      : [
                                          if (summary.paidStudents > 0)
                                            PieChartSectionData(
                                              value: summary.paidStudents
                                                  .toDouble(),
                                              color: _paidColor,
                                              radius: 16,
                                              showTitle: false,
                                            ),
                                          if (summary.partialStudents > 0)
                                            PieChartSectionData(
                                              value: summary.partialStudents
                                                  .toDouble(),
                                              color: _partialColor,
                                              radius: 14,
                                              showTitle: false,
                                            ),
                                          if (summary.unpaidStudents > 0)
                                            PieChartSectionData(
                                              value: summary.unpaidStudents
                                                  .toDouble(),
                                              color: _unpaidColor,
                                              radius: 14,
                                              showTitle: false,
                                            ),
                                        ],
                                ),
                              ),
                              Text(
                                '$percent%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LegendRow(
                                color: _paidColor,
                                label: 'To\'lagan',
                                value: summary.paidStudents,
                              ),
                              if (summary.partialStudents > 0) ...[
                                const SizedBox(height: 6),
                                _LegendRow(
                                  color: _partialColor,
                                  label: 'Qisman',
                                  value: summary.partialStudents,
                                ),
                              ],
                              const SizedBox(height: 6),
                              _LegendRow(
                                color: _unpaidColor,
                                label: 'To\'lamagan',
                                value: summary.unpaidStudents,
                              ),
                            ],
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

/// Pie chart legendasi: rangli nuqta + nom + son
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Oyning eng yaxshi o'quvchilari — har bir guruhdan guruh kattaligiga
/// qarab 1-3 tadan. Bosilganda oy filtri bilan alohida sahifa ochiladi.
class _TopStudentsCard extends StatelessWidget {
  const _TopStudentsCard({required this.groupTops, required this.onTap});

  final List<GroupTopStudents> groupTops;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sections = groupTops
        .where((groupTop) => groupTop.students.isNotEmpty)
        .toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4A017), Color(0xFFF0C24B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Oyning eng yaxshi o\'quvchilari',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF182033),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFF9AA2B2),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var s = 0; s < sections.length; s++) ...[
                if (sections.length > 1) ...[
                  Text(
                    sections[s].groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7B8495),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                for (var i = 0; i < sections[s].students.length; i++) ...[
                  TopStudentRow(student: sections[s].students[i], rank: i),
                  if (i < sections[s].students.length - 1) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFEDF1F7)),
                    const SizedBox(height: 8),
                  ],
                ],
                if (s < sections.length - 1) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFE4E9F1)),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Davomat ko'rsatkichlari: ikkita alohida karta —
/// "Eng yaxshi davomat" (yashil) va "Ko'p dars qoldirganlar" (qizil)
class _AttendanceStatsCard extends StatelessWidget {
  const _AttendanceStatsCard({required this.snapshots});

  final List<PaymentSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    // Faqat davomat qilingan (belgilangan) darslar hisobga olinadi —
    // hali belgilanmagan kunlar "qoldirilgan" deb sanalmaydi
    final withLessons = snapshots.where((s) => s.markedLessons > 0).toList();

    final best = [...withLessons]
      ..sort((a, b) {
        final byPercent = (b.attendedMarkedLessons / b.markedLessons).compareTo(
          a.attendedMarkedLessons / a.markedLessons,
        );
        if (byPercent != 0) return byPercent;
        return b.attendedMarkedLessons.compareTo(a.attendedMarkedLessons);
      });

    final mostMissed =
        withLessons.where((s) => s.missedMarkedLessons > 0).toList()..sort(
          (a, b) => b.missedMarkedLessons.compareTo(a.missedMarkedLessons),
        );

    if (withLessons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (best.isNotEmpty)
          _AttendanceListCard(
            title: 'Eng yaxshi davomat',
            icon: Icons.how_to_reg_rounded,
            gradientColors: const [Color(0xFF0F766E), Color(0xFF2DD4BF)],
            accentColor: const Color(0xFF16934F),
            items: [
              for (final item in best.take(3))
                (
                  item,
                  '${(item.attendedMarkedLessons / item.markedLessons * 100).round()}% • '
                      '${item.attendedMarkedLessons}/${item.markedLessons}',
                ),
            ],
          ),
        if (best.isNotEmpty && mostMissed.isNotEmpty)
          const SizedBox(height: 12),
        if (mostMissed.isNotEmpty)
          _AttendanceListCard(
            title: 'Ko\'p dars qoldirganlar',
            icon: Icons.event_busy_rounded,
            gradientColors: const [Color(0xFFB91C1C), Color(0xFFF87171)],
            accentColor: const Color(0xFFDC2626),
            items: [
              for (final item in mostMissed.take(3))
                (item, '${item.missedMarkedLessons} dars qoldirgan'),
            ],
          ),
      ],
    );
  }
}

/// Bitta davomat ro'yxati kartasi: sarlavha + o'rin raqami bilan qatorlar
class _AttendanceListCard extends StatelessWidget {
  const _AttendanceListCard({
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.accentColor,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final Color accentColor;

  /// (snapshot, o'ng tomondagi yorliq matni)
  final List<(PaymentSnapshot, String)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            _AttendanceRow(
              position: i + 1,
              snapshot: items[i].$1,
              trailing: items[i].$2,
              color: accentColor,
            ),
            if (i < items.length - 1) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFEDF1F7)),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.position,
    required this.snapshot,
    required this.trailing,
    required this.color,
  });

  final int position;
  final PaymentSnapshot snapshot;
  final String trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // O'rin raqami
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$position',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF182033),
                ),
              ),
              Text(
                snapshot.groupName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7B8495),
                ),
              ),
              if (snapshot.studentPhone.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.call_rounded,
                      size: 10.5,
                      color: Color(0xFF7B8495),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        snapshot.studentPhone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7B8495),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            trailing,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
