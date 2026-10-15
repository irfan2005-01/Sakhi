import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';

class DoctorReportView extends StatefulWidget {
  final ApiService apiService;
  final String sessionId;

  const DoctorReportView({
    super.key,
    required this.apiService,
    required this.sessionId,
  });

  @override
  State<DoctorReportView> createState() => _DoctorReportViewState();
}

class _DoctorReportViewState extends State<DoctorReportView> {
  bool _isGenerating = false;
  CycleAnalyticsResult? _analytics;
  List<Map<String, dynamic>> _symptomHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant DoctorReportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final a = await widget.apiService.getCycleAnalytics(widget.sessionId);
      final s = await widget.apiService.getSymptomHistory(widget.sessionId);
      if (mounted) {
        setState(() {
          _analytics = a;
          _symptomHistory = s;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _isGenerating = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      List<String> confirmed = [];
      for (var s in _symptomHistory) {
        final symList = (s['confirmed_symptoms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        confirmed.addAll(symList);
      }
      confirmed = confirmed.toSet().toList();

      final pdfBytes = await widget.apiService.generateDoctorReportPdf(
        sessionId: widget.sessionId,
        confirmedSymptoms: confirmed.isNotEmpty ? confirmed : ['Irregular Menstrual Intervals', 'Clinical Consultation Preparation'],
        patientNotes: 'Generated via Sakhi Clinical Companion for physician consultation prep.',
      );

      await ApiService.openOrDownloadPdf(pdfBytes, 'Sakhi_Doctor_Consultation_Summary_${widget.sessionId}.pdf');

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Doctor consultation PDF report generated and opened/downloaded.'),
            backgroundColor: AppColors.sageGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e\nEnsure backend is running at ${widget.apiService.baseUrl}.'),
            backgroundColor: AppColors.emergencyRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.sageGreen));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doctor Consultation Report',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.charcoal, letterSpacing: -0.3),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Export a structured, one-page clinical summary to bring to your gynecologist or endocrinologist.',
                    style: TextStyle(fontSize: 13.5, color: AppColors.charcoalMuted),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _downloadPdf,
                icon: _isGenerating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.file_download_outlined, size: 17),
                label: Text(_isGenerating ? 'Generating PDF...' : 'Download Clinical Summary PDF'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Non-Diagnostic Prominent Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.ivoryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, color: AppColors.forestGreen, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'IMPORTANT NOTICE: This report is a patient self-advocacy discussion document. It does NOT constitute a clinical diagnosis, laboratory assessment, or medication prescription.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.charcoal, height: 1.3),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Report Preview Sheet Container (Simulates the 1-page paper document)
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 820),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 18, offset: const Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Paper Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sakhi Clinical Bridge',
                            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.forestGreen, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Doctor Consultation Summary & Patient Self-Advocacy Sheet',
                            style: TextStyle(fontSize: 12, color: AppColors.charcoalMuted, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.sageGreenLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Text(
                          'Session: ${widget.sessionId}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: AppColors.forestGreen, thickness: 1.5),
                  const SizedBox(height: 18),

                  // Section 1: Patient-Reported Symptoms
                  const Text('1. PATIENT-CONFIRMED SYMPTOM OBSERVATIONS', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.forestGreen)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.ivoryBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: _symptomHistory.isEmpty
                        ? const Text('• Menstrual cycle irregularity noted. Detailed symptom analysis pending user session log.', style: TextStyle(fontSize: 12))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _symptomHistory.map((s) {
                              final symList = (s['confirmed_symptoms'] as List<dynamic>?)?.join(', ') ?? 'Symptoms logged';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('• $symList (Original vernacular description: "${s['original_description'] ?? ''}")', style: const TextStyle(fontSize: 12, height: 1.35)),
                              );
                            }).toList(),
                          ),
                  ),

                  const SizedBox(height: 22),

                  // Section 2: 6-Month Cycle Analytics
                  const Text('2. MENSTRUAL CYCLE HISTORY & CALCULATED INTERVALS (6 MONTHS)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.forestGreen)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      Text('• Total Recorded Cycles: ${_analytics?.totalRecordedCycles ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('• Mean Interval Length: ${_analytics?.averageGapDays != null ? "${_analytics!.averageGapDays} days" : "No interval data"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text('• Interval Variability (SD): ${_analytics?.variationSd != null ? "±${_analytics!.variationSd}d" : "N/A"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_analytics?.history.isNotEmpty ?? false)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _analytics!.history.map((h) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderColor),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${h.periodStartDate}: ${h.cycleGapDays != null ? "${h.cycleGapDays}d interval" : "Baseline"} (${h.flowIntensity})',
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 22),

                  // Section 3: Evidence References
                  const Text('3. CLINICAL EVIDENCE GUIDELINES (ROTTERDAM CONSENSUS)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.forestGreen)),
                  const SizedBox(height: 8),
                  const Text(
                    '• Rotterdam Consensus Framework (ESHRE/ASRM): Requires at least 2 of 3 features (ovulatory dysfunction, clinical or biochemical hyperandrogenism, polycystic ovarian morphology on ultrasound) and formal exclusion of related etiologies.',
                    style: TextStyle(fontSize: 11.5, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '• Monash International PCOS Guidelines (2023): Menstrual cycles > 35 days indicate ovulatory dysfunction. Metabolic screening is recommended for ovulatory irregularity.',
                    style: TextStyle(fontSize: 11.5, height: 1.4),
                  ),

                  const SizedBox(height: 22),

                  // Section 4: Recommended Doctor Questions
                  const Text('4. SUGGESTED QUESTIONS FOR CLINICAL DISCUSSION', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.forestGreen)),
                  const SizedBox(height: 8),
                  const Text('1. Given my recorded cycle intervals, would you advise testing a fasting lipid/glucose panel, thyroid (TSH), or free testosterone?', style: TextStyle(fontSize: 12, height: 1.35)),
                  const SizedBox(height: 4),
                  const Text('2. Would a pelvic ultrasound be appropriate to evaluate ovarian morphology?', style: TextStyle(fontSize: 12, height: 1.35)),
                  const SizedBox(height: 4),
                  const Text('3. What nutritional or lifestyle adjustments are recommended for my specific symptoms?', style: TextStyle(fontSize: 12, height: 1.35)),

                  const SizedBox(height: 26),
                  const Divider(color: AppColors.borderColor),
                  const SizedBox(height: 10),

                  // Non-diagnostic Disclaimer
                  const Text(
                    'CLINICAL NOTICE: Sakhi is an informational companion and self-advocacy tool. This document does not constitute a clinical diagnosis, medical evaluation, or prescription. A diagnosis of PCOS requires formal in-person examination, laboratory hormone diagnostics, and pelvic imaging conducted by a licensed physician.',
                    style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.charcoalMuted, height: 1.35),
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
