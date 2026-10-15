import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';

class OverviewView extends StatefulWidget {
  final ApiService apiService;
  final String sessionId;
  final Function(int) onNavigate;

  const OverviewView({
    super.key,
    required this.apiService,
    required this.sessionId,
    required this.onNavigate,
  });

  @override
  State<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends State<OverviewView> {
  CycleAnalyticsResult? _analytics;
  List<Map<String, dynamic>> _symptomHistory = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadOverviewData();
  }

  @override
  void didUpdateWidget(covariant OverviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _loadOverviewData();
    }
  }

  Future<void> _loadOverviewData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final analytics = await widget.apiService.getCycleAnalytics(widget.sessionId);
      final history = await widget.apiService.getSymptomHistory(widget.sessionId);
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _symptomHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = widget.sessionId.contains('demo');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Demonstration Profile Notice
          if (isDemo)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warningOrangeLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, color: AppColors.warningOrange, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'DEMONSTRATION PROFILE: You are viewing seeded, illustrative patient baseline data. This is not real medical history and is provided solely for interface evaluation.',
                      style: TextStyle(color: AppColors.charcoal, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _loadOverviewData(),
                    child: const Text('Refresh', style: TextStyle(fontSize: 12, color: AppColors.warningOrange)),
                  ),
                ],
              ),
            ),

          // Backend Connection Notice if offline
          if (_loadError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warningOrangeLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: AppColors.warningOrange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Backend unreachable at ${widget.apiService.baseUrl}. Tap the connection chip in the top bar to adjust endpoint port.',
                      style: const TextStyle(color: AppColors.charcoal, fontSize: 12.5),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _loadOverviewData(),
                    child: const Text('Retry', style: TextStyle(fontSize: 12, color: AppColors.forestGreen)),
                  ),
                ],
              ),
            ),

          // Welcome & Product Purpose Banner
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.sageGreenLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD7E5DC), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.forestGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Sakhi Companion',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Non-Diagnostic Clinical Bridge',
                            style: TextStyle(fontSize: 12, color: AppColors.sageGreen, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Understand your symptoms.\nFind your next step.',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                          height: 1.25,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sakhi helps women translate vernacular symptom descriptions into structured clinical observations, track longitudinal cycle intervals over 6 months, and prepare for confident conversations with healthcare providers.',
                        style: TextStyle(fontSize: 13.5, color: AppColors.charcoalMuted, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => widget.onNavigate(1), // Symptom Companion
                            icon: const Icon(Icons.chat_bubble_outline, size: 17),
                            label: const Text('Start Symptom Check'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => widget.onNavigate(2), // Cycle Insights
                            icon: const Icon(Icons.calendar_today_outlined, size: 17),
                            label: const Text('View Cycle History'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => widget.onNavigate(4), // Doctor Report
                            icon: const Icon(Icons.description_outlined, size: 17),
                            label: const Text('Doctor Consultation Report'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.eco_rounded, color: AppColors.forestGreen, size: 40),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Overview Stats Grid
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.sageGreen)),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 750;
                final cardWidth = isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildStatCard(
                      title: 'Cycles Logged',
                      value: '${_analytics?.totalRecordedCycles ?? 0}',
                      subtitle: _analytics != null && _analytics!.totalRecordedCycles > 0
                          ? 'Past 6-month observation'
                          : 'No data recorded yet',
                      icon: Icons.calendar_month_outlined,
                      width: cardWidth,
                      isMissingData: _analytics?.totalRecordedCycles == 0,
                    ),
                    _buildStatCard(
                      title: 'Mean Interval',
                      value: _analytics?.averageGapDays != null ? '${_analytics!.averageGapDays} days' : 'No data',
                      subtitle: _analytics?.averageGapDays != null ? 'Consecutive cycle average' : 'Requires >= 2 entries',
                      icon: Icons.timelapse_outlined,
                      width: cardWidth,
                      isMissingData: _analytics?.averageGapDays == null,
                    ),
                    _buildStatCard(
                      title: 'Variability (SD)',
                      value: _analytics?.variationSd != null ? '±${_analytics!.variationSd}d' : 'No data',
                      subtitle: _analytics?.irregularityFlag == true ? 'Irregularity flagged (>7d)' : 'Regular interval (<7d)',
                      icon: Icons.auto_graph_outlined,
                      width: cardWidth,
                      isWarning: _analytics?.irregularityFlag == true,
                      isMissingData: _analytics?.variationSd == null,
                    ),
                    _buildStatCard(
                      title: 'Confirmed Logs',
                      value: '${_symptomHistory.length}',
                      subtitle: 'Explicitly consented records',
                      icon: Icons.assignment_turned_in_outlined,
                      width: cardWidth,
                      isMissingData: _symptomHistory.isEmpty,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            // Two-column layout: Recent Cycle Status & Logged Symptoms
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Menstrual Cycle Snapshot Card
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Cycle Observation Summary',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.charcoal),
                              ),
                              TextButton.icon(
                                onPressed: () => widget.onNavigate(2),
                                icon: const Icon(Icons.arrow_forward, size: 15),
                                label: const Text('Manage Dates', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_analytics == null || _analytics!.history.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.ivoryBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderColor),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.event_busy_outlined, size: 36, color: AppColors.charcoalLight),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No cycle entries recorded yet',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Record consecutive period start dates in Cycle Insights to view intervals and variability.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppColors.charcoalMuted),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () => widget.onNavigate(2),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Period Date'),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _analytics!.irregularityFlag ? AppColors.warningOrangeLight : AppColors.sageGreenLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _analytics!.irregularityFlag ? Icons.info_outline : Icons.check_circle_outline,
                                    color: _analytics!.irregularityFlag ? AppColors.warningOrange : AppColors.sageGreen,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _analytics!.clinicalNote,
                                      style: const TextStyle(fontSize: 12.5, color: AppColors.charcoal, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Recent Entries:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.charcoalMuted)),
                            const SizedBox(height: 8),
                            ..._analytics!.history.take(4).map(
                                  (c) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.borderColor),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.water_drop_outlined, size: 15, color: AppColors.sageGreen),
                                        const SizedBox(width: 8),
                                        Text(
                                          c.periodStartDate,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.charcoal),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.sageGreenLight,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            c.cycleGapDays != null ? '${c.cycleGapDays}d gap' : 'Baseline',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Flow: ${c.flowIntensity}',
                                          style: const TextStyle(fontSize: 11.5, color: AppColors.charcoalMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Recent Confirmed Symptoms Card
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Symptoms',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.charcoal),
                              ),
                              TextButton.icon(
                                onPressed: () => widget.onNavigate(1),
                                icon: const Icon(Icons.add, size: 15),
                                label: const Text('Check', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_symptomHistory.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.ivoryBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderColor),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.notes_outlined, size: 36, color: AppColors.charcoalLight),
                                  SizedBox(height: 8),
                                  Text('No symptoms saved yet', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal)),
                                  SizedBox(height: 4),
                                  Text(
                                    'Entries you confirm and consent to store will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppColors.charcoalMuted),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._symptomHistory.take(3).map((item) {
                              final symptoms = (item['confirmed_symptoms'] as List<dynamic>?) ?? [];
                              final timestamp = item['timestamp']?.toString().substring(0, 10) ?? '';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.borderColor),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            symptoms.join(', '),
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.charcoal),
                                          ),
                                        ),
                                        if (timestamp.isNotEmpty)
                                          Text(timestamp, style: const TextStyle(fontSize: 11, color: AppColors.charcoalLight)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['original_description'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.charcoalMuted),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required double width,
    bool isWarning = false,
    bool isMissingData = false,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppColors.charcoalMuted, fontWeight: FontWeight.w600)),
                  Icon(
                    icon,
                    size: 19,
                    color: isWarning
                        ? AppColors.warningOrange
                        : (isMissingData ? AppColors.charcoalLight : AppColors.forestGreen),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isWarning
                      ? AppColors.warningOrange
                      : (isMissingData ? AppColors.charcoalMuted : AppColors.charcoal),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isMissingData ? AppColors.charcoalLight : AppColors.charcoalMuted,
                  fontStyle: isMissingData ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
