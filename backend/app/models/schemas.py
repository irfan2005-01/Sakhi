from datetime import datetime
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Clinical Knowledge Base Models
# ---------------------------------------------------------------------------
class KnowledgeReference(BaseModel):
    id: str = Field(..., description="Unique slug or id of the knowledge entry")
    title: str = Field(..., description="Educational topic title")
    topic: str = Field(..., description="Broader clinical category e.g., 'ovulation', 'androgens'")
    concept: str = Field(..., description="Medical concept explained")
    plain_explanation: str = Field(..., description="Clear patient-friendly explanation")
    vernacular_terms: List[str] = Field(default_factory=list, description="Common vernacular/Hinglish terms")
    source_org: str = Field(..., description="Authentic medical source e.g., ACOG, NIH, Monash")
    source_url: str = Field(..., description="Official verifiable medical URL")
    evidence_excerpt: str = Field(..., description="Direct clinical excerpt or guideline summary")
    review_status: str = Field("reviewed", description="'reviewed' or 'needs_clinical_review'")
    is_demo: bool = Field(False, description="Explicit demo tag")


# ---------------------------------------------------------------------------
# Symptom Extraction & Analysis Models
# ---------------------------------------------------------------------------
class SymptomInput(BaseModel):
    description: str = Field(..., min_length=2, description="Patient description in any vernacular/English")
    language: Optional[str] = Field("auto", description="User selected language code or auto")
    session_id: str = Field(..., description="Anonymous patient session ID")


class ExtractedSymptomInfo(BaseModel):
    original_description: str
    detected_language: str
    explicit_symptoms: List[str] = Field(default_factory=list, description="Symptoms explicitly stated by user")
    menstrual_timing: Optional[str] = Field(None, description="Timing details e.g., 'delayed by 2 months'")
    reported_cycle_gap_days: Optional[int] = Field(None, description="Reported or inferred gap between cycles in days")
    duration_and_context: Optional[str] = Field(None, description="Duration, lifestyle context, or triggers")
    uncertainties: List[str] = Field(default_factory=list, description="Ambiguous or missing clinical points")
    clarification_questions: List[str] = Field(default_factory=list, description="Questions to clarify condition")


class SafetyOutcome(BaseModel):
    passed: bool = True
    triggered_rules: List[str] = Field(default_factory=list)
    action_taken: str = "none"  # "none", "rewritten", "blocked", "urgent_care_advised"
    urgent_care_required: bool = False
    urgent_guidance: Optional[str] = None
    user_message: str = ""
    is_diagnostic_claim_prevented: bool = False


class SymptomAnalysisResponse(BaseModel):
    session_id: str
    extracted: ExtractedSymptomInfo
    safety: SafetyOutcome
    knowledge_references: List[KnowledgeReference] = Field(default_factory=list)
    care_navigation: str = Field(..., description="Non-diagnostic guidance on next clinical steps")
    disclaimer: str = Field(
        "Sakhi is a non-diagnostic clinical companion. It does not provide medical diagnoses or prescriptions. "
        "Consult a qualified healthcare provider for clinical evaluation.",
        description="Standard medical disclaimer"
    )
    requires_consent_to_save: bool = True


class VoiceAnalysisResponse(BaseModel):
    transcript: str
    detected_language: Optional[str] = None
    analysis: SymptomAnalysisResponse


class VoiceSynthesisRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2500)
    language_code: str


class VoiceSynthesisResponse(BaseModel):
    audio_base64: str
    content_type: str = "audio/wav"
    language_code: str
    model: str


# ---------------------------------------------------------------------------
# Patient Log & Consent Models
# ---------------------------------------------------------------------------
class SymptomConfirmationRequest(BaseModel):
    session_id: str
    original_description: str
    confirmed_symptoms: List[str]
    reported_cycle_gap_days: Optional[int] = None
    duration_and_context: Optional[str] = None
    consent_given: bool = Field(..., description="Must explicitly be True to store user data")
    notes: Optional[str] = None


class PatientSymptomLog(BaseModel):
    session_id: str
    timestamp: str
    original_description: str
    input_language: str
    confirmed_symptoms: List[str]
    reported_cycle_gap_days: Optional[int] = None
    knowledge_references: List[str] = Field(default_factory=list)
    safety_outcome: Dict[str, Any] = Field(default_factory=dict)
    consent_status: bool = True
    is_demo: bool = False


# ---------------------------------------------------------------------------
# Menstrual Cycle Analytics Models
# ---------------------------------------------------------------------------
class CycleEntryCreate(BaseModel):
    session_id: str
    period_start_date: str = Field(..., description="YYYY-MM-DD format")
    flow_intensity: Optional[str] = Field("medium", description="light, medium, heavy")
    notes: Optional[str] = None


class CycleRecord(BaseModel):
    id: Optional[str] = None
    session_id: str
    period_start_date: str
    cycle_gap_days: Optional[int] = None
    flow_intensity: Optional[str] = None
    is_demo: bool = False
    created_at: str


class CycleAnalyticsResult(BaseModel):
    session_id: str
    total_recorded_cycles: int
    observation_window_months: int = 6
    average_gap_days: Optional[float] = None
    min_gap_days: Optional[int] = None
    max_gap_days: Optional[int] = None
    variation_sd: Optional[float] = None
    irregularity_flag: bool = False
    missing_data_intervals: List[str] = Field(default_factory=list)
    history: List[Dict[str, Any]] = Field(default_factory=list)
    clinical_note: str
    is_diagnostic: bool = False  # NEVER True: irregularity is not a standalone diagnosis


# ---------------------------------------------------------------------------
# Safety Audit Log Model
# ---------------------------------------------------------------------------
class SafetyAuditLog(BaseModel):
    request_id: str
    timestamp: str
    rule_triggered: str
    action_taken: str
    blocked_or_rewritten: bool
    final_safety_status: str
    redacted_summary: str

