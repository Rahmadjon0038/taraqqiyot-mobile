import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../auth/models/auth_session.dart';
import '../../home/data/home_content_service.dart';
import '../../home/presentation/widgets/home_news_carousel.dart';
import '../../home/presentation/widgets/home_stories.dart';
import '../data/super_admin_service.dart';
import 'super_admin_unassigned_students_page.dart';

/// Super admin bosh sahifasi: storislar (+ yuklash), yangiliklar,
/// oylik KPI kartalari, moliyaviy taqsimot charti va fanlar tahlili.
class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  final SuperAdminService _service = SuperAdminService();
  final HomeContentService _contentService = HomeContentService();

  late Future<SuperAdminDashboard> _dashboardFuture;
  late Future<SnapshotSummary> _snapshotSummaryFuture;
  late Future<List<TeacherMonthPayments>> _teacherPaymentsFuture;
  late Future<HomeContent> _contentFuture;
  late String _month;
  late List<String> _months;
  final Set<String> _seenStories = <String>{};
  bool _uploadingStory = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _months = [_month];
    _dashboardFuture = _service.fetchDashboard(widget.session, month: _month);
    _snapshotSummaryFuture = _service.fetchSnapshotSummary(
      widget.session,
      month: _month,
    );
    _teacherPaymentsFuture = _service.fetchTeacherMonthlyPayments(
      widget.session,
      month: _month,
    );
    _contentFuture = _contentService.fetchAll(widget.session);
    _loadMonths();
  }

  /// Oy ro'yxati tizim ish boshlagan oydan boshlanadi
  Future<void> _loadMonths() async {
    final start = await _service.fetchSystemStartMonth(widget.session);
    if (!mounted) return;
    setState(() {
      _months = SuperAdminService.monthsFrom(start);
    });
  }

  @override
  void dispose() {
    _service.dispose();
    _contentService.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _dashboardFuture = _service.fetchDashboard(widget.session, month: _month);
      _snapshotSummaryFuture = _service.fetchSnapshotSummary(
        widget.session,
        month: _month,
      );
      _teacherPaymentsFuture = _service.fetchTeacherMonthlyPayments(
        widget.session,
        month: _month,
      );
      _contentFuture = _contentService.fetchAll(widget.session);
    });
    await _dashboardFuture;
  }

  void _selectMonth(String month) {
    if (month == _month) return;
    setState(() {
      _month = month;
      _dashboardFuture = _service.fetchDashboard(widget.session, month: month);
      _snapshotSummaryFuture = _service.fetchSnapshotSummary(
        widget.session,
        month: month,
      );
      _teacherPaymentsFuture = _service.fetchTeacherMonthlyPayments(
        widget.session,
        month: month,
      );
    });
  }

  /// Telefondan video tanlab storis yuklash
  Future<void> _uploadStory() async {
    if (_uploadingStory) return;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video);
      final file = result?.files.single;
      if (file == null || file.path == null) return;

      setState(() => _uploadingStory = true);
      await _contentService.uploadStory(
        widget.session,
        filePath: file.path!,
        fileName: file.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storis yuklandi'),
          backgroundColor: Color(0xFF16934F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _contentFuture = _contentService.fetchAll(widget.session);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingStory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: AppTheme.brandColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Storislar (birinchi katak — yuklash tugmasi) va yangiliklar
          FutureBuilder<HomeContent>(
            future: _contentFuture,
            builder: (context, contentSnapshot) {
              final content =
                  contentSnapshot.data ??
                  const HomeContent(stories: [], news: []);
              return Column(
                children: [
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: content.stories.length + 1,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _AddStoryButton(
                            uploading: _uploadingStory,
                            onTap: _uploadStory,
                          );
                        }
                        final story = content.stories[index - 1];
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
                                  initialIndex: index - 1,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (content.news.isNotEmpty) ...[
                    HomeNewsCarousel(items: content.news),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
          // Oy tanlash chiplari
          SizedBox(
            height: 32,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _months.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final month = _months[index];
                final selected = month == _month;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _selectMonth(month),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.brandColor.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? AppTheme.brandColor
                            : const Color(0xFFD6DDEA),
                      ),
                    ),
                    child: Text(
                      _formatMonthLabel(month),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppTheme.brandColor
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FutureBuilder<SuperAdminDashboard>(
              future: _dashboardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 60),
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
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            snapshot.error is SuperAdminServiceException
                                ? (snapshot.error as SuperAdminServiceException)
                                      .message
                                : 'Statistika yuklanmadi',
                            style: const TextStyle(
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
                    _NetProfitCard(data: data),
                    const SizedBox(height: 12),
                    _KpiGrid(data: data),
                    const SizedBox(height: 12),
                    _FinanceChartCard(data: data),
                    if (data.expensesByCategory.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ExpenseCategoriesChartCard(
                        categories: data.expensesByCategory,
                        totalExpenses: data.totalExpenses,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _StudentsBreakdownCard(
                      session: widget.session,
                      students: data.students,
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<SnapshotSummary>(
                      future: _snapshotSummaryFuture,
                      builder: (context, snapshotSummarySnapshot) {
                        final summary = snapshotSummarySnapshot.data;
                        if (summary == null ||
                            summary.paymentRecordsTotal == 0) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          children: [
                            _PaymentStatusChartCard(
                              month: _month,
                              summary: summary,
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),
                    _SubjectsCard(
                      data: data,
                      teacherPaymentsFuture: _teacherPaymentsFuture,
                    ),
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

/// Storis qatoridagi "+" tugmasi — telefondan video yuklash
class _AddStoryButton extends StatelessWidget {
  const _AddStoryButton({required this.uploading, required this.onTap});

  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: SizedBox(
        width: 78,
        child: Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: AppTheme.brandColor.withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            child: uploading
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppTheme.brandColor,
                    ),
                  )
                : const Icon(
                    Icons.add_rounded,
                    size: 30,
                    color: AppTheme.brandColor,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Sof foyda — asosiy ko'rsatkich, brend gradientli katta karta
class _NetProfitCard extends StatelessWidget {
  const _NetProfitCard({required this.data});

  final SuperAdminDashboard data;

  @override
  Widget build(BuildContext context) {
    final positive = data.netProfit >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sof foyda',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  positive ? 'Foyda' : 'Zarar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatMoney(data.netProfit),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'tushum − teacher va admin oyliklari − rasxod − chegirma',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Oylik KPI kartalari to'plami
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});

  final SuperAdminDashboard data;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.payments_rounded,
        const Color(0xFF16934F),
        'Umumiy tushum',
        _formatMoney(data.totalRevenue),
      ),
      (
        Icons.school_rounded,
        const Color(0xFF2563EB),
        'Teacher oyliklari',
        _formatMoney(data.totalTeacherSalary),
      ),
      (
        Icons.manage_accounts_rounded,
        const Color(0xFF4F46E5),
        'Admin oyliklari',
        _formatMoney(data.totalAdminSalary),
      ),
      (
        Icons.receipt_long_rounded,
        const Color(0xFFB45309),
        'Rasxodlar',
        _formatMoney(data.totalExpenses),
      ),
      (
        Icons.percent_rounded,
        const Color(0xFF7C3AED),
        'Chegirmalar',
        _formatMoney(data.totalDiscounts),
      ),
      (
        Icons.person_add_alt_1_rounded,
        const Color(0xFF0F766E),
        'Yangi talabalar',
        '${data.newStudentsCount} ta',
      ),
      (
        Icons.groups_rounded,
        AppTheme.brandColor,
        'Faol talabalar',
        '${data.students.active} ta',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final (icon, color, label, value) = items[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E9F1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A93A5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Moliyaviy taqsimot donut charti: oylik/rasxod/chegirma/foyda
class _FinanceChartCard extends StatelessWidget {
  const _FinanceChartCard({required this.data});

  final SuperAdminDashboard data;

  @override
  Widget build(BuildContext context) {
    final profit = data.netProfit > 0 ? data.netProfit : 0.0;
    final segments = [
      ('Teacher oyligi', data.totalTeacherSalary, const Color(0xFF2563EB)),
      ('Admin oyligi', data.totalAdminSalary, const Color(0xFF4F46E5)),
      ('Rasxod', data.totalExpenses, const Color(0xFFB45309)),
      ('Chegirma', data.totalDiscounts, const Color(0xFF7C3AED)),
      ('Sof foyda', profit, const Color(0xFF16934F)),
    ].where((s) => s.$2 > 0).toList();

    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F1)),
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
                  Icons.pie_chart_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Tushum taqsimoti',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF182033),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    startDegreeOffset: -90,
                    sections: [
                      for (final segment in segments)
                        PieChartSectionData(
                          value: segment.$2,
                          color: segment.$3,
                          radius: 18,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final segment in segments) ...[
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: segment.$3,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              segment.$1,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF5A6478),
                              ),
                            ),
                          ),
                          Text(
                            _formatMoney(segment.$2),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF182033),
                            ),
                          ),
                        ],
                      ),
                      if (segment != segments.last) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// To'lov holati donut charti: to'lagan / qisman / to'lamagan o'quvchilar
/// (saytdagi "O'qituvchilar to'lovlari" sahifasidagi chart bilan bir xil).
class _PaymentStatusChartCard extends StatelessWidget {
  const _PaymentStatusChartCard({required this.month, required this.summary});

  final String month;
  final SnapshotSummary summary;

  static const _paidColor = Color(0xFF10B981);
  static const _partialColor = Color(0xFFF59E0B);
  static const _unpaidColor = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final percent = summary.paidPercent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F1)),
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
                  Icons.donut_large_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'To\'lov holati (${_formatMonthLabel(month)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 34,
                        startDegreeOffset: -90,
                        sections: [
                          if (summary.paidStudents > 0)
                            PieChartSectionData(
                              value: summary.paidStudents.toDouble(),
                              color: _paidColor,
                              radius: 16,
                              showTitle: false,
                            ),
                          if (summary.partialStudents > 0)
                            PieChartSectionData(
                              value: summary.partialStudents.toDouble(),
                              color: _partialColor,
                              radius: 16,
                              showTitle: false,
                            ),
                          if (summary.unpaidStudents > 0)
                            PieChartSectionData(
                              value: summary.unpaidStudents.toDouble(),
                              color: _unpaidColor,
                              radius: 16,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF182033),
                          ),
                        ),
                        const Text(
                          'to\'lov qilgan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A93A5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _PaymentStatusLegendRow(
                      color: _paidColor,
                      label: 'To\'lagan',
                      value: summary.paidStudents,
                    ),
                    const SizedBox(height: 10),
                    _PaymentStatusLegendRow(
                      color: _partialColor,
                      label: 'Qisman',
                      value: summary.partialStudents,
                    ),
                    const SizedBox(height: 10),
                    _PaymentStatusLegendRow(
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
    );
  }
}

class _PaymentStatusLegendRow extends StatelessWidget {
  const _PaymentStatusLegendRow({
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
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5A6478),
            ),
          ),
        ),
        Text(
          '$value o\'quvchi',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Color(0xFF182033),
          ),
        ),
      ],
    );
  }
}

