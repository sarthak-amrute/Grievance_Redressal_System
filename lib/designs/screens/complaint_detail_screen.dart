// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grievance_redressal_system/designs/models/complaint_model.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final ComplaintModel complaint;

  // ignore: use_super_parameters
  const ComplaintDetailScreen({Key? key, required this.complaint})
      : super(key: key);

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isDeleting = false;
  bool _isUpdating = false;
  late ComplaintModel _complaint;

  // Controllers for the update sheet
  late TextEditingController _updateTitleCtrl;
  late TextEditingController _updateDescCtrl;
  String? _updateCategory;

  @override
  void initState() {
    super.initState();
    _complaint = widget.complaint;
    _updateTitleCtrl = TextEditingController(text: _complaint.title);
    _updateDescCtrl = TextEditingController(text: _complaint.description);
    _updateCategory = _complaint.category;
  }

  @override
  void dispose() {
    _updateTitleCtrl.dispose();
    _updateDescCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Roads':
        return Icons.edit_road;
      case 'Water':
        return Icons.water_drop;
      case 'Sanitation':
        return Icons.delete_sweep;
      case 'Power':
        return Icons.lightbulb;
      case 'Parks':
        return Icons.park;
      case 'Safety':
        return Icons.health_and_safety;
      case 'Noise':
        return Icons.volume_up;
      case 'Transport':
        return Icons.directions_bus;
      case 'Buildings':
        return Icons.apartment;
      case 'Animals':
        return Icons.pets;
      case 'Environment':
        return Icons.eco;
      case 'Healthcare':
        return Icons.local_hospital;
      default:
        return Icons.report_problem;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Roads':
        return const Color(0xFF2563EB);
      case 'Water':
        return const Color(0xFF0891B2);
      case 'Sanitation':
        return const Color(0xFF16A34A);
      case 'Power':
        return const Color(0xFFCA8A04);
      case 'Parks':
        return const Color(0xFFEA580C);
      case 'Safety':
        return const Color(0xFF9333EA);
      case 'Noise':
        return const Color(0xFFDB2777);
      case 'Transport':
        return const Color(0xFF0284C7);
      case 'Buildings':
        return const Color(0xFF64748B);
      case 'Animals':
        return const Color(0xFFD97706);
      case 'Environment':
        return const Color(0xFF15803D);
      case 'Healthcare':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF195DE6);
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  •  $hour:$minute $ampm';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() > 1 ? 's' : ''} ago';
  }

  bool get _canUpdate =>
      _complaint.status == 'Pending' || _complaint.status == 'In Progress';

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _deleteComplaint() async {
    setState(() => _isDeleting = true);
    try {
      await _firestore
          .collection('complaints')
          .doc(_complaint.complaintId)
          .delete();
      if (mounted) {
        Navigator.pop(context, 'deleted');
        _showToast('Complaint deleted successfully.', success: false);
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      _showToast('Failed to delete. Please try again.');
    }
  }

  Future<void> _updateComplaint() async {
    final newTitle = _updateTitleCtrl.text.trim();
    final newDesc = _updateDescCtrl.text.trim();
    final newCat = _updateCategory ?? _complaint.category;

    if (newTitle.isEmpty || newTitle.length < 5) {
      _showToast('Title must be at least 5 characters.', success: false);
      return;
    }
    if (newDesc.isEmpty || newDesc.length < 10) {
      _showToast('Description must be at least 10 characters.', success: false);
      return;
    }

    setState(() => _isUpdating = true);
    try {
      await _firestore
          .collection('complaints')
          .doc(_complaint.complaintId)
          .update({
        'title': newTitle,
        'description': newDesc,
        'category': newCat,
      });
      setState(() {
        _complaint = _complaint.copyWith(
          title: newTitle,
          description: newDesc,
          category: newCat,
        );
        _isUpdating = false;
      });
      if (mounted) Navigator.pop(context); // close sheet
      _showToast('Complaint updated successfully!');
    } catch (e) {
      setState(() => _isUpdating = false);
      _showToast('Failed to update. Please try again.', success: false);
    }
  }

  void _showUpdateSheet() {
    // Reset controllers to current complaint values each time sheet opens
    _updateTitleCtrl.text = _complaint.title;
    _updateDescCtrl.text = _complaint.description;
    _updateCategory = _complaint.category;

    final List<Map<String, dynamic>> categories = [
      {'name': 'Roads',       'icon': Icons.edit_road,          'color': Color(0xFF2563EB), 'bgColor': Color(0xFFDCEAFF)},
      {'name': 'Water',       'icon': Icons.water_drop,          'color': Color(0xFF0891B2), 'bgColor': Color(0xFFCFFAFE)},
      {'name': 'Sanitation',  'icon': Icons.delete_sweep,        'color': Color(0xFF16A34A), 'bgColor': Color(0xFFDCFCE7)},
      {'name': 'Power',       'icon': Icons.lightbulb,           'color': Color(0xFFCA8A04), 'bgColor': Color(0xFFFEF3C7)},
      {'name': 'Parks',       'icon': Icons.park,                'color': Color(0xFFEA580C), 'bgColor': Color(0xFFFFEDD5)},
      {'name': 'Safety',      'icon': Icons.health_and_safety,   'color': Color(0xFF9333EA), 'bgColor': Color(0xFFF3E8FF)},
      {'name': 'Noise',       'icon': Icons.volume_up,           'color': Color(0xFFDB2777), 'bgColor': Color(0xFFFFE4F0)},
      {'name': 'Transport',   'icon': Icons.directions_bus,      'color': Color(0xFF0284C7), 'bgColor': Color(0xFFE0F2FE)},
      {'name': 'Buildings',   'icon': Icons.apartment,           'color': Color(0xFF64748B), 'bgColor': Color(0xFFF1F5F9)},
      {'name': 'Animals',     'icon': Icons.pets,                'color': Color(0xFFD97706), 'bgColor': Color(0xFFFEF3C7)},
      {'name': 'Environment', 'icon': Icons.eco,                 'color': Color(0xFF15803D), 'bgColor': Color(0xFFDCFCE7)},
      {'name': 'Healthcare',  'icon': Icons.local_hospital,      'color': Color(0xFFDC2626), 'bgColor': Color(0xFFFEE2E2)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (_, scrollCtrl) => Column(
                  children: [
                    // ── Handle + Header ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 40, height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  // ignore: duplicate_ignore
                                  // ignore: deprecated_member_use
                                  color: const Color(0xFF195DE6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.edit_outlined,
                                    color: Color(0xFF195DE6), size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Update Complaint',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1E293B))),
                                    Text('Edit the details below',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close,
                                    color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        ],
                      ),
                    ),

                    // ── Scrollable fields ────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            const Text('Title',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B))),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _updateTitleCtrl,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B)),
                              decoration: _inputDecoration(
                                  'Brief title of the issue'),
                            ),
                            const SizedBox(height: 20),

                            // Category picker
                            const Text('Category',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B))),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: List.generate(
                                    categories.length, (i) {
                                  final cat = categories[i];
                                  final sel =
                                      _updateCategory == cat['name'];
                                  final isLast =
                                      i == categories.length - 1;
                                  return Column(
                                    children: [
                                      InkWell(
                                        onTap: () => setSheetState(() =>
                                            _updateCategory =
                                                cat['name'] as String),
                                        borderRadius: BorderRadius.vertical(
                                          top: i == 0
                                              ? const Radius.circular(12)
                                              : Radius.zero,
                                          bottom: isLast
                                              ? const Radius.circular(12)
                                              : Radius.zero,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: sel
                                                ? const Color(0xFF195DE6)
                                                    // ignore: duplicate_ignore
                                                    // ignore: deprecated_member_use
                                                    .withOpacity(0.06)
                                                : Colors.transparent,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36, height: 36,
                                                decoration: BoxDecoration(
                                                  color: sel
                                                      ? const Color(0xFF195DE6)
                                                          // ignore: duplicate_ignore
                                                          // ignore: deprecated_member_use
                                                          .withOpacity(0.12)
                                                      : cat['bgColor'] as Color,
                                                  borderRadius:
                                                      BorderRadius.circular(9),
                                                ),
                                                child: Icon(
                                                  cat['icon'] as IconData,
                                                  color: sel
                                                      ? const Color(0xFF195DE6)
                                                      : cat['color'] as Color,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  cat['name'] as String,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: sel
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: sel
                                                        ? const Color(
                                                            0xFF195DE6)
                                                        : const Color(
                                                            0xFF1E293B),
                                                  ),
                                                ),
                                              ),
                                              if (sel)
                                                Container(
                                                  width: 22, height: 22,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Color(0xFF195DE6),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                      Icons.check,
                                                      color: Colors.white,
                                                      size: 13),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (!isLast)
                                        const Divider(
                                            height: 1,
                                            color: Color(0xFFF1F5F9),
                                            indent: 62),
                                    ],
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Description
                            const Text('Description',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B))),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _updateDescCtrl,
                              maxLines: 5,
                              maxLength: 500,
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF1E293B)),
                              decoration: _inputDecoration(
                                  'Describe the issue in detail...'),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),

                    // ── Save button ──────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20,
                          MediaQuery.of(ctx).padding.bottom + 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isUpdating ? null : _updateComplaint,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF195DE6),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            disabledBackgroundColor:
                                const Color(0xFF94A3B8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isUpdating
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Colors.white)),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Save Changes',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: Color(0xFF94A3B8), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFFAFBFF),
      counterStyle:
          const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF195DE6), width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(14),
    );
  }

  void _showToast(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? const Color(0xFF16A34A) : const Color(0xFF64748B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _copyId() {
    Clipboard.setData(ClipboardData(text: _complaint.complaintId));
    _showToast('Complaint ID copied to clipboard.');
  }

  // ─── Dialogs ────────────────────────────────────────────────────────────────

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Danger icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.delete_forever_outlined,
                  size: 38,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Complaint?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This action is permanent and cannot be undone. The complaint and all its data will be removed forever.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Go Back',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteComplaint();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = _complaint;
    final catColor = _categoryColor(c.category);
    final catIcon = _categoryIcon(c.category);
    final shortId = '#${c.complaintId.substring(0, 8).toUpperCase()}';
    final hasImage = c.imageUrl.isNotEmpty;

    Color statusBg;
    Color statusFg;
    IconData statusIcon;
    if (c.status == 'Resolved') {
      statusBg = const Color(0xFFDCFCE7);
      statusFg = const Color(0xFF15803D);
      statusIcon = Icons.check_circle_outline;
    } else if (c.status == 'In Progress') {
      statusBg = const Color(0xFFDCEAFF);
      statusFg = const Color(0xFF2563EB);
      statusIcon = Icons.autorenew;
    } else if (c.status == 'Cancelled') {
      statusBg = const Color(0xFFF1F5F9);
      statusFg = const Color(0xFF64748B);
      statusIcon = Icons.cancel_outlined;
    } else {
      statusBg = const Color(0xFFFFEDD5);
      statusFg = const Color(0xFFC2410C);
      statusIcon = Icons.pending_outlined;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── App Bar with hero image / colored header ──
              SliverAppBar(
                expandedHeight: hasImage ? 280 : 180,
                pinned: true,
                backgroundColor: Colors.white,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 18, color: Color(0xFF1E293B)),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: hasImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              c.imageUrl,
                              fit: BoxFit.cover,
                              // ignore: unnecessary_underscores
                              errorBuilder: (_, __, ___) =>
                                  _coloredHeader(catColor, catIcon),
                            ),
                            // Gradient overlay bottom
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      const Color(0xFFF6F6F8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : _coloredHeader(catColor, catIcon),
                ),
              ),

              // ── Content ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + status row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              c.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E293B),
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 13, color: statusFg),
                                const SizedBox(width: 4),
                                Text(
                                  c.status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: statusFg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ID row with copy
                      GestureDetector(
                        onTap: _copyId,
                        child: Row(
                          children: [
                            Text(
                              shortId,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy,
                                size: 14, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Info card ──
                      _infoCard([
                        _infoRow(Icons.category_outlined, 'Category',
                            c.category, catColor),
                        _divider(),
                        _infoRow(Icons.calendar_today_outlined, 'Submitted',
                            _formatDate(c.createdAt), const Color(0xFF64748B)),
                        _divider(),
                        _infoRow(Icons.access_time, 'Time',
                            _timeAgo(c.createdAt), const Color(0xFF64748B)),
                      ]),

                      const SizedBox(height: 16),

                      // ── Description ──
                      _sectionTitle('Description'),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Text(
                          c.description.isNotEmpty
                              ? c.description
                              : 'No description provided.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                            height: 1.6,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Location ──
                      _sectionTitle('Location'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCEAFF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on,
                                      size: 18, color: Color(0xFF195DE6)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.address.isNotEmpty
                                            ? c.address
                                            : 'Address not available',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                          height: 1.4,
                                        ),
                                      ),
                                      if (c.latitude != 0 && c.longitude != 0)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Lat: ${c.latitude.toStringAsFixed(6)},  Long: ${c.longitude.toStringAsFixed(6)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Status Timeline ──
                      _sectionTitle('Status Timeline'),
                      const SizedBox(height: 10),
                      _buildTimeline(c.status, c.createdAt),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Bottom Action Bar ──
          if (!_isDeleting)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Update button — only show if complaint can be updated
                    if (_canUpdate) ...[Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showUpdateSheet,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Update'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF195DE6),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            backgroundColor: const Color(0xFFEFF6FF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    // Delete button — always visible
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showDeleteConfirmation,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE2E2),
                          foregroundColor: const Color(0xFFDC2626),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
                color: Colors.white,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF195DE6)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Small helpers ───────────────────────────────────────────────────────────

  Widget _coloredHeader(Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, size: 72, color: Colors.white.withOpacity(0.5)),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9));

  Widget _infoRow(IconData icon, String label, String value, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(String status, DateTime createdAt) {
    final steps = [
      {'label': 'Submitted', 'icon': Icons.send_outlined, 'done': true},
      {
        'label': 'Under Review',
        'icon': Icons.manage_search_outlined,
        'done': status == 'In Progress' ||
            status == 'Resolved' ||
            status == 'Cancelled',
      },
      {
        'label': 'In Progress',
        'icon': Icons.autorenew,
        'done': status == 'Resolved',
      },
      {
        'label': status == 'Cancelled' ? 'Cancelled' : 'Resolved',
        'icon': status == 'Cancelled'
            ? Icons.cancel_outlined
            : Icons.check_circle_outline,
        'done': status == 'Resolved' || status == 'Cancelled',
        'isFinal': true,
        'isRed': status == 'Cancelled',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: List.generate(steps.length, (i) {
          final step = steps[i];
          final isDone = step['done'] as bool;
          final isRed = (step['isRed'] as bool?) ?? false;
          final isLast = i == steps.length - 1;
          final activeColor = isRed
              ? const Color(0xFFDC2626)
              : const Color(0xFF195DE6);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + line
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDone
                          ? activeColor.withOpacity(0.12)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDone ? activeColor : const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      step['icon'] as IconData,
                      size: 17,
                      color: isDone ? activeColor : const Color(0xFFCBD5E1),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 28,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isDone
                            ? activeColor.withOpacity(0.3)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  step['label'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isDone ? FontWeight.w700 : FontWeight.w500,
                    color: isDone
                        ? (isRed
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF1E293B))
                        : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}