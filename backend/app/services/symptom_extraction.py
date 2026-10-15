import re
import uuid
import logging
from typing import Dict, Any, List, Optional
from app.models.schemas import (
    ExtractedSymptomInfo,
    SymptomAnalysisResponse,
    SafetyOutcome,
    KnowledgeReference
)
from app.services.gemini_service import gemini_service
from app.services.safety_engine import DeterministicSafetyEngine
from app.services.knowledge_service import KnowledgeRetrievalService
from app.config import settings

logger = logging.getLogger("sakhi.symptom_extraction")


class SymptomAnalysisUnavailable(Exception):
    pass

# Multilingual Vernacular dictionary for deterministic extraction & fallback
VERNACULAR_SYMPTOM_MAP = {
    "irregular_periods": [
        "irregular periods", "period late", "periods late", "mahina late", "irregual",
        "date miss", "missed period", "chadh ke", "aage piche", "delay", "cycle gap"
    ],
    "hirsutism_facial_hair": [
        "facial hair", "chin hair", "chin baal", "chehre par baal", "upper lip hair",
        "unwanted hair", "excessive body hair", "hirsutism"
    ],
    "acne_skin_issues": [
        "acne", "pimples", "cystic acne", "chehre par dane", "breakouts", "oily skin"
    ],
    "weight_changes": [
        "weight gain", "wazan badhna", "motaapa", "cannot lose weight", "belly fat", "pet badhna"
    ],
    "hair_loss": [
        "hair fall", "hair thinning", "baal jhadna", "scalp thinning", "hair loss"
    ],
    "fatigue_energy": [
        "tired", "fatigue", "thakan", "kamzori", "exhausted", "low energy"
    ],
    "pelvic_cramps": [
        "cramps", "pet me dard", "period pain", "dard", "pelvic discomfort"
    ],
    "acanthosis_nigricans": [
        "dark neck", "gardan kali", "dark patches", "velvety skin"
    ]
}