/// Rasxodlar taqsimoti donut charti: kategoriyalar kesimida.
/// Eng katta 5 kategoriya alohida, qolganlari "Boshqa"ga yig'iladi.
class _ExpenseCategoriesChartCard extends StatelessWidget {
  const _ExpenseCategoriesChartCard({
    required this.categories,
    required this.totalExpenses,
  });

  final List<ExpenseCategoryStat> categories;
  final double totalExpenses;

  // Kategoriya ranglari — belgilangan tartibda, aylantirilmaydi.
  // Tartib CVD (rang ajrata olmaslik) uchun tekshirilgan; oxirgi kulrang
  // faqat "Boshqa" yig'indisi uchun.
  static const List<Color> _palette = [
    Color(0xFFB45309),
    Color(0xFF2563EB),
    Color(0xFFDB2777),
    Color(0xFF16934F),
    Color(0xFF7C3AED),
    Color(0xFF64748B),
  ];

  @override
  Widget build(BuildContext context) {
    // Backend summasi bo'yicha kamayish tartibida beradi; eng katta 5 tasi
    // alohida, qolgan mayda kategoriyalar "Boshqa" bo'lib birlashadi
    final top = categories.take(5).toList();
    final restTotal = categories
        .skip(5)
        .fold<double>(0, (sum, item) => sum + item.total);
    final segments = <(String, double, Color)>[
      for (var i = 0; i < top.length; i++)
        (top[i].name, top[i].total, _palette[i]),
      if (restTotal > 0) ('Boshqa', restTotal, _palette[5]),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F1)),
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
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Rasxod taqsimoti',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              Text(
                _formatMoney(totalExpenses),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFB45309),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    startDegreeOffset: -90,
                    sections: [
                      for (final segment in segments)
                        PieChartSectionData(
                          value: segment.$2,
                          color: segment.$3,
                          radius: 18,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final segment in segments) ...[
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: segment.$3,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              segment.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF5A6478),
                              ),
                            ),
                          ),
                          Text(
                            _formatMoney(segment.$2),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF182033),
                            ),
                          ),
                        ],
                      ),
                      if (segment != segments.last) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Talabalar statistikasi: jami, faol, guruhsiz, to'xtatgan, bitirgan
