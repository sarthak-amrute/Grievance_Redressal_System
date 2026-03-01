// ignore_for_file: unused_element, deprecated_member_use

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grievance_redressal_system/designs/models/complaint_model.dart';
import 'package:grievance_redressal_system/designs/screens/notifications_screen.dart';
import 'package:grievance_redressal_system/designs/screens/settings_screen.dart';
import 'package:grievance_redressal_system/designs/screens/report_complaint_screen.dart';
import 'package:grievance_redressal_system/designs/screens/support_chat_screen.dart';

class HomeFragment extends StatefulWidget {
  // ignore: use_super_parameters
  const HomeFragment({Key? key}) : super(key: key);

  @override
  State<HomeFragment> createState() => _HomeFragmentState();
}

class _HomeFragmentState extends State<HomeFragment> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _complaintsSub;

  Map<String, dynamic>? _userData;
  // ignore: unused_field
  bool _isLoading = true;
  bool _isLoadingActivity = true;
  List<ComplaintModel> _recentComplaints = [];
  int _totalComplaints = 0;
  int _resolvedComplaints = 0;

  static const List<Map<String, dynamic>> _allCategories = [
    {'name': 'Roads',       'icon': Icons.edit_road,          'bgColor': Color(0xFFDCEAFF), 'iconColor': Color(0xFF2563EB)},
    {'name': 'Water',       'icon': Icons.water_drop,          'bgColor': Color(0xFFCFFAFE), 'iconColor': Color(0xFF0891B2)},
    {'name': 'Sanitation',  'icon': Icons.delete_sweep,        'bgColor': Color(0xFFDCFCE7), 'iconColor': Color(0xFF16A34A)},
    {'name': 'Power',       'icon': Icons.lightbulb,           'bgColor': Color(0xFFFEF3C7), 'iconColor': Color(0xFFCA8A04)},
    {'name': 'Parks',       'icon': Icons.park,                'bgColor': Color(0xFFFFEDD5), 'iconColor': Color(0xFFEA580C)},
    {'name': 'Safety',      'icon': Icons.health_and_safety,   'bgColor': Color(0xFFF3E8FF), 'iconColor': Color(0xFF9333EA)},
    {'name': 'Noise',       'icon': Icons.volume_up,           'bgColor': Color(0xFFFFE4F0), 'iconColor': Color(0xFFDB2777)},
    {'name': 'Transport',   'icon': Icons.directions_bus,      'bgColor': Color(0xFFE0F2FE), 'iconColor': Color(0xFF0284C7)},
    {'name': 'Buildings',   'icon': Icons.apartment,           'bgColor': Color(0xFFF1F5F9), 'iconColor': Color(0xFF64748B)},
    {'name': 'Animals',     'icon': Icons.pets,                'bgColor': Color(0xFFFEF3C7), 'iconColor': Color(0xFFD97706)},
    {'name': 'Environment', 'icon': Icons.eco,                 'bgColor': Color(0xFFDCFCE7), 'iconColor': Color(0xFF15803D)},
    {'name': 'Healthcare',  'icon': Icons.local_hospital,      'bgColor': Color(0xFFFEE2E2), 'iconColor': Color(0xFFDC2626)},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _subscribeComplaints();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _userData = doc.data();
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _subscribeComplaints() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingActivity = false);
      return;
    }

    // ✅ KEY FIX: No .orderBy() here — that requires a composite Firestore
    // index (userId + createdAt). Without that index Firestore throws an
    // error which is silently swallowed, leaving the UI blank.
    // We fetch by userId only and sort the list ourselves in Dart.
    _complaintsSub = _firestore
        .collection('complaints')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            final complaints = snapshot.docs
                .map((doc) => ComplaintModel.fromMap(
                      // ignore: unnecessary_cast
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ))
                .toList();

            // Sort newest first in Dart — no index needed
            complaints.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            int resolved = 0;
            for (final c in complaints) {
              if (c.status == 'Resolved') resolved++;
            }

            setState(() {
              _recentComplaints = complaints;
              _totalComplaints = complaints.length;
              _resolvedComplaints = resolved;
              _isLoadingActivity = false;
            });
          },
          onError: (e) {
            debugPrint('Complaints stream error: $e');
            setState(() {
              _recentComplaints = [];
              _totalComplaints = 0;
              _resolvedComplaints = 0;
              _isLoadingActivity = false;
            });
          },
        );
  }

  @override
  void dispose() {
    _complaintsSub?.cancel();
    super.dispose();
  }

  String _getFirstName() {
    if (_userData?['fullName'] != null) {
      return (_userData!['fullName'] as String).split(' ').first;
    }
    return 'Citizen';
  }

  String _getProfilePhotoUrl() {
    if (_userData?['profilePhoto'] != null &&
        (_userData!['profilePhoto'] as String).isNotEmpty) {
      return _userData!['profilePhoto'];
    }
    return 'https://ui-avatars.com/api/?name=${_getFirstName()}&background=195DE6&color=fff&size=512';
  }

  void _showAllCategoriesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFFF6F6F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'All Categories',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select a category to report an issue',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: _allCategories.map((cat) {
                      return _buildCategoryItem(
                        cat['name'] as String,
                        cat['icon'] as IconData,
                        cat['bgColor'] as Color,
                        cat['iconColor'] as Color,
                        fromModal: true,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildReportButton(),
          const SizedBox(height: 16),
          _buildHelpSupport(),
          const SizedBox(height: 40),
          _buildCategories(),
          const SizedBox(height: 40),
          _buildRecentActivity(),
          const SizedBox(height: 160),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(48),
          bottomRight: Radius.circular(48),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFDCEAFF).withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -40,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6).withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
            child: Column(
              children: [
                // Profile row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            Transform.rotate(
                              angle: 0.105,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDCEAFF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                image: DecorationImage(
                                  image: NetworkImage(_getProfilePhotoUrl()),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back,',
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            Text(
                              'Hello, ${_getFirstName()}!',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Notification icon
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.notifications_outlined,
                                    color: Color(0xFF64748B), size: 26),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Settings icon
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.settings_outlined,
                                color: Color(0xFF64748B), size: 26),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Stats cards
                Row(
                  children: [
                    // All complaints card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCEAFF).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: const Color(0xFFDCEAFF).withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.list_alt,
                                    color: Color(0xFF2563EB), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'ALL COMPLAINTS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _isLoadingActivity
                                ? const SizedBox(
                                    height: 36,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF2563EB)),
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    '$_totalComplaints',
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Resolved card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: const Color(0xFFDCFCE7).withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.task_alt,
                                    color: Color(0xFF16A34A), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'RESOLVED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _isLoadingActivity
                                ? const SizedBox(
                                    height: 36,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF16A34A)),
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    '$_resolvedComplaints',
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                          ],
                        ),
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

  // ─── Report button ───────────────────────────────────────────────────────────

  Widget _buildReportButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF195DE6).withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: const Color(0xFF195DE6),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportComplaintScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.campaign,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Report a Complaint',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Spot an issue? Let us know immediately.',
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFFBFDBFE)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      color: Colors.white.withOpacity(0.5), size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Help & Support card ─────────────────────────────────────────────────────

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF195DE6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildHelpSupport() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SupportChatScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                // Icon container — purple tint matching the image
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.support_agent_outlined,
                    color: Color(0xFF9333EA),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Text
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Help & Support',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Chat with our assistant to get help or guidance',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Arrow
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9333EA),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Categories ──────────────────────────────────────────────────────────────

  Widget _buildCategories() {
    final homeCategories = _allCategories.take(6).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              GestureDetector(
                onTap: _showAllCategoriesModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEAFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF195DE6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: homeCategories
                .map((cat) => _buildCategoryItem(
                      cat['name'] as String,
                      cat['icon'] as IconData,
                      cat['bgColor'] as Color,
                      cat['iconColor'] as Color,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    String label,
    IconData icon,
    Color bgColor,
    Color iconColor, {
    bool fromModal = false,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (fromModal) Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ReportComplaintScreen(initialCategory: label),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(32),
                    bottomLeft: Radius.circular(38),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Recent activity ─────────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoadingActivity)
            const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF195DE6)),
              ),
            )
          else if (_recentComplaints.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.inbox_outlined,
                        size: 36, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No complaints yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your submitted complaints will appear here.',
                    style:
                        TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: List.generate(_recentComplaints.length, (index) {
                final c = _recentComplaints[index];
                final diff = DateTime.now().difference(c.createdAt);
                final timeText = diff.inMinutes < 60
                    ? '${diff.inMinutes} min ago'
                    : diff.inHours < 24
                        ? '${diff.inHours} hours ago'
                        : '${diff.inDays} days ago';

                Color statusBg;
                Color statusText;
                if (c.status == 'Resolved') {
                  statusBg = const Color(0xFFDCFCE7);
                  statusText = const Color(0xFF15803D);
                } else if (c.status == 'In Progress') {
                  statusBg = const Color(0xFFDCEAFF);
                  statusText = const Color(0xFF2563EB);
                } else if (c.status == 'Cancelled') {
                  statusBg = const Color(0xFFF1F5F9);
                  statusText = const Color(0xFF64748B);
                } else {
                  statusBg = const Color(0xFFFFEDD5);
                  statusText = const Color(0xFFC2410C);
                }

                final imageUrl = c.imageUrl.isNotEmpty
                    ? c.imageUrl
                    : 'https://via.placeholder.com/64';

                return Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 16),
                  child: _buildActivityItem(
                    c.title,
                    '$timeText • #${c.complaintId.substring(0, 6).toUpperCase()}',
                    c.status,
                    statusBg,
                    statusText,
                    imageUrl,
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    String status,
    Color statusBg,
    Color statusText,
    String imageUrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipPath(
            clipper: BlobClipper(),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Blob clipper ────────────────────────────────────────────────────────────

class BlobClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.447, h * 0.236);
    path.cubicTo(w * 0.581, w * 0.308, w * 0.692, w * 0.419, w * 0.764, w * 0.553);
    path.cubicTo(w * 0.837, w * 0.687, w * 0.871, w * 0.843, w * 0.863, w);
    path.cubicTo(w * 0.854, h * 1.147, w * 0.803, h * 1.293, w * 0.718, h * 1.42);
    path.cubicTo(w * 0.633, h * 1.547, w * 0.514, h * 1.655, w * 0.378, h * 1.727);
    path.cubicTo(w * 0.242, h * 1.798, w * 0.088, h * 1.833, w * -0.062, h * 1.808);
    path.cubicTo(w * -0.212, h * 1.782, w * -0.358, h * 1.697, w * -0.48, h * 1.588);
    path.cubicTo(w * -0.602, h * 1.48, w * -0.701, h * 1.348, w * -0.754, h * 1.201);
    path.cubicTo(w * -0.807, h * 1.054, w * -0.814, h * 0.892, w * -0.768, h * 0.743);
    path.cubicTo(w * -0.722, h * 0.594, w * -0.624, h * 0.458, w * -0.496, h * 0.383);
    path.cubicTo(w * -0.368, h * 0.308, w * -0.211, h * 0.294, w * -0.054, h * 0.349);
    path.cubicTo(w * 0.103, h * 0.404, w * 0.205, h * 0.328, w * 0.313, h * 0.346);
    path.cubicTo(w * 0.421, h * 0.364, w * 0.534, h * 0.376, w * 0.447, h * 0.236);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}