class SymptomExtractionPipeline:
    def __init__(self, db_manager):
        self.db_manager = db_manager
        self.knowledge_service = KnowledgeRetrievalService(db_manager)

    async def analyze_symptom(self, raw_description: str, session_id: str, language_pref: str = "auto") -> SymptomAnalysisResponse:
        request_id = str(uuid.uuid4())

        # Step 1: Urgent-symptom screening (Strict Pre-Check)
        urgent_outcome = DeterministicSafetyEngine.screen_urgent_symptoms(raw_description)
        if urgent_outcome:
            await DeterministicSafetyEngine.create_audit_log(
                self.db_manager,
                request_id=request_id,
                rule_triggered=urgent_outcome.triggered_rules[0],
                action_taken="urgent_care_advised",
                blocked_or_rewritten=True,
                final_safety_status="BLOCKED_URGENT",
                redacted_summary=f"Urgent symptom intercepted: {urgent_outcome.triggered_rules}"
            )
            return SymptomAnalysisResponse(
                session_id=session_id,
                extracted=ExtractedSymptomInfo(
                    original_description=raw_description,
                    detected_language="auto",
                    explicit_symptoms=["Acute Emergency Symptoms Reported"],
                    uncertainties=["Immediate physical hospital evaluation required"],
                    clarification_questions=[]
                ),
                safety=urgent_outcome,
                knowledge_references=[],
                care_navigation="Please proceed immediately to an Emergency Room (ER) or contact urgent medical services.",
                requires_consent_to_save=False
            )

        # Step 2: Screen Adversarial / Policy violations (Pre-Check)
        policy_outcome = DeterministicSafetyEngine.screen_adversarial_and_policy(raw_description)
        if policy_outcome and policy_outcome.action_taken in {"clarification_requested", "rewritten", "blocked"}:
            await DeterministicSafetyEngine.create_audit_log(
                self.db_manager,
                request_id=request_id,
                rule_triggered=policy_outcome.triggered_rules[0],
                action_taken=policy_outcome.action_taken,
                blocked_or_rewritten=policy_outcome.action_taken in {"rewritten", "blocked"},
                final_safety_status="CLARIFICATION_REQUIRED" if policy_outcome.action_taken == "clarification_requested" else "POLICY_INTERCEPTED",
                redacted_summary="Safety policy intercepted input before model processing."
            )
            return SymptomAnalysisResponse(
                session_id=session_id,
                extracted=ExtractedSymptomInfo(
                    original_description=raw_description,
                    detected_language="auto",
                    explicit_symptoms=[],
                    uncertainties=["Input was intercepted by a safety rule."],
                    clarification_questions=(
                        ["How long have you noticed these symptoms?", "What is your typical cycle length in days?"]
                        if policy_outcome.action_taken == "clarification_requested"
                        else []
                    ),
                ),
                safety=policy_outcome,
                knowledge_references=[],
                care_navigation=policy_outcome.user_message,
                requires_consent_to_save=False
            )

        # Step 3: Structured Extraction (Gemini with Deterministic Fallback)
        extracted_info = await self._extract_structured_info(raw_description, language_pref)

        # Step 4: Evidence Retrieval
        retrieved_refs = await self.knowledge_service.retrieve_relevant_knowledge(
            symptoms=extracted_info.explicit_symptoms,
            query_text=raw_description,
            limit=3
        )

        # Step 5: Construct Non-Diagnostic Care Navigation Narrative
        care_navigation = self._build_care_navigation(extracted_info, retrieved_refs, policy_outcome)

        # Step 6: Post-Check Response Validation & Interception
        sanitized_nav, post_safety = DeterministicSafetyEngine.validate_and_sanitize_response(care_navigation)

        # Step 7: Audit Event Log
        final_rule = "NONE"
        if policy_outcome and policy_outcome.triggered_rules:
            final_rule = policy_outcome.triggered_rules[0]
        elif post_safety.triggered_rules:
            final_rule = post_safety.triggered_rules[0]

        await DeterministicSafetyEngine.create_audit_log(
            self.db_manager,
            request_id=request_id,
            rule_triggered=final_rule,
            action_taken=post_safety.action_taken,
            blocked_or_rewritten=post_safety.action_taken != "none",
            final_safety_status="COMPLETED_SAFE",
            redacted_summary=f"Processed symptoms: {len(extracted_info.explicit_symptoms)} identified."
        )

        return SymptomAnalysisResponse(
            session_id=session_id,
            extracted=extracted_info,
            safety=post_safety if post_safety.triggered_rules else (policy_outcome or post_safety),
            knowledge_references=retrieved_refs,
            care_navigation=sanitized_nav,
            requires_consent_to_save=True
        )

    async def _extract_structured_info(self, raw_description: str, language_pref: str) -> ExtractedSymptomInfo:
        """Use Gemini in normal operation and deterministic extraction only in explicit demo mode."""
        if gemini_service.is_live:
            system_prompt = (
                "You are an expert clinical data extraction assistant for Sakhi. "
                "Extract structured facts from the user's vernacular health description. "
                "CRITICAL CLINICAL RULES: "
                "1. NEVER diagnose PCOS. "
                "2. NEVER recommend medications or dosages. "
                "3. Distinguish clearly between explicitly stated symptoms and uncertainties. "
                "Return valid JSON matching this schema: "
                "{"
                "  \"detected_language\": \"English|Hindi|Hinglish|Other\","
                "  \"explicit_symptoms\": [\"list of symptoms mentioned\"],"
                "  \"menstrual_timing\": \"timing string or null\","
                "  \"reported_cycle_gap_days\": integer or null,"
                "  \"duration_and_context\": \"duration details or null\","
                "  \"uncertainties\": [\"missing details\"],"
                "  \"clarification_questions\": [\"1-2 questions\"]"
                "}"
            )
            prompt = f"User Symptom Description: \"{raw_description}\"\nLanguage Preference: {language_pref}"
            model_data = await gemini_service.generate_json(prompt, system_instruction=system_prompt)
            if model_data is not None:
                try:
                    return ExtractedSymptomInfo(
                        original_description=raw_description,
                        detected_language=model_data.get("detected_language", "auto"),
                        explicit_symptoms=model_data.get("explicit_symptoms", []),
                        menstrual_timing=model_data.get("menstrual_timing"),
                        reported_cycle_gap_days=model_data.get("reported_cycle_gap_days"),
                        duration_and_context=model_data.get("duration_and_context"),
                        uncertainties=model_data.get("uncertainties", []),
                        clarification_questions=model_data.get("clarification_questions", []),
                    )
                except Exception as e:
                    logger.warning("Gemini extraction output failed schema validation (%s).", type(e).__name__)

        if settings.DEMO_MODE:
            return self._deterministic_extract(raw_description)
        raise SymptomAnalysisUnavailable("Live symptom analysis is unavailable; deterministic analysis is disabled outside demo mode.")

    def _deterministic_extract(self, text: str) -> ExtractedSymptomInfo:
        lower = text.lower()

        # Language detection
        hindi_markers = ["hai", "mera", "meri", "dard", "mahina", "baal", "chehre", "pichle", "wazan", "hoti"]
        detected_lang = "English"
        if any(marker in lower.split() for marker in hindi_markers):
            detected_lang = "Hinglish / Hindi"

        # Symptom matching
        found_symptoms = []
        for sym_category, keywords in VERNACULAR_SYMPTOM_MAP.items():
            if any(kw in lower for kw in keywords):
                clean_name = sym_category.replace("_", " ").title()
                if clean_name not in found_symptoms:
                    found_symptoms.append(clean_name)

        # Flexible pattern detection for separated words (e.g., 'period 45 days se late')
        has_period_word = any(w in lower for w in ["period", "periods", "mahina", "cycle", "menstrual"])
        has_delay_word = any(w in lower for w in ["late", "delay", "irregular", "miss", "chadh", "gap", "aage piche"])
        if has_period_word and has_delay_word:
            if "Irregular Periods" not in found_symptoms:
                found_symptoms.append("Irregular Periods")

        if any(w in lower for w in ["baal", "hair"]) and any(w in lower for w in ["chin", "chehre", "face", "facial", "lip"]):
            if "Hirsutism Facial Hair" not in found_symptoms:
                found_symptoms.append("Hirsutism Facial Hair")

        # Menstrual timing & cycle gap parsing (e.g., '45 days', '2 months', '60 din')
        timing_match = re.search(r"(\d+)\s*(days?|din|mahine|months?|weeks?)", lower)
        timing_str = None
        gap_days = None
        if timing_match:
            qty = int(timing_match.group(1))
            unit = timing_match.group(2)
            timing_str = f"{qty} {unit}"
            if "month" in unit or "mahine" in unit:
                gap_days = qty * 30
            elif "week" in unit:
                gap_days = qty * 7
            else:
                gap_days = qty

        # Uncertainties and clarifying questions
        uncertainties = []
        questions = []
        if "Irregular Periods" in found_symptoms and not gap_days:
            uncertainties.append("Exact number of days between periods was not specified.")
            questions.append("When was the first day of your last period, and how many days usually pass between cycles?")
        if not found_symptoms:
            found_symptoms.append("General Health Query")
            questions.append("Could you specify any changes in your skin, energy, or monthly cycle?")

        return ExtractedSymptomInfo(
            original_description=text,
            detected_language=detected_lang,
            explicit_symptoms=found_symptoms,
            menstrual_timing=timing_str,
            reported_cycle_gap_days=gap_days,
            duration_and_context=timing_str or "Reported during symptom analysis",
            uncertainties=uncertainties,
            clarification_questions=questions,
        )

    def _build_care_navigation(
        self,
        extracted: ExtractedSymptomInfo,
        refs: List[KnowledgeReference],
        policy_outcome: Optional[SafetyOutcome]
    ) -> str:
        lines = []

        if policy_outcome and policy_outcome.action_taken == "rewritten":
            lines.append(f"**Safety Notice:** {policy_outcome.user_message}\n")

        symptom_list = ", ".join(extracted.explicit_symptoms) if extracted.explicit_symptoms else "the symptoms you mentioned"
        lines.append(
            f"Based on your description, we identified observations regarding **{symptom_list}**."
        )

        if extracted.reported_cycle_gap_days:
            lines.append(
                f"You reported an interval of approximately **{extracted.reported_cycle_gap_days} days** between menstrual cycles."
            )

        lines.append(
            "\n**What this means clinically:**"
            "\nThese physical signs can occur for various interconnected hormonal reasons, including stress, thyroid function, "
            "metabolic variations, or conditions like PCOS. Under international clinical guidelines (such as the Rotterdam Criteria), "
            "PCOS cannot be diagnosed by symptoms alone; it requires objective laboratory hormone evaluation and pelvic ultrasound by a physician."
        )

        if refs:
            lines.append("\n**Retrieved Evidence References:**")
            for ref in refs:
                demo_tag = " *(Demo Reference - Needs Clinical Review)*" if ref.is_demo else ""
                lines.append(f"- **{ref.title}** ({ref.source_org}){demo_tag}: {ref.plain_explanation}")

        lines.append(
            "\n**Suggested Next Steps for Care:**"
            "\n1. Consider logging your cycle dates over 3–6 months to establish your individual baseline."
            "\n2. Schedule a clinical consultation with a gynecologist or physician."
            "\n3. Discuss whether hormone panel tests (such as TSH, Prolactin, Free Androgens) or ultrasound imaging are appropriate."
        )

        return "\n".join(lines)