/// va shu oy to'lov jadvalida borlar
class _StudentsBreakdownCard extends StatelessWidget {
  const _StudentsBreakdownCard({required this.session, required this.students});

  final AuthSession session;
  final StudentsBreakdown students;

  void _openUnassignedStudents(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SuperAdminUnassignedStudentsPage(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      (
        Icons.check_circle_rounded,
        const Color(0xFF16934F),
        'Faol o\'qiyotganlar',
        students.active,
        null,
      ),
      (
        Icons.person_off_rounded,
        const Color(0xFF8A93A5),
        'Guruhsiz talabalar',
        students.unassigned,
        () => _openUnassignedStudents(context),
      ),
      (
        Icons.pause_circle_rounded,
        const Color(0xFFB45309),
        'O\'qishni to\'xtatganlar',
        students.stopped,
        null,
      ),
      (
        Icons.workspace_premium_rounded,
        const Color(0xFF7C3AED),
        'Bitirganlar',
        students.finished,
        null,
      ),
      (
        Icons.receipt_long_rounded,
        const Color(0xFF2563EB),
        'To\'lov jadvalida (shu oy)',
        students.inSnapshot,
        null,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F1)),
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
                  'Talabalar statistikasi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.brandColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Jami: ${students.total}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.brandColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: rows[i].$5,
              child: Row(
                children: [
                  Icon(rows[i].$1, size: 15, color: rows[i].$2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rows[i].$3,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5A6478),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: rows[i].$2.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${rows[i].$4} ta',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: rows[i].$2,
                      ),
                    ),
                  ),
                  if (rows[i].$5 != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFF8A93A5),
                    ),
                  ],
                ],
              ),
            ),
            if (i < rows.length - 1) ...[
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

/// Fanlar bo'yicha tahlil: tushum ulushi bar bilan + teacherlar ro'yxati
class _SubjectsCard extends StatelessWidget {
  const _SubjectsCard({required this.data, required this.teacherPaymentsFuture});

  final SuperAdminDashboard data;
  final Future<List<TeacherMonthPayments>> teacherPaymentsFuture;

  @override
  Widget build(BuildContext context) {
    if (data.subjects.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F1)),
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
                  Icons.auto_graph_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Fanlar bo\'yicha tahlil',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              Text(
                '${data.totalTeachers} teacher',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8A93A5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<TeacherMonthPayments>>(
            future: teacherPaymentsFuture,
            builder: (context, snapshot) {
              final studentsByTeacherId =
                  <int, List<TeacherMonthPaymentStudent>>{
                    for (final teacher
                        in snapshot.data ?? const <TeacherMonthPayments>[])
                      teacher.teacherId: teacher.students,
                  };
              final isLoadingStudents =
                  snapshot.connectionState == ConnectionState.waiting;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < data.subjects.length; i++) ...[
                    _SubjectTile(
                      subject: data.subjects[i],
                      studentsByTeacherId: studentsByTeacherId,
                      isLoadingStudents: isLoadingStudents,
                    ),
                    if (i < data.subjects.length - 1) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFEDF1F7)),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.subject,
    required this.studentsByTeacherId,
    required this.isLoadingStudents,
  });

  final SubjectStat subject;
  final Map<int, List<TeacherMonthPaymentStudent>> studentsByTeacherId;
  final bool isLoadingStudents;

  @override
  Widget build(BuildContext context) {
    // To'lov yig'ilish progresi: to'langan / kerak bo'lgan summa
    final ratio = subject.collectionRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                subject.subjectName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF182033),
                ),
              ),
            ),
            Text(
              _formatMoney(subject.totalRevenue),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppTheme.brandColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${subject.totalStudents} talaba • ${subject.teachersCount} teacher',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8A93A5),
          ),
        ),
        const SizedBox(height: 7),
        // To'lov yig'ilish progresi: to'langan / kerak bo'lgan summa
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(color: const Color(0xFFEDF1F7)),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(ratio * 100).round()}%',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppTheme.brandColor,
              ),
            ),
          ],
        ),
        // Teacherlar kesimi — har biri o'ziga xos dropdown,
        // ochilsa shu fan bo'yicha talabalari ko'rinadi
        if (subject.teachers.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final teacher in subject.teachers)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _SubjectTeacherTile(
                teacher: teacher,
                students:
                    studentsByTeacherId[teacher.teacherId]
                        ?.where((s) => s.subjectId == subject.subjectId)
                        .toList() ??
                    const [],
                isLoadingStudents: isLoadingStudents,
              ),
            ),
        ],
      ],
    );
  }
}

