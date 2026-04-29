import 'package:flutter/material.dart';
import '../navigation/app_nav.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_theme.dart';
import 'wfh_monitoring_upload.dart';

class WFHMonitoringScreen extends StatelessWidget {
  const WFHMonitoringScreen({
    super.key,
    required this.onNavigate,
    required this.onSignOut,
  });

  final ValueChanged<AppNavItem> onNavigate;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        selected: AppNavItem.wfhMonitoring,
        onSelect: (item) {
          Navigator.pop(context);
          onNavigate(item);
        },
        onSignOut: onSignOut,
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B66),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('WFH Monitoring'),
        actions: [
            IconButton(
              onPressed: () => onNavigate(AppNavItem.notifications),
              icon: const Icon(Icons.notifications_none),
              tooltip: 'Notifications',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
        children: [
          const Text(
            'Upload your Work Output Monitoring Sheet for a WFH day. Once HR approves it, the approved date is written to your attendance record.',
            style: TextStyle(
              color: AppColors.mutedText,
              fontSize: 14,
              height: 1.3,
            ),
          ),
          SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const WFHMonitoringUploadScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Upload New',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2B2F36),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'WFH Monitoring Submissions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4B4B4B),
                          ),
                        ),
                      ),
                      
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: const Text(
                        'No WFH monitoring sheets uploaded yet.\nUpload your first Work Output Monitoring Sheet to start the review flow.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
