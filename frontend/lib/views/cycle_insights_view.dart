import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';

class CycleInsightsView extends StatefulWidget {
  final ApiService apiService;
  final String sessionId;

  const CycleInsightsView({
    super.key,
    required this.apiService,
    required this.sessionId,
  });

  @override
  State<CycleInsightsView> createState() => _CycleInsightsViewState();
}

class _CycleInsightsViewState extends State<CycleInsightsView> {
  CycleAnalyticsResult? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  @override
  void didUpdateWidget(covariant CycleInsightsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _loadAnalytics();
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.apiService.getCycleAnalytics(widget.sessionId);
      if (mounted) {
        setState(() {
          _analytics = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddCycleDialog() {
    DateTime selectedDate = DateTime.now();
    String flowIntensity = 'medium';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Log Menstrual Cycle Start Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select the first day of your period bleeding:'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 730)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Reported Flow Intensity:'),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: flowIntensity,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'light', child: Text('Light (Spotting / Minimal)')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium (Normal)')),
                      DropdownMenuItem(value: 'heavy', child: Text('Heavy (Substantial)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => flowIntensity = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await widget.apiService.recordCycleStart(
                        sessionId: widget.sessionId,
                        periodStartDate: formattedDate,
                        flowIntensity: flowIntensity,
                      );
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Cycle entry recorded successfully.'), backgroundColor: AppColors.sageGreen),
                      );
                      _loadAnalytics();
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.emergencyRed),
                      );
                    }
                  },
                  child: const Text('Save Entry'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.sageGreen));
    }

    final history = _analytics?.history ?? [];
    final hasIntervals = history.where((h) => h.cycleGapDays != null).isNotEmpty;
    final isDemo = widget.sessionId.contains('demo');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Log Action
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cycle Insights & Longitudinal Analytics',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.charcoal, letterSpacing: -0.3),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '6-month interval tracking based exclusively on reported start dates',
                    style: TextStyle(fontSize: 13.5, color: AppColors.charcoalMuted),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddCycleDialog,
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Log Period Start Date'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Demo Banner if active
          if (isDemo)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningOrangeLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.science_outlined, color: AppColors.warningOrange, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'DEMONSTRATION HISTORY: The records below represent seeded illustrative baseline data to showcase interval analytics. In a real patient session, all fields start blank until logged.',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.charcoal, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

          // Clinical Interpretation Card
          Card(
            color: _analytics?.irregularityFlag == true ? AppColors.warningOrangeLight : AppColors.sageGreenLight,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _analytics?.irregularityFlag == true ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    color: _analytics?.irregularityFlag == true ? AppColors.warningOrange : AppColors.forestGreen,
                    size: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _analytics?.irregularityFlag == true
                              ? 'Irregular Cycle Pattern Flagged (> 35 days or SD > 7 days)'
                              : 'Cycle Pattern Status',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _analytics?.irregularityFlag == true ? AppColors.warningOrange : AppColors.charcoal,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _analytics?.clinicalNote ?? 'No cycle records logged yet.',
                          style: const TextStyle(fontSize: 13, color: AppColors.charcoal, height: 1.45),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Clinical Note: Cycle irregularity can warrant physician assessment for ovulatory dysfunction, but does NOT constitute a standalone PCOS diagnosis.',
                          style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.charcoalMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Missing Data / Skips Indicators
          if (_analytics?.missingDataIntervals.isNotEmpty ?? false)
            Container(
              margin: const EdgeInsets.only(bottom: 22),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lavenderLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lavenderAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.help_center_outlined, size: 18, color: AppColors.lavenderAccent),
                      SizedBox(width: 8),
                      Text(
                        'Missing Data / Prolonged Interval Notice:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.lavenderAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._analytics!.missingDataIntervals.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• $m', style: const TextStyle(fontSize: 12, color: AppColors.charcoal)),
                    ),
                  ),
                ],
              ),
            ),

          // Interval Gap Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      const Text(
                        'Consecutive Cycle Interval Timeline',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sageGreenLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Normal Range: 21–35 Days',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bars indicate the gap in days between consecutive reported period starts.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.charcoalMuted),
                  ),
                  const SizedBox(height: 24),
                  if (!hasIntervals)
                    Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart_outlined, size: 40, color: AppColors.charcoalLight),
                          SizedBox(height: 10),
                          Text(
                            'At least 2 recorded period start dates are required to calculate intervals.',
                            style: TextStyle(fontSize: 13, color: AppColors.charcoalMuted),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 240,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 65,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final gap = rod.toY.round();
                                return BarTooltipItem(
                                  '$gap days',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                getTitlesWidget: (val, meta) {
                                  if (val % 15 == 0) {
                                    return Text('${val.toInt()}d', style: const TextStyle(fontSize: 10, color: AppColors.charcoalMuted));
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  final idx = val.toInt();
                                  if (idx >= 0 && idx < history.length) {
                                    final d = history[idx].periodStartDate;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        d.length >= 7 ? d.substring(5) : d,
                                        style: const TextStyle(fontSize: 10, color: AppColors.charcoalMuted),
                                      ),
                                    );
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            horizontalInterval: 15,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (val) {
                              if (val == 35) {
                                return const FlLine(color: AppColors.forestGreen, strokeWidth: 1.5, dashArray: [4, 4]);
                              }
                              return const FlLine(color: AppColors.borderColor, strokeWidth: 0.8);
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: history.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final gap = item.cycleGapDays?.toDouble() ?? 28.0;
                            final isIrregular = gap > 35 || gap < 21;
                            return BarChartGroupData(
                              x: idx,
                              barRods: [
                                BarChartRodData(
                                  toY: gap,
                                  color: item.cycleGapDays == null
                                      ? AppColors.charcoalLight.withValues(alpha: 0.4)
                                      : (isIrregular ? AppColors.warningOrange : AppColors.forestGreen),
                                  width: 24,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Detailed Table of Recorded Periods
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reported Cycle Records', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.charcoal)),
                  const SizedBox(height: 12),
                  if (history.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: const Text('No records found for current session.', style: TextStyle(color: AppColors.charcoalMuted)),
                    )
                  else
                    Table(
                      border: const TableBorder(
                        horizontalInside: BorderSide(color: AppColors.borderColor, width: 0.8),
                        bottom: BorderSide(color: AppColors.borderColor, width: 0.8),
                      ),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: AppColors.sageGreenLight),
                          children: [
                            Padding(padding: EdgeInsets.all(10), child: Text('Period Start Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Calculated Interval', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Flow Intensity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(10), child: Text('Provenance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                        ...history.map((h) {
                          final isIrregular = h.cycleGapDays != null && (h.cycleGapDays! > 35 || h.cycleGapDays! < 21);
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(10), child: Text(h.periodStartDate, style: const TextStyle(fontSize: 12.5))),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  h.cycleGapDays != null ? '${h.cycleGapDays} days' : 'Baseline entry',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isIrregular ? AppColors.warningOrange : AppColors.charcoal,
                                  ),
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(10), child: Text(h.flowIntensity, style: const TextStyle(fontSize: 12.5))),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  h.isDemo ? 'Demonstration Data' : 'User Confirmed',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: h.isDemo ? AppColors.warningOrange : AppColors.forestGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
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
