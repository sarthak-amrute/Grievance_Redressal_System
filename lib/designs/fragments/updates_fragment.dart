import 'package:flutter/material.dart';

class UpdatesFragment extends StatelessWidget {
  const UpdatesFragment({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            const Text(
              'Updates & News',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stay informed about your community',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 32),
            _buildUpdatesList(),
            const SizedBox(height: 160),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesList() {
    return Column(
      children: [
        _buildUpdateCard(
          'System Maintenance Scheduled',
          'The complaint system will undergo maintenance on Feb 20. Services may be temporarily unavailable.',
          '2 hours ago',
          Icons.info_outline,
          const Color(0xFF2563EB),
          const Color(0xFFDCEAFF),
        ),
        const SizedBox(height: 16),
        _buildUpdateCard(
          'New Road Repair Initiative',
          'The city has started a major road repair project covering Main Street and surrounding areas.',
          '1 day ago',
          Icons.construction,
          const Color(0xFFCA8A04),
          const Color(0xFFFEF3C7),
        ),
        const SizedBox(height: 16),
        _buildUpdateCard(
          'Water Supply Update',
          'Water supply has been restored in the Park area. Thank you for your patience.',
          '3 days ago',
          Icons.water_drop,
          const Color(0xFF0891B2),
          const Color(0xFFCFFAFE),
        ),
        const SizedBox(height: 16),
        _buildUpdateCard(
          'Community Meeting',
          'Join us for a community meeting to discuss local improvements on Feb 25 at City Hall.',
          '5 days ago',
          Icons.groups,
          const Color(0xFF9333EA),
          const Color(0xFFF3E8FF),
        ),
      ],
    );
  }

  Widget _buildUpdateCard(
    String title,
    String description,
    String time,
    IconData icon,
    Color iconColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}