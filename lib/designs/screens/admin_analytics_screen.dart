// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int totalComplaints = 0;
  int pendingCount = 0;
  int resolvedCount = 0;
  int inProgressCount = 0;
  int escalatedCount = 0;
  double avgResolutionDays = 0;
  Map<String, int> categoryCount = {};
  List<int> monthlyData = List.filled(12, 0);
  bool _isLoading = true;

  final List<String> monthLabels = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('complaints').get();
      int total = snapshot.docs.length;
      Map<String, int> cats = {};
      double totalDays = 0;
      int resolved = 0, pending = 0, inProgress = 0, escalated = 0;
      List<int> monthly = List.filled(12, 0);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final category = data['category'] as String? ?? 'Other';
        cats[category] = (cats[category] ?? 0) + 1;

        final status = (data['status'] as String? ?? '').toLowerCase();
        if (status == 'resolved') resolved++;
        if (status == 'pending') pending++;
        if (status == 'in progress') inProgress++;
        if (status == 'escalated') escalated++;

        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          monthly[createdAt.toDate().month - 1]++;
        }

        if (status == 'resolved' &&
            createdAt != null &&
            data['resolvedAt'] != null) {
          final created = createdAt.toDate();
          final resolvedAt = (data['resolvedAt'] as Timestamp).toDate();
          totalDays += resolvedAt.difference(created).inHours / 24.0;
        }
      }

      if (mounted) {
        setState(() {
          totalComplaints = total;
          categoryCount = cats;
          resolvedCount = resolved;
          pendingCount = pending;
          inProgressCount = inProgress;
          escalatedCount = escalated;
          monthlyData = monthly;
          avgResolutionDays = resolved > 0 ? totalDays / resolved : 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            // ✅ FIXED: Real TabBar wired to TabController
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: TabBar(
                controller: _tabController,
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                labelColor: const Color(0xFF1A4DB7),
                unselectedLabelColor: const Color(0xFF94A3B8),
                indicatorColor: const Color(0xFF1A4DB7),
                indicatorWeight: 2.5,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Categories'),
                  Tab(text: 'Trends'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A4DB7)))
                  : TabBarView(
                      controller: _tabController,
                      // ✅ FIXED: each tab shows completely different content
                      children: [
                        _buildOverviewTab(),
                        _buildCategoriesTab(),
                        _buildTrendsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.bar_chart_rounded, size: 24, color: Color(0xFF1A4DB7)),
          const Expanded(
            child: Center(
              child: Text('Analytics',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ),
          ),
          GestureDetector(
            onTap: _fetchAnalytics,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.refresh, size: 20, color: Color(0xFF1A4DB7)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1 — OVERVIEW
  // ─────────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _statCard('Total', totalComplaints, Icons.inbox_rounded, const Color(0xFF1A4DB7)),
              _statCard('Pending', pendingCount, Icons.hourglass_top_rounded, const Color(0xFFF59E0B)),
              _statCard('In Progress', inProgressCount, Icons.autorenew_rounded, const Color(0xFF6366F1)),
              _statCard('Resolved', resolvedCount, Icons.check_circle_rounded, const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 16),
          _infoCard(
            icon: Icons.timer_outlined,
            label: 'AVG. RESOLUTION TIME',
            value: avgResolutionDays == 0 ? 'No data yet' : '${avgResolutionDays.toStringAsFixed(1)} days',
            color: const Color(0xFF06B6D4),
          ),
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.warning_amber_rounded,
            label: 'ESCALATED COMPLAINTS',
            value: escalatedCount.toString(),
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 16),
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 22, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.toString(),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final total = totalComplaints == 0 ? 1 : totalComplaints;
    final statuses = [
      ('Pending', pendingCount, const Color(0xFFF59E0B)),
      ('In Progress', inProgressCount, const Color(0xFF6366F1)),
      ('Escalated', escalatedCount, const Color(0xFFEF4444)),
      ('Resolved', resolvedCount, const Color(0xFF10B981)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STATUS DISTRIBUTION',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: statuses.map((s) {
                final flex = ((s.$2 / total) * 1000).round().clamp(1, 1000);
                return Flexible(flex: flex, child: Container(height: 14, color: s.$3));
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16, runSpacing: 8,
            children: statuses.map((s) {
              final pct = totalComplaints == 0 ? 0 : ((s.$2 / totalComplaints) * 100).round();
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: s.$3, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('${s.$1} ($pct%)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2 — CATEGORIES
  // ─────────────────────────────────────────────────────────────
  Widget _buildCategoriesTab() {
    if (categoryCount.isEmpty) {
      return const Center(
        child: Text('No category data yet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
      );
    }

    final sorted = categoryCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value;
    final colors = [
      const Color(0xFF1A4DB7), const Color(0xFF06B6D4), const Color(0xFFEF4444),
      const Color(0xFF10B981), const Color(0xFF8B5CF6), const Color(0xFFF59E0B),
    ];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('COMPLAINTS BY CATEGORY',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
                const SizedBox(height: 16),
                ...List.generate(sorted.length, (i) {
                  final e = sorted[i];
                  final color = colors[i % colors.length];
                  final ratio = maxVal == 0 ? 0.0 : e.value / maxVal;
                  final pct = totalComplaints == 0 ? 0 : ((e.value / totalComplaints) * 100).round();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                          Text('${e.value}  ($pct%)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                        ]),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio, minHeight: 10,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(sorted.length, (i) {
            final e = sorted[i];
            final color = colors[i % colors.length];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(e.key.isNotEmpty ? e.key[0].toUpperCase() : 'C',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(e.key,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(e.value.toString(),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                  const Text('complaints',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ]),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3 — TRENDS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Line chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('MONTHLY TREND',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
                    Text('Total: $totalComplaints',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A4DB7))),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: CustomPaint(painter: _LineChartPainter(monthlyData), size: Size.infinite),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['J','F','M','A','M','J','J','A','S','O','N','D']
                      .map((m) => Text(m,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Month-by-month bars
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MONTH BY MONTH',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.6)),
                const SizedBox(height: 14),
                ...List.generate(12, (i) {
                  final val = monthlyData[i];
                  final maxM = monthlyData.reduce((a, b) => a > b ? a : b);
                  final ratio = maxM == 0 ? 0.0 : val / maxM;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      SizedBox(
                        width: 36,
                        child: Text(monthLabels[i],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio, minHeight: 10,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A4DB7)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text('$val',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            textAlign: TextAlign.right),
                      ),
                    ]),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _insightCard('Peak Month', () {
              final maxVal = monthlyData.reduce((a, b) => a > b ? a : b);
              if (maxVal == 0) return 'No data';
              return '${monthLabels[monthlyData.indexOf(maxVal)]} ($maxVal)';
            }(), Icons.trending_up_rounded, const Color(0xFFEF4444))),
            const SizedBox(width: 12),
            Expanded(child: _insightCard('Quietest', () {
              final nonZero = monthlyData.where((v) => v > 0).toList();
              if (nonZero.isEmpty) return 'No data';
              final minVal = nonZero.reduce((a, b) => a < b ? a : b);
              return '${monthLabels[monthlyData.indexOf(minVal)]} ($minVal)';
            }(), Icons.trending_down_rounded, const Color(0xFF10B981))),
          ]),
        ],
      ),
    );
  }

  Widget _insightCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> data;
  _LineChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || data.every((v) => v == 0)) {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2),
          Paint()..color = const Color(0xFF1A4DB7).withOpacity(0.3)..strokeWidth = 2..style = PaintingStyle.stroke);
      return;
    }
    final maxVal = data.reduce((a, b) => a > b ? a : b).toDouble();
    final minVal = data.reduce((a, b) => a < b ? a : b).toDouble();
    final range = maxVal == minVal ? 1.0 : maxVal - minVal;

    final points = List.generate(data.length, (i) => Offset(
      i / (data.length - 1) * size.width,
      size.height - ((data[i] - minVal) / range) * size.height * 0.8 - size.height * 0.1,
    ));

    final fillPath = Path()..moveTo(points[0].dx, size.height);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i+1].dx) / 2, points[i].dy);
      final cp2 = Offset((points[i].dx + points[i+1].dx) / 2, points[i+1].dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i+1].dx, points[i+1].dy);
    }
    fillPath..lineTo(size.width, size.height)..close();
    canvas.drawPath(fillPath, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [const Color(0xFF1A4DB7).withOpacity(0.2), const Color(0xFF1A4DB7).withOpacity(0.0)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i+1].dx) / 2, points[i].dy);
      final cp2 = Offset((points[i].dx + points[i+1].dx) / 2, points[i+1].dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i+1].dx, points[i+1].dy);
    }
    canvas.drawPath(linePath, Paint()..color = const Color(0xFF1A4DB7)..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    for (final pt in points) {
      canvas.drawCircle(pt, 4, Paint()..color = const Color(0xFF1A4DB7));
      canvas.drawCircle(pt, 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}