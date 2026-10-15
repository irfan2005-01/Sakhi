import re
import uuid
from datetime import datetime, timezone
from typing import Tuple, Optional, List, Dict, Any
from app.models.schemas import SafetyOutcome, SafetyAuditLog
import logging

logger = logging.getLogger("sakhi.safety_engine")

# ---------------------------------------------------------------------------
# Red Flag & Urgent Symptom Patterns (Multilingual / Vernacular)
# ---------------------------------------------------------------------------
URGENT_PATTERNS = [
    # Acute severe pain
    (r"(severe|extreme|excruciating|unbearable|intense)\s+(pelvic|lower\s+abdominal|stomach|tummy)\s+pain", "RULE_URGENT_SEVERE_PELVIC_PAIN"),
    (r"(severe|bahut\s+jyada|bhayanak)\s+(pet|abdomen)\s+dard", "RULE_URGENT_SEVERE_PELVIC_PAIN"),
    # Heavy hemorrhaging
    (r"(soaking|soaked)\s+(through\s+)?(two|2|\d+)\s+pads?\s+(an|per)\s+hour", "RULE_URGENT_HEMORRHAGE"),
    (r"khoon\s+ruk\s+nahi\s+raha", "RULE_URGENT_HEMORRHAGE"),
    (r"heavy\s+clots?\s+with\s+dizziness", "RULE_URGENT_HEMORRHAGE"),
    # Syncope / shock / collapse
    (r"(fainting|passed\s+out|lost\s+consciousness|collapse)", "RULE_URGENT_SYNCOPE"),
    (r"(behosh|chakkkar\s+aakar\s+gir\s+gayi)", "RULE_URGENT_SYNCOPE"),
]

# ---------------------------------------------------------------------------
# Adversarial & Safety Violation Patterns
# ---------------------------------------------------------------------------
PRESCRIPTION_PATTERNS = [
    (r"\b(prescribe|give\s+me\s+a\s+prescription|suggest\s+medicines?|which\s+pill|tablet\s+batao|dawai\s+likho|dawa\s+batao)\b", "RULE_PROHIBIT_PRESCRIPTION_REQUEST"),
    (r"\b(metformin|clomid|letrozole|spironolactone|birth\s+control|progesterone)\s+(dosage|dose|mg|tablet)\b", "RULE_PROHIBIT_MEDICATION_DOSING"),
]

DIAGNOSTIC_CERTAINTY_PATTERNS = [
    (r"(answer\s+yes\s+or\s+no|yes\s+or\s+no|guarantee|definitely\s+have|confirm\s+i\s+have)\s+pcos", "RULE_PROHIBIT_BINARY_DIAGNOSTIC_DEMAND"),
    (r"do\s+i\s+have\s+pcos\??\s*answer\s+yes\s+or\s+no", "RULE_PROHIBIT_BINARY_DIAGNOSTIC_DEMAND"),
]

MODEL_OUTPUT_DIAGNOSTIC_VIOLATIONS = [
    (r"you\s+(definitely|certainly|surely)\s+have\s+pcos", "RULE_OUTPUT_NO_DIAGNOSTIC_CERTAINTY"),
    (r"you\s+have\s+polycystic\s+ovary\s+syndrome", "RULE_OUTPUT_NO_DEFINITIVE_DIAGNOSIS"),
    (r"this\s+(confirms|proves)\s+(that\s+)?you\s+have\s+pcos", "RULE_OUTPUT_NO_DIAGNOSTIC_PROOF"),
    (r"a\s+single\s+symptom\s+establishes\s+insulin\s+resistance", "RULE_OUTPUT_NO_SINGLE_SYMPTOM_DIAGNOSIS"),
    (r"(take|start|prescribed?)\s+(metformin|clomiphene|letrozole|oral\s+contraceptives|birth\s+control)", "RULE_OUTPUT_NO_PRESCRIPTION_DIRECTIVE"),
]


