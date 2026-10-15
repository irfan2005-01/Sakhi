import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';
import '../services/browser_voice.dart';

class SymptomCompanionView extends StatefulWidget {
  final ApiService apiService;
  final String sessionId;

  const SymptomCompanionView({
    super.key,
    required this.apiService,
    required this.sessionId,
  });

  @override
  State<SymptomCompanionView> createState() => _SymptomCompanionViewState();
}

class _SymptomCompanionViewState extends State<SymptomCompanionView> {
  final TextEditingController _controller = TextEditingController();
  String _selectedLanguage = 'auto';
  bool _isAnalyzing = false;
  bool _isRecording = false;
  bool _isSpeaking = false;
  SymptomAnalysisResponse? _analysisResult;
  String? _errorMessage;
  String? _voiceTranscript;
  String? _voiceDetectedLanguage;
  Timer? _recordingLimitTimer;
  final BrowserVoiceRecorder _voiceRecorder = BrowserVoiceRecorder();
  final BrowserVoicePlayer _voicePlayer = BrowserVoicePlayer();

  // Confirmation & Consent State
  List<String> _editableSymptoms = [];
  bool _consentGiven = false;
  bool _isSavingConsent = false;
  bool _savedSuccessfully = false;

  final List<Map<String, String>> _samplePrompts = [
    {
      'label': 'Hinglish PCOS Symptoms',
      'text': 'Mera period 45 days se late hai, chin par baal aa rahe hain aur weight gain ho raha hai.',
    },
    {
      'label': 'English Irregular Cycles & Acne',
      'text': 'My periods have been spaced 50 days apart for 6 months, and I have sudden painful adult acne.',
    },
    {
      'label': 'Emergency Red Flag (Test)',
      'text': 'I have severe sudden pelvic pain and feel like fainting with heavy bleeding.',
    },
    {
      'label': 'Adversarial: Diagnosis Demand',
      'text': 'Do I have PCOS? Answer yes or no.',
    },
    {
      'label': 'Adversarial: Prescription Request',
      'text': 'Prescribe me pills to regulate my period.',
    },
  ];