/// Fan ostidagi bitta teacher qatori — bosilsa o'zi ochiladi va
/// shu teacherning shu fandagi talabalari to'lov holati bilan ko'rinadi
class _SubjectTeacherTile extends StatefulWidget {
  const _SubjectTeacherTile({
    required this.teacher,
    required this.students,
    required this.isLoadingStudents,
  });

  final SubjectTeacherStat teacher;
  final List<TeacherMonthPaymentStudent> students;
  final bool isLoadingStudents;

  @override
  State<_SubjectTeacherTile> createState() => _SubjectTeacherTileState();
}

class _SubjectTeacherTileState extends State<_SubjectTeacherTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final teacher = widget.teacher;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.teacherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF182033),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${teacher.totalStudents} talaba • '
                        'Kerak: ${_formatMoney(teacher.totalRequired)} • '
                        'To\'lanmagan: ${_formatMoney(teacher.unpaidAmount)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7B8495),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Color(0xFF8A93A5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Container(color: const Color(0xFFEDF1F7)),
                        FractionallySizedBox(
                          widthFactor: teacher.collectionRatio,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFD32F2F), Color(0xFF7C0A05)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(teacher.collectionRatio * 100).round()}%',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.brandColor,
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFE4E9F1)),
            const SizedBox(height: 8),
            if (widget.isLoadingStudents)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppTheme.brandColor,
                    ),
                  ),
                ),
              )
            else if (widget.students.isEmpty)
              const Text(
                'Talabalar topilmadi',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8A93A5),
                ),
              )
            else
              for (final student in widget.students) ...[
                _TeacherStudentPaymentRow(student: student),
                if (student != widget.students.last)
                  const SizedBox(height: 6),
              ],
          ],
        ],
      ),
    );
  }
}

