import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  // ignore: use_super_parameters
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ignore: unused_field
  final _auth = FirebaseAuth.instance;
  // ignore: unused_field
  final _firestore = FirebaseFirestore.instance;

  // Toggle states
  bool _notificationsEnabled = true;
  bool _emailAlertsEnabled = true;
  bool _darkMode = false;
  bool _locationEnabled = true;

  static const Color _primary = Color(0xFF195DE6);
  static const Color _bg = Color(0xFFF6F8FD);
  static const Color _cardBg = Colors.white;
  static const Color _textColor = Color(0xFF0F172A);
  static const Color _subtleText = Color(0xFF64748B);
  static const Color _labelColor = Color(0xFF94A3B8);

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Cache?',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: _textColor),
        ),
        content: const Text(
          'This will clear all locally cached data. Your account data will not be affected.',
          style: TextStyle(fontSize: 14, color: _subtleText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(
                    color: _subtleText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSnackBar('Cache cleared successfully');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Clear',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Citizen App',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.location_city, color: Colors.white, size: 32),
      ),
      applicationLegalese: '© 2025 Grievance Redressal System\nAll rights reserved.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: _textColor),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: _textColor),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Notifications ────────────────────────────────────────────────
            _sectionLabel('Notifications'),
            _buildCard([
              _toggleItem(
                icon: Icons.notifications_outlined,
                iconBg: const Color(0xFFDCEAFF),
                iconColor: _primary,
                label: 'Push Notifications',
                subtitle: 'Alerts for your complaint updates',
                value: _notificationsEnabled,
                onChanged: (v) =>
                    setState(() => _notificationsEnabled = v),
              ),
              _divider(),
              _toggleItem(
                icon: Icons.email_outlined,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF16A34A),
                label: 'Email Alerts',
                subtitle: 'Receive updates via email',
                value: _emailAlertsEnabled,
                onChanged: (v) =>
                    setState(() => _emailAlertsEnabled = v),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Appearance ───────────────────────────────────────────────────
            _sectionLabel('Appearance'),
            _buildCard([
              _toggleItem(
                icon: Icons.dark_mode_outlined,
                // ignore: deprecated_member_use
                iconBg: const Color(0xFF1E293B).withOpacity(0.08),
                iconColor: const Color(0xFF1E293B),
                label: 'Dark Mode',
                subtitle: 'Switch to dark theme',
                value: _darkMode,
                onChanged: (v) {
                  setState(() => _darkMode = v);
                  _showSnackBar(
                      v ? 'Dark mode enabled' : 'Dark mode disabled');
                },
              ),
            ]),

            const SizedBox(height: 20),

            // ── Privacy ──────────────────────────────────────────────────────
            _sectionLabel('Privacy'),
            _buildCard([
              _toggleItem(
                icon: Icons.location_on_outlined,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFCA8A04),
                label: 'Location Access',
                subtitle: 'Allow app to access location',
                value: _locationEnabled,
                onChanged: (v) => setState(() => _locationEnabled = v),
              ),
              _divider(),
              _tappableItem(
                icon: Icons.lock_outline,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
                label: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showSnackBar('Password change coming soon'),
              ),
              _divider(),
              _tappableItem(
                icon: Icons.delete_sweep_outlined,
                iconBg: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFDC2626),
                label: 'Delete Account',
                subtitle: 'Permanently remove your account',
                onTap: () => _showSnackBar('Contact support to delete account'),
                labelColor: const Color(0xFFDC2626),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Storage ──────────────────────────────────────────────────────
            _sectionLabel('Storage'),
            _buildCard([
              _tappableItem(
                icon: Icons.cleaning_services_outlined,
                iconBg: const Color(0xFFE0F2FE),
                iconColor: const Color(0xFF0284C7),
                label: 'Clear Cache',
                subtitle: 'Free up local storage space',
                onTap: _showClearCacheDialog,
              ),
            ]),

            const SizedBox(height: 20),

            // ── About ────────────────────────────────────────────────────────
            _sectionLabel('About'),
            _buildCard([
              _tappableItem(
                icon: Icons.info_outline,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF64748B),
                label: 'About App',
                subtitle: 'Version 1.0.0',
                onTap: _showAboutDialog,
              ),
              _divider(),
              _tappableItem(
                icon: Icons.description_outlined,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF64748B),
                label: 'Terms & Conditions',
                subtitle: 'Read our terms of service',
                onTap: () =>
                    _showSnackBar('Terms & Conditions coming soon'),
              ),
              _divider(),
              _tappableItem(
                icon: Icons.privacy_tip_outlined,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF64748B),
                label: 'Privacy Policy',
                subtitle: 'How we handle your data',
                onTap: () => _showSnackBar('Privacy Policy coming soon'),
              ),
            ]),

            const SizedBox(height: 20),

            // ── App version tag ──────────────────────────────────────────────
            Center(
              child: Text(
                'Citizen App  •  v1.0.0',
                style: const TextStyle(
                    fontSize: 12,
                    color: _labelColor,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _labelColor,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFF8FAFC),
        indent: 68,
        endIndent: 16,
      );

  Widget _toggleItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _textColor)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: _labelColor)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            // ignore: deprecated_member_use
            activeColor: _primary,
          ),
        ],
      ),
    );
  }

  Widget _tappableItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Color labelColor = _textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: labelColor)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: _labelColor)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFFCBD5E1), size: 22),
          ],
        ),
      ),
    );
  }
}