import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class PrivacySafetyView extends StatefulWidget {
  final ApiService apiService;

  const PrivacySafetyView({super.key, required this.apiService});

  @override
  State<PrivacySafetyView> createState() => _PrivacySafetyViewState();
}

class _PrivacySafetyViewState extends State<PrivacySafetyView> {
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoadingLogs = true;

  @override
  void initState() {
    super.initState();
    _fetchAuditLogs();
  }

  Future<void> _fetchAuditLogs() async {
    setState(() => _isLoadingLogs = true);
    final logs = await widget.apiService.getSafetyAuditLogs(limit: 25);
    if (mounted) {
      setState(() {
        _auditLogs = logs;
        _isLoadingLogs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clinical Safety & Privacy Architecture',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.charcoal, letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sakhi is built with deterministic clinical guardrails to protect user safety, prevent AI hallucination, and ensure transparent, consent-based health data handling.',
            style: TextStyle(fontSize: 13.5, color: AppColors.charcoalMuted),
          ),

          const SizedBox(height: 20),

          // Core Safety Invariants Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 750;
              final cardWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildPrincipleCard(
                    title: 'Deterministic Pre & Post Checks',
                    description:
                        'Safety screening operates independently of Gemini. Acute red flags (severe sudden pain, excessive hemorrhage, syncope) are screened immediately before any model call.',
                    icon: Icons.shield_outlined,
                    width: cardWidth,
                  ),
                  _buildPrincipleCard(
                    title: 'Strict Non-Diagnostic Invariant',
                    description:
                        'Sakhi will never diagnose PCOS or declare that a single symptom confirms insulin resistance. The Rotterdam Consensus requires objective clinical and ultrasound testing.',
                    icon: Icons.health_and_safety_outlined,
                    width: cardWidth,
                  ),
                  _buildPrincipleCard(
                    title: 'No Prescriptions or Dosing Directives',
                    description:
                        'Medication prescriptions (such as metformin, birth control, or hormonal regulators) are strictly forbidden and scrubbed by post-generation interception.',
                    icon: Icons.medication_outlined,
                    width: cardWidth,
                  ),
                  _buildPrincipleCard(
                    title: 'Explicit Consent Persistence',
                    description:
                        'No health description or confirmed symptom is ever persisted to our database without the user explicitly checking the consent confirmation box.',
                    icon: Icons.lock_outline,
                    width: cardWidth,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // When to Seek Professional Clinical Care
          Card(
            color: AppColors.sageGreenLight,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_hospital_outlined, color: AppColors.forestGreen, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'When to Seek Immediate or Professional Medical Care',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sakhi is an educational preparation companion. You should schedule a clinical consultation with a licensed healthcare professional if:',
                    style: TextStyle(fontSize: 13, color: AppColors.charcoalMuted),
                  ),
                  const SizedBox(height: 10),
                  const Text('• You notice your menstrual cycles are consistently longer than 35 days or shorter than 21 days.', style: TextStyle(fontSize: 12.5, height: 1.3)),
                  const SizedBox(height: 4),
                  const Text('• You have gone more than 3 consecutive months without a menstrual period (amenorrhea).', style: TextStyle(fontSize: 12.5, height: 1.3)),
                  const SizedBox(height: 4),
                  const Text('• You experience rapid or distressing new facial hair growth, severe acne, or significant scalp hair thinning.', style: TextStyle(fontSize: 12.5, height: 1.3)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.emergencyRedLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.emergency, color: AppColors.emergencyRed, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'EMERGENCY: Sudden severe pelvic pain, dizziness with fainting, or bleeding soaking 2+ pads/hour requires immediate Emergency Room evaluation.',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.emergencyRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Deterministic Safety Engine Flow
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deterministic Processing Pipeline',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The strict sequence executed on every user request:',
                    style: TextStyle(fontSize: 13, color: AppColors.charcoalMuted),
                  ),
                  const SizedBox(height: 16),
                  _buildPipelineStep('1. Urgent Symptom Screening', 'Detects acute emergencies and redirects directly to urgent care before invoking any LLM.'),
                  _buildPipelineStep('2. Structured Extraction', 'Gemini extracts structured observations, validated strictly against Pydantic schemas.'),
                  _buildPipelineStep('3. Guideline Retrieval', 'Evidence is retrieved from vetted sources (ACOG, Monash, NIH). Sources are strictly attributed.'),
                  _buildPipelineStep('4. Response Validation', 'Generated text is screened to block diagnostic certainty and prescription recommendations.'),
                  _buildPipelineStep('5. Append-Only Audit', 'An immutable record is stored in safety_audit_logs. Editing or deleting audit logs is disabled.'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Append-Only Safety Audit Log Viewer
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Append-Only Safety Audit Trail', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.charcoal)),
                          SizedBox(height: 2),
                          Text('Live compliance audit log. Never exposes sensitive raw user text or secrets.', style: TextStyle(fontSize: 12, color: AppColors.charcoalMuted)),
                        ],
                      ),
                      IconButton(
                        onPressed: _fetchAuditLogs,
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Refresh Audit Log',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingLogs)
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.sageGreen)))
                  else if (_auditLogs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      child: const Text('No safety audit events recorded yet in current database session.', style: TextStyle(color: AppColors.charcoalMuted)),
                    )
                  else
                    Table(
                      border: const TableBorder(horizontalInside: BorderSide(color: AppColors.borderColor, width: 0.8)),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: AppColors.sageGreenLight),
                          children: [
                            Padding(padding: EdgeInsets.all(8), child: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Rule Triggered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Action Taken', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                            Padding(padding: EdgeInsets.all(8), child: Text('Safety Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                          ],
                        ),
                        ..._auditLogs.take(8).map((log) {
                          final status = log['final_safety_status'] ?? '-';
                          final isUrgent = status == 'BLOCKED_URGENT';
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8), child: Text(log['timestamp']?.toString().substring(11, 19) ?? '-', style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(8), child: Text(log['rule_triggered'] ?? 'NONE', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                              Padding(padding: const EdgeInsets.all(8), child: Text(log['action_taken'] ?? '-', style: const TextStyle(fontSize: 11))),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isUrgent ? AppColors.emergencyRed : AppColors.forestGreen,
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

  Widget _buildPrincipleCard({required String title, required String description, required IconData icon, required double width}) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.sageGreenLight, borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: AppColors.forestGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.charcoal))),
                ],
              ),
              const SizedBox(height: 12),
              Text(description, style: const TextStyle(fontSize: 13, color: AppColors.charcoalMuted, height: 1.45)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPipelineStep(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right_alt, color: AppColors.forestGreen, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.charcoal, height: 1.35),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.forestGreen)),
                  TextSpan(text: subtitle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