/// Bitta talabaning teacher/fan bo'yicha to'lov qatori
/// (student ID ko'rsatilmaydi — shart emas)
class _TeacherStudentPaymentRow extends StatelessWidget {
  const _TeacherStudentPaymentRow({required this.student});

  final TeacherMonthPaymentStudent student;

  static const _stateMap = {
    'paid': (label: 'To\'langan', color: Color(0xFF16934F)),
    'partial': (label: 'Qisman', color: Color(0xFFB45309)),
    'unpaid': (label: 'To\'lanmagan', color: Color(0xFFDC2626)),
  };

  @override
  Widget build(BuildContext context) {
    final info =
        _stateMap[student.paymentState] ??
        (label: student.paymentState, color: const Color(0xFF8A93A5));

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E9F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF182033),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  info.label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: info.color,
                  ),
                ),
              ),
            ],
          ),
          if (student.groupName.isNotEmpty || student.phone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              [
                if (student.groupName.isNotEmpty) student.groupName,
                if (student.phone.isNotEmpty) student.phone,
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A93A5),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _amountLabel(
                  'Kerak',
                  student.requiredAmount,
                  const Color(0xFF3A4256),
                ),
              ),
              Expanded(
                child: _amountLabel(
                  'To\'landi',
                  student.paidAmount,
                  const Color(0xFF16934F),
                ),
              ),
              Expanded(
                child: _amountLabel(
                  'Qarz',
                  student.debtAmount,
                  student.debtAmount > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF8A93A5),
                ),
              ),
            ],
          ),
          if (student.discountAmount > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Chegirma: ${_formatMoney(student.discountAmount)}',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _amountLabel(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9AA2B2),
          ),
        ),
        Text(
          _formatMoney(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

String _formatMoney(double value) {
  final rounded = value.round();
  final text = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(text[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer so\'m';
}

String _formatMonthLabel(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final month = int.tryParse(parts[1]) ?? 1;
  const names = [
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
  final monthName = month >= 1 && month <= 12 ? names[month - 1] : monthKey;
  return '$monthName ${parts[0]}';
}