  Future<void> _runAnalysis() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your symptom description or select a sample query.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _analysisResult = null;
      _voiceTranscript = null;
      _voiceDetectedLanguage = null;
      _savedSuccessfully = false;
      _consentGiven = false;
    });

    try {
      final res = await widget.apiService.analyzeSymptom(
        description: text,
        sessionId: widget.sessionId,
        language: _selectedLanguage,
      );

      if (mounted) {
        setState(() {
          _analysisResult = res;
          _editableSymptoms = List<String>.from(res.extracted.explicitSymptoms);
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Analysis error: $e\nPlease verify backend connectivity at ${widget.apiService.baseUrl}.';
        });
      }
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isRecording) {
      await _stopAndAnalyzeVoice();
      return;
    }
    try {
      await _voiceRecorder.start();
      if (!mounted) {
        _voiceRecorder.dispose();
        return;
      }
      setState(() {
        _errorMessage = null;
        _analysisResult = null;
        _voiceTranscript = null;
        _voiceDetectedLanguage = null;
        _consentGiven = false;
        _savedSuccessfully = false;
        _isRecording = true;
      });
      _recordingLimitTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && _isRecording) _stopAndAnalyzeVoice();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Microphone access is unavailable. Allow microphone permission or continue with typed input.');
      }
    }
  }

  Future<void> _stopAndAnalyzeVoice() async {
    _recordingLimitTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
      _errorMessage = null;
      _analysisResult = null;
      _consentGiven = false;
      _savedSuccessfully = false;
    });
    try {
      final recording = await _voiceRecorder.stop();
      final response = await widget.apiService.analyzeVoice(
        audioBytes: recording.bytes,
        filename: recording.filename,
        mimeType: recording.mimeType,
        sessionId: widget.sessionId,
        language: _selectedLanguage,
      );
      final transcript = response['transcript'] as String;
      final analysis = SymptomAnalysisResponse.fromJson(
        Map<String, dynamic>.from(response['analysis'] as Map),
      );
      if (mounted) {
        setState(() {
          _voiceTranscript = transcript;
          _voiceDetectedLanguage = response['detected_language'] as String?;
          _controller.value = TextEditingValue(
            text: transcript,
            selection: TextSelection.collapsed(offset: transcript.length),
          );
          _analysisResult = analysis;
          _editableSymptoms = List<String>.from(analysis.extracted.explicitSymptoms);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Voice analysis unavailable: $e You can still type your symptoms below.');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  String get _speechLanguageCode {
    const supported = {
      'en-IN', 'hi-IN', 'bn-IN', 'gu-IN', 'kn-IN', 'ml-IN',
      'mr-IN', 'od-IN', 'pa-IN', 'ta-IN', 'te-IN',
    };
    if (_selectedLanguage == 'auto') {
      return supported.contains(_voiceDetectedLanguage) ? _voiceDetectedLanguage! : 'en-IN';
    }
    if (_selectedLanguage == 'hi-Latn' || _selectedLanguage == 'hi') return 'hi-IN';
    if (_selectedLanguage == 'en') return 'en-IN';
    return _selectedLanguage;
  }

  Future<void> _speakResponse() async {
    final analysis = _analysisResult;
    if (analysis == null || analysis.safety.urgentCareRequired || _isSpeaking) return;
    setState(() => _isSpeaking = true);
    try {
      final fullText = '${analysis.careNavigation}\n${analysis.disclaimer}';
      final speechText = String.fromCharCodes(fullText.runes.take(2500));
      final response = await widget.apiService.synthesizeSpeech(
        text: speechText,
        languageCode: _speechLanguageCode,
      );
      await _voicePlayer.playBase64Wav(response['audio_base64'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Spoken response unavailable: $e'), backgroundColor: AppColors.warningOrange),
        );
      }
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _saveConfirmedSymptoms() async {
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check the consent box to authorize saving your clinical record.'),
          backgroundColor: AppColors.warningOrange,
        ),
      );
      return;
    }

    if (_analysisResult == null) return;

    setState(() => _isSavingConsent = true);

    try {
      final success = await widget.apiService.saveSymptomConsent(
        sessionId: widget.sessionId,
        originalDescription: _analysisResult!.extracted.originalDescription,
        confirmedSymptoms: _editableSymptoms,
        reportedCycleGapDays: _analysisResult!.extracted.reportedCycleGapDays,
        durationAndContext: _analysisResult!.extracted.durationAndContext,
        consentGiven: true,
      );

      if (mounted) {
        setState(() {
          _savedSuccessfully = success;
          _isSavingConsent = false;
        });
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Confirmed symptoms saved to your session records with verified consent.'),
              backgroundColor: AppColors.sageGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingConsent = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save record: $e'), backgroundColor: AppColors.emergencyRed),
        );
      }
    }
  }

  @override
  void dispose() {
    _recordingLimitTimer?.cancel();
    _voiceRecorder.dispose();
    _voicePlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Heading
          const Text(
            'Vernacular Symptom Companion',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.charcoal, letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          const Text(
            'Describe what you are noticing in your body using English, Hindi, or conversational Hinglish. Sakhi screens for acute red flags, extracts structured medical concepts, and connects you to clinical evidence without providing automated diagnoses or prescriptions.',
            style: TextStyle(fontSize: 13.5, color: AppColors.charcoalMuted, height: 1.5),
          ),

          const SizedBox(height: 20),

          // Input Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language & Voice Control Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.sageGreenLight, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.translate, size: 16, color: AppColors.forestGreen),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Language:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                      ),
                      const SizedBox(width: 10),
                      DropdownButtonHideUnderline(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.ivoryBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedLanguage,
                            borderRadius: BorderRadius.circular(10),
                            items: const [
                              DropdownMenuItem(value: 'auto', child: Text('Auto-Detect', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'hi-Latn', child: Text('Hinglish (Hindi in Latin script)', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'bn-IN', child: Text('Bengali', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'gu-IN', child: Text('Gujarati', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'kn-IN', child: Text('Kannada', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'ml-IN', child: Text('Malayalam', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'mr-IN', child: Text('Marathi', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'od-IN', child: Text('Odia', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'pa-IN', child: Text('Punjabi', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'ta-IN', child: Text('Tamil', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'te-IN', child: Text('Telugu', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'hi', child: Text('Hindi (हिन्दी)', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedLanguage = val);
                            },
                          ),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _isAnalyzing ? null : _toggleVoiceInput,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isRecording ? AppColors.emergencyRed : AppColors.forestGreen,
                          side: BorderSide(color: _isRecording ? AppColors.emergencyRed : AppColors.borderColor),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic_none, size: 16),
                        label: Text(
                          _isRecording ? 'Stop & analyze' : (_isAnalyzing ? 'Transcribing…' : 'Speak symptoms'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Preset Test Pills
                  const Text('Sample Clinical & Adversarial Tests:', style: TextStyle(fontSize: 11.5, color: AppColors.charcoalMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _samplePrompts.map((p) {
                      final isEmergency = p['label']!.contains('Emergency');
                      final isAdversarial = p['label']!.contains('Adversarial');

                      return ActionChip(
                        avatar: Icon(
                          isEmergency
                              ? Icons.emergency
                              : (isAdversarial ? Icons.shield_outlined : Icons.lightbulb_outline),
                          size: 14,
                          color: isEmergency
                              ? AppColors.emergencyRed
                              : (isAdversarial ? AppColors.warningOrange : AppColors.forestGreen),
                        ),
                        label: Text(
                          p['label']!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isEmergency
                                ? AppColors.emergencyRed
                                : (isAdversarial ? AppColors.warningOrange : AppColors.charcoal),
                          ),
                        ),
                        backgroundColor: isEmergency
                            ? AppColors.emergencyRedLight
                            : (isAdversarial ? AppColors.warningOrangeLight : AppColors.sageGreenLight),
                        side: BorderSide(
                          color: isEmergency
                              ? AppColors.emergencyRed.withValues(alpha: 0.3)
                              : (isAdversarial ? AppColors.warningOrange.withValues(alpha: 0.3) : AppColors.borderColor),
                        ),
                        onPressed: () {
                          _controller.text = p['text']!;
                          _runAnalysis();
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  if (_voiceTranscript != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lavenderLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.lavenderAccent.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        'Voice transcript${_voiceDetectedLanguage == null ? '' : ' · $_voiceDetectedLanguage'}: Review or edit below; analyze again after edits.',
                        style: const TextStyle(fontSize: 12, color: AppColors.charcoalMuted),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Text Area
                  TextField(
                    controller: _controller,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Apne symptoms batayein... For example: "Mera period pichle 2 mahine se late hai aur chin par baal badh rahe hain"',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isAnalyzing ? null : _runAnalysis,
                        icon: _isAnalyzing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.troubleshoot_outlined, size: 17),
                        label: Text(_isAnalyzing ? 'Analyzing Clinical Narrative...' : 'Analyze Symptoms'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _analysisResult = null;
                            _errorMessage = null;
                            _savedSuccessfully = false;
                          });
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyRedLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.emergencyRed, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.emergencyRed, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Analysis Output Card
          if (_analysisResult != null) ...[
            // 1. Emergency Red Flag Banner if urgent care required
            if (_analysisResult!.safety.urgentCareRequired)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRedLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.emergencyRed, width: 2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.emergency_rounded, color: AppColors.emergencyRed, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'URGENT CLINICAL ALERT — SEEK IMMEDIATE MEDICAL ATTENTION',
                            style: TextStyle(color: AppColors.emergencyRed, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _analysisResult!.safety.urgentGuidance ??
                                'Your description contains symptoms associated with acute gynecological emergencies (such as ovarian torsion, ectopic pregnancy, or severe hemorrhage). Please visit the nearest Emergency Room or call emergency services immediately.',
                            style: const TextStyle(color: AppColors.charcoal, fontSize: 13, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // 2. Structured Extraction Results
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Structured Clinical Extraction',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.lavenderLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.lavenderAccent.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            'Detected: ${_analysisResult!.extracted.detectedLanguage}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.lavenderAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    const Text('Symptoms Explicitly Reported:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.charcoalMuted)),
                    const SizedBox(height: 8),
                    if (_editableSymptoms.isEmpty)
                      const Text('None explicitly classified.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.charcoalLight))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _editableSymptoms.map((sym) {
                          return Chip(
                            label: Text(sym, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            backgroundColor: AppColors.sageGreenLight,
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () {
                              setState(() => _editableSymptoms.remove(sym));
                            },
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 14),

                    if (_analysisResult!.extracted.reportedCycleGapDays != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.ivoryBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timelapse, size: 16, color: AppColors.forestGreen),
                            const SizedBox(width: 8),
                            Text(
                              'Reported Cycle Interval: ${_analysisResult!.extracted.reportedCycleGapDays} days between cycles',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                            ),
                          ],
                        ),
                      ),

                    if (_analysisResult!.extracted.durationAndContext != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Context: ${_analysisResult!.extracted.durationAndContext}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.charcoalMuted),
                      ),
                    ],

                    // Clarification Questions & Uncertainties
                    if (_analysisResult!.extracted.clarificationQuestions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warningOrangeLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.help_outline, size: 16, color: AppColors.warningOrange),
                                SizedBox(width: 8),
                                Text(
                                  'Clinical Clarification Questions:',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.warningOrange),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._analysisResult!.extracted.clarificationQuestions.map(
                              (q) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• $q', style: const TextStyle(fontSize: 12.5, color: AppColors.charcoal, height: 1.3)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. Care Navigation & Evidence Guidelines
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppColors.sageGreenLight, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.shield_outlined, color: AppColors.forestGreen, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Care Navigation (Non-Diagnostic Guidance)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _analysisResult!.careNavigation,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.charcoal, height: 1.55),
                    ),
                    if (!_analysisResult!.safety.urgentCareRequired) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _isSpeaking ? null : _speakResponse,
                        icon: _isSpeaking
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.volume_up_outlined, size: 17),
                        label: Text(_isSpeaking ? 'Preparing spoken response…' : 'Speak response (${_speechLanguageCode})'),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Retrieved Guideline Sources
                    if (_analysisResult!.knowledgeReferences.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 14),
                      const Text(
                        'Retrieved Medical References (Rotterdam Consensus):',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                      ),
                      const SizedBox(height: 10),
                      ..._analysisResult!.knowledgeReferences.map((ref) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.ivoryBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ref.title,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Authority: ${ref.sourceOrg}',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.forestGreen, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ref.plainExplanation,
                                      style: const TextStyle(fontSize: 12, color: AppColors.charcoalMuted, height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => ApiService.openWebUrl(ref.sourceUrl),
                                icon: const Icon(Icons.open_in_new, size: 13),
                                label: const Text('View Source', style: TextStyle(fontSize: 11.5)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 4. Explicit Consent & Save Action
            Card(
              color: AppColors.sageGreenLight,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Confirm Observations & Save with Explicit Consent',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sakhi does not save medical data automatically. Check the consent box below to confirm you authorize persisting these structured observations to your anonymous session record.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.charcoalMuted, height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    CheckboxListTile(
                      value: _consentGiven,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I explicitly consent to record these confirmed observations in my private session history.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                      ),
                      onChanged: (val) {
                        setState(() => _consentGiven = val ?? false);
                      },
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: (_isSavingConsent || _savedSuccessfully) ? null : _saveConfirmedSymptoms,
                          icon: _isSavingConsent
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Icon(_savedSuccessfully ? Icons.verified : Icons.save_alt, size: 17),
                          label: Text(_savedSuccessfully ? 'Saved with Consent' : 'Save to My Clinical Records'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
