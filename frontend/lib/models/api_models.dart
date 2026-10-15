class KnowledgeReference {
  final String id;
  final String title;
  final String topic;
  final String concept;
  final String plainExplanation;
  final List<String> vernacularTerms;
  final String sourceOrg;
  final String sourceUrl;
  final String evidenceExcerpt;
  final String reviewStatus;
  final bool isDemo;

  KnowledgeReference({
    required this.id,
    required this.title,
    required this.topic,
    required this.concept,
    required this.plainExplanation,
    required this.vernacularTerms,
    required this.sourceOrg,
    required this.sourceUrl,
    required this.evidenceExcerpt,
    required this.reviewStatus,
    this.isDemo = false,
  });

  factory KnowledgeReference.fromJson(Map<String, dynamic> json) {
    return KnowledgeReference(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      topic: json['topic'] ?? '',
      concept: json['concept'] ?? '',
      plainExplanation: json['plain_explanation'] ?? '',
      vernacularTerms: (json['vernacular_terms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      sourceOrg: json['source_org'] ?? '',
      sourceUrl: json['source_url'] ?? '',
      evidenceExcerpt: json['evidence_excerpt'] ?? '',
      reviewStatus: json['review_status'] ?? 'reviewed',
      isDemo: json['is_demo'] ?? false,
    );
  }
}

class ExtractedSymptomInfo {
  final String originalDescription;
  final String detectedLanguage;
  final List<String> explicitSymptoms;
  final String? menstrualTiming;
  final int? reportedCycleGapDays;
  final String? durationAndContext;
  final List<String> uncertainties;
  final List<String> clarificationQuestions;

  ExtractedSymptomInfo({
    required this.originalDescription,
    required this.detectedLanguage,
    required this.explicitSymptoms,
    this.menstrualTiming,
    this.reportedCycleGapDays,
    this.durationAndContext,
    required this.uncertainties,
    required this.clarificationQuestions,
  });

  factory ExtractedSymptomInfo.fromJson(Map<String, dynamic> json) {
    return ExtractedSymptomInfo(
      originalDescription: json['original_description'] ?? '',
      detectedLanguage: json['detected_language'] ?? 'auto',
      explicitSymptoms: (json['explicit_symptoms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      menstrualTiming: json['menstrual_timing'],
      reportedCycleGapDays: json['reported_cycle_gap_days'],
      durationAndContext: json['duration_and_context'],
      uncertainties: (json['uncertainties'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      clarificationQuestions: (json['clarification_questions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class SafetyOutcome {
  final bool passed;
  final List<String> triggeredRules;
  final String actionTaken;
  final bool urgentCareRequired;
  final String? urgentGuidance;
  final String userMessage;
  final bool isDiagnosticClaimPrevented;

  SafetyOutcome({
    required this.passed,
    required this.triggeredRules,
    required this.actionTaken,
    required this.urgentCareRequired,
    this.urgentGuidance,
    required this.userMessage,
    required this.isDiagnosticClaimPrevented,
  });

  factory SafetyOutcome.fromJson(Map<String, dynamic> json) {
    return SafetyOutcome(
      passed: json['passed'] ?? true,
      triggeredRules: (json['triggered_rules'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      actionTaken: json['action_taken'] ?? 'none',
      urgentCareRequired: json['urgent_care_required'] ?? false,
      urgentGuidance: json['urgent_guidance'],
      userMessage: json['user_message'] ?? '',
      isDiagnosticClaimPrevented: json['is_diagnostic_claim_prevented'] ?? false,
    );
  }
}

class SymptomAnalysisResponse {
  final String sessionId;
  final ExtractedSymptomInfo extracted;
  final SafetyOutcome safety;
  final List<KnowledgeReference> knowledgeReferences;
  final String careNavigation;
  final String disclaimer;
  final bool requiresConsentToSave;

  SymptomAnalysisResponse({
    required this.sessionId,
    required this.extracted,
    required this.safety,
    required this.knowledgeReferences,
    required this.careNavigation,
    required this.disclaimer,
    required this.requiresConsentToSave,
  });

  factory SymptomAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return SymptomAnalysisResponse(
      sessionId: json['session_id'] ?? '',
      extracted: ExtractedSymptomInfo.fromJson(json['extracted'] ?? {}),
      safety: SafetyOutcome.fromJson(json['safety'] ?? {}),
      knowledgeReferences: (json['knowledge_references'] as List<dynamic>?)
              ?.map((e) => KnowledgeReference.fromJson(e))
              .toList() ??
          [],
      careNavigation: json['care_navigation'] ?? '',
      disclaimer: json['disclaimer'] ?? '',
      requiresConsentToSave: json['requires_consent_to_save'] ?? true,
    );
  }
}

class CycleHistoryItem {
  final String periodStartDate;
  final int? cycleGapDays;
  final String flowIntensity;
  final bool isDemo;

  CycleHistoryItem({
    required this.periodStartDate,
    this.cycleGapDays,
    required this.flowIntensity,
    this.isDemo = false,
  });

  factory CycleHistoryItem.fromJson(Map<String, dynamic> json) {
    return CycleHistoryItem(
      periodStartDate: json['period_start_date'] ?? '',
      cycleGapDays: json['cycle_gap_days'],
      flowIntensity: json['flow_intensity'] ?? 'medium',
      isDemo: json['is_demo'] ?? false,
    );
  }
}

class CycleAnalyticsResult {
  final String sessionId;
  final int totalRecordedCycles;
  final int observationWindowMonths;
  final double? averageGapDays;
  final int? minGapDays;
  final int? maxGapDays;
  final double? variationSd;
  final bool irregularityFlag;
  final List<String> missingDataIntervals;
  final List<CycleHistoryItem> history;
  final String clinicalNote;
  final bool isDiagnostic;

  CycleAnalyticsResult({
    required this.sessionId,
    required this.totalRecordedCycles,
    required this.observationWindowMonths,
    this.averageGapDays,
    this.minGapDays,
    this.maxGapDays,
    this.variationSd,
    required this.irregularityFlag,
    required this.missingDataIntervals,
    required this.history,
    required this.clinicalNote,
    this.isDiagnostic = false,
  });

  factory CycleAnalyticsResult.fromJson(Map<String, dynamic> json) {
    return CycleAnalyticsResult(
      sessionId: json['session_id'] ?? '',
      totalRecordedCycles: json['total_recorded_cycles'] ?? 0,
      observationWindowMonths: json['observation_window_months'] ?? 6,
      averageGapDays: json['average_gap_days'] != null ? (json['average_gap_days'] as num).toDouble() : null,
      minGapDays: json['min_gap_days'],
      maxGapDays: json['max_gap_days'],
      variationSd: json['variation_sd'] != null ? (json['variation_sd'] as num).toDouble() : null,
      irregularityFlag: json['irregularity_flag'] ?? false,
      missingDataIntervals: (json['missing_data_intervals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      history: (json['history'] as List<dynamic>?)?.map((e) => CycleHistoryItem.fromJson(e)).toList() ?? [],
      clinicalNote: json['clinical_note'] ?? '',
      isDiagnostic: json['is_diagnostic'] ?? false,
    );
  }
}

