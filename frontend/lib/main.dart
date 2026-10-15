import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'views/overview_view.dart';
import 'views/symptom_companion_view.dart';
import 'views/cycle_insights_view.dart';
import 'views/clinical_knowledge_view.dart';
import 'views/doctor_report_view.dart';
import 'views/privacy_safety_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SakhiApp());
}

class SakhiApp extends StatelessWidget {
  const SakhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sakhi — PCOS Symptom Companion & Clinical Bridge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SakhiDashboard(),
    );
  }
}

class SakhiDashboard extends StatefulWidget {
  const SakhiDashboard({super.key});

  @override
  State<SakhiDashboard> createState() => _SakhiDashboardState();
}

class _SakhiDashboardState extends State<SakhiDashboard> {
  final ApiService _apiService = ApiService();
  int _currentIndex = 0;
  String _currentSessionId = 'demo-pcos-patient-001';
  bool _isBackendLive = false;
  String _backendStatusText = 'Connecting (8001)...';

  final List<String> _navTitles = [
    'Overview',
    'Symptom Companion',
    'Cycle Insights',
    'Clinical Knowledge',
    'Doctor Report',
    'Privacy & Safety',
  ];

  final List<IconData> _navIcons = [
    Icons.dashboard_outlined,
    Icons.chat_bubble_outline,
    Icons.calendar_month_outlined,
    Icons.menu_book_outlined,
    Icons.picture_as_pdf_outlined,
    Icons.verified_user_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
    ApiService.baseUrlNotifier.addListener(_onBaseUrlChanged);
  }

  @override
  void dispose() {
    ApiService.baseUrlNotifier.removeListener(_onBaseUrlChanged);
    super.dispose();
  }

  void _onBaseUrlChanged() {
    _checkBackendHealth();
  }

  Future<void> _checkBackendHealth() async {
    final health = await _apiService.checkHealth();
    if (mounted) {
      setState(() {
        if (health['status'] == 'healthy') {
          _isBackendLive = true;
          final aiStatus = health['ai_engine']?['status'] ?? 'active';
          final port = Uri.tryParse(_apiService.baseUrl)?.port ?? 8001;
          _backendStatusText = 'API Connected (:$port • $aiStatus)';
        } else {
          _isBackendLive = false;
          final port = Uri.tryParse(_apiService.baseUrl)?.port ?? 8001;
          _backendStatusText = 'API Offline (:$port)';
        }
      });
    }
  }

  void _switchSession() {
    setState(() {
      if (_currentSessionId.contains('demo')) {
        _currentSessionId = 'patient-session-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      } else {
        _currentSessionId = 'demo-pcos-patient-001';
      }
    });
  }

