// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grievance_redressal_system/designs/screens/admin_profile.dart';
import 'admin_home_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_map_screen.dart';
// ignore: unused_import
import 'admin_profile_screen.dart' hide AdminProfileScreen;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.list_alt_rounded, label: 'Complaints'),
    _NavItem(icon: Icons.bar_chart_rounded, label: 'Analytics'),
    _NavItem(icon: Icons.map_outlined, label: 'Map'),
    _NavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _checkAuth();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _checkAuth() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/admin-login', (_) => false);
      });
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _KeepAlivePage(child: AdminHomeScreen()),
            _KeepAlivePage(child: AdminComplaintsScreen()),
            _KeepAlivePage(child: AdminAnalyticsScreen()),
            _KeepAlivePage(child: AdminMapScreen()),
            _KeepAlivePage(child: AdminProfileScreen()),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = _currentIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabTapped(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      index == 1
                          ? _PendingBadge(child: Icon(item.icon, size: 24, color: isSelected ? const Color(0xFF1A4DB7) : const Color(0xFF94A3B8)))
                          : Icon(item.icon, size: 24, color: isSelected ? const Color(0xFF1A4DB7) : const Color(0xFF94A3B8)),
                      const SizedBox(height: 4),
                      Text(item.label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? const Color(0xFF1A4DB7) : const Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 3,
                        width: isSelected ? 20 : 0,
                        decoration: BoxDecoration(color: const Color(0xFF1A4DB7), borderRadius: BorderRadius.circular(2)),
                      ),
                    ],
                  ),  
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final Widget child;
  const _PendingBadge({required this.child});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('complaints').where('status', isEqualTo: 'Pending').snapshots(),
      builder: (ctx, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (count > 0)
              Positioned(
                top: -4, right: -6,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                  child: Center(child: Text(count > 9 ? '9+' : '$count', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});
  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}