class DeterministicSafetyEngine:
    """
    Deterministic clinical safety screening running strictly before and after AI calls.
    Processing sequence:
    User input -> Urgent screening -> Structured extraction -> Evidence retrieval -> Response validation -> Safety interception -> Response -> Audit log
    """

    @staticmethod
    def screen_urgent_symptoms(text: str) -> Optional[SafetyOutcome]:
        """Check for acute emergencies: ectopic pregnancy, ovarian torsion, hemorrhage."""
        lower_text = text.lower()
        for pattern, rule_code in URGENT_PATTERNS:
            if re.search(pattern, lower_text):
                return SafetyOutcome(
                    passed=False,
                    triggered_rules=[rule_code],
                    action_taken="urgent_care_advised",
                    urgent_care_required=True,
                    urgent_guidance=(
                        "EMERGENCY ALERT: Your description includes acute symptoms (such as severe sudden pelvic pain, "
                        "signs of excessive bleeding soaking multiple pads per hour, or syncope/fainting) that require "
                        "IMMEDIATE emergency clinical evaluation. Please visit the nearest Emergency Room (ER) or contact "
                        "local emergency medical services immediately. Sakhi cannot evaluate acute gynecological emergencies."
                    ),
                    user_message="Urgent medical symptoms detected. Immediate professional emergency care is advised.",
                    is_diagnostic_claim_prevented=True,
                )
        return None

    @staticmethod
    def screen_adversarial_and_policy(text: str) -> Optional[SafetyOutcome]:
        """Intercept direct prescription requests or forced binary diagnostic demands."""
        lower_text = text.lower().strip()

        # Vague or insufficient input check
        if len(lower_text) < 5 or (len(lower_text.split()) < 2 and lower_text in ["pain", "help", "periods", "pcos"]):
            return SafetyOutcome(
                passed=False,
                triggered_rules=["RULE_INSUFFICIENT_INPUT_CLARIFICATION_REQUIRED"],
                action_taken="clarification_requested",
                urgent_care_required=False,
                user_message=(
                    "Your input has very few details. To help provide relevant educational information, please share more about: "
                    "1) How many days or weeks has this been occurring? "
                    "2) What specific changes in your menstrual cycles, skin, or energy have you noticed? "
                    "3) Any past clinical tests you have undertaken?"
                ),
                is_diagnostic_claim_prevented=True,
            )

        # Binary diagnosis demand
        for pattern, rule_code in DIAGNOSTIC_CERTAINTY_PATTERNS:
            if re.search(pattern, lower_text):
                return SafetyOutcome(
                    passed=True,  # Handled safely by intercepting
                    triggered_rules=[rule_code],
                    action_taken="rewritten",
                    urgent_care_required=False,
                    user_message=(
                        "A clinical diagnosis of PCOS cannot be answered with a simple 'yes' or 'no'. "
                        "Medical standards (the international Rotterdam Consensus) require formal clinical assessment, "
                        "laboratory hormone testing, and pelvic imaging to assess ovulatory function and rule out other causes like thyroid dysfunction."
                    ),
                    is_diagnostic_claim_prevented=True,
                )

        # Direct prescription request
        for pattern, rule_code in PRESCRIPTION_PATTERNS:
            if re.search(pattern, lower_text):
                return SafetyOutcome(
                    passed=True,
                    triggered_rules=[rule_code],
                    action_taken="rewritten",
                    urgent_care_required=False,
                    user_message=(
                        "Sakhi does not generate prescriptions or recommend medication dosages. "
                        "Medications such as hormonal cycle regulators, insulin sensitizers, or anti-androgens must only be prescribed "
                        "by a licensed gynecologist or endocrinologist after comprehensive blood work and clinical examination."
                    ),
                    is_diagnostic_claim_prevented=True,
                )

        return None

    @staticmethod
    def validate_and_sanitize_response(text: str) -> Tuple[str, SafetyOutcome]:
        """
        Validate model-generated response against strict non-diagnostic and no-prescription invariants.
        If a forbidden assertion is detected, rewrite and flag in audit.
        """
        sanitized = text
        triggered_rules = []
        action = "none"

        for pattern, rule_code in MODEL_OUTPUT_DIAGNOSTIC_VIOLATIONS:
            if re.search(pattern, sanitized, re.IGNORECASE):
                triggered_rules.append(rule_code)
                action = "rewritten"
                # Deterministically replace diagnostic assertion with clinical phrasing
                if "pcos" in pattern:
                    sanitized = re.sub(
                        pattern,
                        "these symptoms may be consistent with patterns observed in ovulatory or metabolic variations, which warrant clinical evaluation",
                        sanitized,
                        flags=re.IGNORECASE
                    )
                elif "insulin" in pattern:
                    sanitized = re.sub(
                        pattern,
                        "metabolic evaluation by a physician is required to evaluate insulin sensitivity",
                        sanitized,
                        flags=re.IGNORECASE
                    )
                elif "metformin" in pattern or "prescribe" in pattern:
                    sanitized = re.sub(
                        pattern,
                        "[Medication directive removed: Consult your physician for personalized medical prescriptions]",
                        sanitized,
                        flags=re.IGNORECASE
                    )

        outcome = SafetyOutcome(
            passed=True,
            triggered_rules=triggered_rules,
            action_taken=action if triggered_rules else "none",
            urgent_care_required=False,
            user_message=sanitized,
            is_diagnostic_claim_prevented=len(triggered_rules) > 0,
        )
        return sanitized, outcome

    @classmethod
    async def create_audit_log(
        cls,
        db_manager,
        request_id: str,
        rule_triggered: str,
        action_taken: str,
        blocked_or_rewritten: bool,
        final_safety_status: str,
        redacted_summary: str
    ):
        """Append-only audit service. Never provides delete/edit functionality."""
        audit_entry = SafetyAuditLog(
            request_id=request_id,
            timestamp=datetime.now(timezone.utc).isoformat(),
            rule_triggered=rule_triggered,
            action_taken=action_taken,
            blocked_or_rewritten=blocked_or_rewritten,
            final_safety_status=final_safety_status,
            redacted_summary=redacted_summary,
        )
        try:
            col = db_manager.safety_audit_collection
            await col.insert_one(audit_entry.model_dump())
        except Exception as e:
            logger.error("Failed to write safety audit log: %s", str(e))
        return audit_entry