  void _showApiConfigDialog() {
    final controller = TextEditingController(text: _apiService.baseUrl);
    bool testing = false;
    String? testResult;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings_ethernet, color: AppColors.forestGreen),
              SizedBox(width: 10),
              Text('Configure API Base URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure the backend endpoint for local hackathon testing:',
                style: TextStyle(fontSize: 12.5, color: AppColors.charcoalMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Backend URL',
                  hintText: 'http://127.0.0.1:8001',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Port 8001 (Default)', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setDialogState(() {
                        controller.text = 'http://127.0.0.1:8001';
                      });
                    },
                  ),
                  ActionChip(
                    label: const Text('Port 8000', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      setDialogState(() {
                        controller.text = 'http://127.0.0.1:8000';
                      });
                    },
                  ),
                ],
              ),
              if (testResult != null) ...[
                const SizedBox(height: 12),
                Text(
                  testResult!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: testResult!.startsWith('Connected') ? AppColors.forestGreen : AppColors.emergencyRed,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: testing
                  ? null
                  : () async {
                      setDialogState(() {
                        testing = true;
                        testResult = 'Testing connection...';
                      });
                      final tempService = ApiService();
                      tempService.baseUrl = controller.text;
                      final res = await tempService.checkHealth();
                      setDialogState(() {
                        testing = false;
                        if (res['status'] == 'healthy') {
                          testResult = 'Connected! Database: ${res['database']?['status']}';
                        } else {
                          testResult = 'Connection failed: ${res['error'] ?? res['message']}';
                        }
                      });
                    },
              child: const Text('Test Connection'),
            ),
            ElevatedButton(
              onPressed: () {
                _apiService.baseUrl = controller.text;
                Navigator.pop(dialogCtx);
                _checkBackendHealth();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return OverviewView(
          apiService: _apiService,
          sessionId: _currentSessionId,
          onNavigate: (index) => setState(() => _currentIndex = index),
        );
      case 1:
        return SymptomCompanionView(
          apiService: _apiService,
          sessionId: _currentSessionId,
        );
      case 2:
        return CycleInsightsView(
          apiService: _apiService,
          sessionId: _currentSessionId,
        );
      case 3:
        return ClinicalKnowledgeView(
          apiService: _apiService,
        );
      case 4:
        return DoctorReportView(
          apiService: _apiService,
          sessionId: _currentSessionId,
        );
      case 5:
        return PrivacySafetyView(
          apiService: _apiService,
        );
      default:
        return OverviewView(
          apiService: _apiService,
          sessionId: _currentSessionId,
          onNavigate: (index) => setState(() => _currentIndex = index),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 820;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.forestGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sakhi',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.charcoal, letterSpacing: -0.3),
                ),
                Text(
                  'Understand your symptoms. Find your next step.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.charcoalMuted.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Backend Health & Configuration Chip
          InkWell(
            onTap: _showApiConfigDialog,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isBackendLive ? AppColors.sageGreenLight : AppColors.warningOrangeLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isBackendLive
                      ? AppColors.sageGreen.withValues(alpha: 0.4)
                      : AppColors.warningOrange.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 3.5,
                    backgroundColor: _isBackendLive ? AppColors.forestGreen : AppColors.warningOrange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _backendStatusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isBackendLive ? AppColors.forestGreen : AppColors.warningOrange,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.tune, size: 13, color: AppColors.charcoalMuted),
                ],
              ),
            ),
          ),

          // Session Profile Pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentSessionId.contains('demo') ? Icons.science_outlined : Icons.person_outline,
                  size: 15,
                  color: _currentSessionId.contains('demo') ? AppColors.warningOrange : AppColors.forestGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentSessionId.contains('demo') ? 'Demo Profile (Seeded)' : 'User Session (Private)',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _switchSession,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    _currentSessionId.contains('demo') ? 'Switch to Fresh' : 'Switch to Demo',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                // Desktop Sidebar Navigation
                Container(
                  width: 230,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: AppColors.borderColor)),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
                    itemCount: _navTitles.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final isSelected = _currentIndex == index;
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          selected: isSelected,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          selectedTileColor: AppColors.sageGreenLight,
                          leading: Icon(
                            _navIcons[index],
                            color: isSelected ? AppColors.forestGreen : AppColors.charcoalMuted,
                            size: 19,
                          ),
                          title: Text(
                            _navTitles[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.forestGreen : AppColors.charcoal,
                            ),
                          ),
                          onTap: () => setState(() => _currentIndex = index),
                        ),
                      );
                    },
                  ),
                ),
                // Main Content View
                Expanded(child: _buildBody()),
              ],
            )
          : _buildBody(),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.forestGreen,
              unselectedItemColor: AppColors.charcoalMuted,
              selectedFontSize: 11,
              unselectedFontSize: 10,
              items: _navTitles.asMap().entries.map((e) {
                return BottomNavigationBarItem(
                  icon: Icon(_navIcons[e.key], size: 19),
                  label: e.value,
                );
              }).toList(),
              onTap: (index) => setState(() => _currentIndex = index),
            ),
    );
  }
}
