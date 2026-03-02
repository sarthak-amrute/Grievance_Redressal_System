// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'admin_complaint_detail_screen.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  int _tabIndex = 0;
  String _selectedFilter = 'ALL';
  Map<String, dynamic>? _selectedComplaint;
  String? _selectedComplaintId;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _tabs = ['Active', 'Priority', 'Assigned'];
  // ✅ FIXED: filters match actual category values in Firestore
  final List<String> _filters = ['ALL', 'Roads', 'Water', 'Sanitation', 'Electricity'];

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(18.5204, 73.8567), // ✅ Pune (matches your data)
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMarkers() async {
    try {
      // ✅ FIXED: collection is 'complaints' not 'grievances'
      final snapshot = await _firestore.collection('complaints').get();

      final Set<Marker> newMarkers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // ✅ FIXED: field names match Firestore screenshot
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        if (lat == null || lng == null) continue;

        final status = (data['status'] as String? ?? 'pending').toLowerCase();
        final category = data['category'] as String? ?? '';

        // Apply category filter
        if (_selectedFilter != 'ALL' &&
            !category.toLowerCase().contains(_selectedFilter.toLowerCase())) {
          continue;
        }

        final hue = _markerHue(status);

        final marker = Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: category.isEmpty ? 'Complaint' : category,
            // ✅ FIXED: use 'address' field not 'location'
            snippet: data['address'] as String? ?? '',
          ),
          onTap: () {
            setState(() {
              _selectedComplaint = data;
              _selectedComplaintId = doc.id;
            });
          },
        );

        newMarkers.add(marker);
      }

      if (mounted) {
        setState(() {
          _markers.clear();
          _markers.addAll(newMarkers);
        });
      }
    } catch (e) {
      debugPrint('Map load error: $e');
    }
  }

  double _markerHue(String status) {
    switch (status) {
      case 'escalated':
        return BitmapDescriptor.hueRed;
      case 'pending':
        return BitmapDescriptor.hueOrange;
      case 'in progress':
        return BitmapDescriptor.hueBlue;
      case 'resolved':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueViolet;
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
            _buildTabs(),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: _defaultPosition,
                    markers: _markers,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    onTap: (_) {
                      setState(() => _selectedComplaint = null);
                    },
                  ),
                  _buildSearchBar(),
                  _buildFilterChips(),
                  if (_selectedComplaint != null)
                    Positioned(
                      top: 130,
                      left: 12,
                      right: 12,
                      child: _buildComplaintPopup(),
                    ),
                  Positioned(
                    bottom: 16,
                    left: 12,
                    child: _buildLegend(),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 12,
                    child: _buildMapControls(),
                  ),
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.map_rounded,
                color: Color(0xFF1A4DB7), size: 20),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'City Complaint Map',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _markers.clear());
              _loadMarkers();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.refresh,
                  size: 18, color: Color(0xFF1A4DB7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Column(
      children: [
        Row(
          children: List.generate(_tabs.length, (i) {
            final selected = _tabIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 16 : 8, right: 8),
                child: Column(
                  children: [
                    Text(
                      _tabs[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? const Color(0xFF1A4DB7)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (selected)
                      Container(
                          height: 2,
                          width: 50,
                          color: const Color(0xFF1A4DB7))
                    else
                      const SizedBox(height: 2),
                  ],
                ),
              ),
            );
          }),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: const InputDecoration(
            hintText: 'Search category or area...',
            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            prefixIcon:
                Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
            suffixIcon:
                Icon(Icons.tune, color: Color(0xFF94A3B8), size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Positioned(
      top: 74,
      left: 12,
      right: 12,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            final selected = _selectedFilter == f;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedFilter = f);
                // Reload markers with new filter
                setState(() => _markers.clear());
                _loadMarkers();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1A4DB7)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  f,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildComplaintPopup() {
    // ✅ FIXED: use correct field names from Firestore
    final description =
        _selectedComplaint!['description'] as String? ?? 'Unknown Issue';
    final createdAt = _selectedComplaint!['createdAt'] as Timestamp?;
    final address = _selectedComplaint!['address'] as String? ?? '';
    final category = _selectedComplaint!['category'] as String? ?? '';
    final status = _selectedComplaint!['status'] as String? ?? 'Pending';
    final timeAgo = createdAt != null ? _timeAgo(createdAt.toDate()) : '';

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'in progress':
        statusColor = const Color(0xFF1A4DB7);
        break;
      case 'resolved':
        statusColor = const Color(0xFF10B981);
        break;
      default:
        statusColor = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.isEmpty ? 'Complaint' : category,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.isEmpty ? timeAgo : '$timeAgo • $address',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description.length > 70
                ? '${description.substring(0, 70)}...'
                : description,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF475569), height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    if (_selectedComplaintId == null) return;
                    // ✅ FIXED: collection is 'complaints'
                    await _firestore
                        .collection('complaints')
                        .doc(_selectedComplaintId)
                        .update({
                      'status': 'In Progress',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (mounted) {
                      setState(() => _selectedComplaint = null);
                      _loadMarkers();
                    }
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A4DB7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'Mark In Progress',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_selectedComplaintId != null &&
                        _selectedComplaint != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminComplaintDetailScreen(
                            complaintId: _selectedComplaintId!,
                            data: _selectedComplaint!,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _selectedComplaint = null),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close,
                      size: 16, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendItem(const Color(0xFFEF4444), 'Escalated'),
          const SizedBox(height: 6),
          _legendItem(const Color(0xFFF59E0B), 'Pending'),
          const SizedBox(height: 6),
          _legendItem(const Color(0xFF1A4DB7), 'In Progress'),
          const SizedBox(height: 6),
          _legendItem(const Color(0xFF10B981), 'Resolved'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildMapControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _mapButton(Icons.my_location, () {
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(_defaultPosition),
          );
        }),
        const SizedBox(height: 8),
        _mapButton(Icons.add, () {
          _mapController?.animateCamera(CameraUpdate.zoomIn());
        }),
        const SizedBox(height: 8),
        _mapButton(Icons.remove, () {
          _mapController?.animateCamera(CameraUpdate.zoomOut());
        }),
      ],
    );
  }

  Widget _mapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}