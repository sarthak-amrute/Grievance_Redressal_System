import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grievance_redressal_system/designs/models/complaint_model.dart';
import 'package:grievance_redressal_system/designs/screens/complaint_detail_screen.dart';

class ActivityFragment extends StatefulWidget {
  const ActivityFragment({Key? key}) : super(key: key);

  @override
  State<ActivityFragment> createState() => _ActivityFragmentState();
}

class _ActivityFragmentState extends State<ActivityFragment> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _complaintsSub;

  List<ComplaintModel> _allComplaints = [];
  String _activeFilter = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subscribeComplaints();
  }

  void _subscribeComplaints() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    _complaintsSub = _firestore
        .collection('complaints')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            final complaints = snapshot.docs
                .map((doc) => ComplaintModel.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ))
                .toList();
            complaints.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            setState(() {
              _allComplaints = complaints;
              _isLoading = false;
            });
          },
          onError: (e) {
            debugPrint('Complaints stream error: $e');
            setState(() => _isLoading = false);
          },
        );
  }

  @override
  void dispose() {
    _complaintsSub?.cancel();
    super.dispose();
  }

  // ── Filters ──────────────────────────────────────────────────────────────────

  List<ComplaintModel> get _filteredComplaints {
    switch (_activeFilter) {
      case 'Pending':
        return _allComplaints.where((c) => c.status == 'Pending').toList();
      case 'In Progress':
        return _allComplaints.where((c) => c.status == 'In Progress').toList();
      case 'Resolved':
        return _allComplaints.where((c) => c.status == 'Resolved').toList();
      default:
        return _allComplaints;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) {
      return diff.inMinutes == 1 ? '1 minute ago' : '${diff.inMinutes} minutes ago';
    }
    if (diff.inHours < 24) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    if (diff.inDays < 7) {
      return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
    }
    final weeks = (diff.inDays / 7).floor();
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }

  /// Progress % for each status — matches the reference design's progress bar
  double _progressValue(String status) {
    switch (status) {
      case 'Pending':     return 0.10;
      case 'In Progress': return 0.50;
      case 'Resolved':    return 1.00;
      case 'Cancelled':   return 0.0;
      default:            return 0.05;
    }
  }

  /// Stage label shown above the progress bar
  String _stageLabel(String status) {
    switch (status) {
      case 'Pending':     return 'Verification Pending';
      case 'In Progress': return 'Assigning Officer';
      case 'Resolved':    return 'Ticket Closed';
      case 'Cancelled':   return 'Complaint Cancelled';
      default:            return 'Submitted';
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Roads':       return Icons.edit_road;
      case 'Water':       return Icons.water_drop;
      case 'Sanitation':  return Icons.delete_sweep;
      case 'Power':       return Icons.lightbulb;
      case 'Parks':       return Icons.park;
      case 'Safety':      return Icons.health_and_safety;
      case 'Noise':       return Icons.volume_up;
      case 'Transport':   return Icons.directions_bus;
      case 'Buildings':   return Icons.apartment;
      case 'Animals':     return Icons.pets;
      case 'Environment': return Icons.eco;
      case 'Healthcare':  return Icons.local_hospital;
      default:            return Icons.report_problem;
    }
  }

  // Per-status color set: { bg, fg, barColor }
  _StatusColors _statusColors(String status) {
    switch (status) {
      case 'In Progress':
        return _StatusColors(
          chipBg: const Color(0xFFEFF6FF),
          chipFg: const Color(0xFF1D4ED8),
          barColor: const Color(0xFF195DE6),
          iconBg: const Color(0xFFEFF6FF),
          iconFg: const Color(0xFF195DE6),
        );
      case 'Resolved':
        return _StatusColors(
          chipBg: const Color(0xFFF0FDF4),
          chipFg: const Color(0xFF15803D),
          barColor: const Color(0xFF22C55E),
          iconBg: const Color(0xFFF0FDF4),
          iconFg: const Color(0xFF16A34A),
        );
      case 'Cancelled':
        return _StatusColors(
          chipBg: const Color(0xFFF1F5F9),
          chipFg: const Color(0xFF64748B),
          barColor: const Color(0xFF94A3B8),
          iconBg: const Color(0xFFF1F5F9),
          iconFg: const Color(0xFF64748B),
        );
      default: // Pending
        return _StatusColors(
          chipBg: const Color(0xFFFFF7ED),
          chipFg: const Color(0xFFC2410C),
          barColor: const Color(0xFFF97316),
          iconBg: const Color(0xFFFFF7ED),
          iconFg: const Color(0xFFEA580C),
        );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(child: _buildStickyHeader()),
        ],
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF195DE6)),
                ),
              )
            : _buildList(),
      ),
    );
  }

  // ── Sticky header (title + filter chips) ─────────────────────────────────────

  Widget _buildStickyHeader() {
    final filters = ['All', 'Pending', 'In Progress', 'Resolved'];
    final filterIcons = {
      'All':         Icons.check,
      'Pending':     Icons.schedule,
      'In Progress': Icons.trending_up,
      'Resolved':    Icons.check_circle_outline,
    };

    return Container(
      color: const Color(0xFFF6F6F8),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Complaints',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0E121B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Track your grievance status',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4E6797),
                      ),
                    ),
                  ],
                ),
                // Filter button
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border:
                        Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: const Icon(Icons.tune,
                      size: 20, color: Color(0xFF0E121B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Filter chips — scrollable horizontal row
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: filters.length,
              itemBuilder: (_, i) {
                final f = filters[i];
                final isActive = _activeFilter == f;
                return GestureDetector(
                  onTap: () => setState(() => _activeFilter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 0),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF195DE6)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF195DE6)
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: const Color(0xFF195DE6)
                                    .withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          filterIcons[f]!,
                          size: 16,
                          color: isActive
                              ? Colors.white
                              : const Color(0xFF4E6797),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          f,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF0E121B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Complaints list ───────────────────────────────────────────────────────────

  Widget _buildList() {
    final complaints = _filteredComplaints;

    if (complaints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: const Icon(Icons.inbox_outlined,
                  size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No complaints found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0E121B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _activeFilter == 'All'
                  ? "You haven't submitted any complaints yet."
                  : 'No "$_activeFilter" complaints right now.',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: complaints.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _buildCard(complaints[i]),
    );
  }

  // ── Card ──────────────────────────────────────────────────────────────────────

  Widget _buildCard(ComplaintModel c) {
    final colors = _statusColors(c.status);
    final icon = _categoryIcon(c.category);
    final progress = _progressValue(c.status);
    final stage = _stageLabel(c.status);
    final percent = '${(progress * 100).toInt()}%';
    // GRV style ID: first 8 chars of complaintId, uppercased
    final grvId =
        '#GRV-${c.complaintId.substring(0, min(8, c.complaintId.length)).toUpperCase()}';
    final isResolved = c.status == 'Resolved';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ComplaintDetailScreen(complaint: c)),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isResolved ? 0.85 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ComplaintDetailScreen(complaint: c)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Row 1: ID + time  |  status chip ──────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              grvId,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4E6797),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _timeAgo(c.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF4E6797),
                              ),
                            ),
                          ],
                        ),
                        _buildStatusChip(c.status, colors),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Row 2: Category icon + title + address ─────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.iconBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon,
                              color: colors.iconFg, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0E121B),
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.address.isNotEmpty
                                    ? c.address
                                    : c.category,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4E6797),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Progress bar section ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                stage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0E121B),
                                ),
                              ),
                              Text(
                                percent,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.barColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 7,
                              backgroundColor:
                                  const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.barColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Status chip ───────────────────────────────────────────────────────────────

  Widget _buildStatusChip(String status, _StatusColors colors) {
    // "In Progress" gets a pulsing dot; others get an icon
    final isPulsing = status == 'In Progress';
    final isPending = status == 'Pending';

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPulsing || isPending)
            _PulsingDot(
                color: colors.chipFg, pulse: isPulsing)
          else if (status == 'Resolved')
            Icon(Icons.check, size: 12, color: colors.chipFg)
          else
            Icon(Icons.cancel_outlined,
                size: 12, color: colors.chipFg),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: colors.chipFg,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing dot widget ────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _PulsingDot({required this.color, required this.pulse});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Color data class ──────────────────────────────────────────────────────────

class _StatusColors {
  final Color chipBg;
  final Color chipFg;
  final Color barColor;
  final Color iconBg;
  final Color iconFg;
  const _StatusColors({
    required this.chipBg,
    required this.chipFg,
    required this.barColor,
    required this.iconBg,
    required this.iconFg,
  });
}

// ── Helper ────────────────────────────────────────────────────────────────────
int min(int a, int b) => a < b ? a : b;