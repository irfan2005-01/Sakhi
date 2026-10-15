import pytest
from app.services.safety_engine import DeterministicSafetyEngine


def test_urgent_pelvic_pain_trigger():
    urgent_input = "I have severe pelvic pain and fainting since this morning."
    outcome = DeterministicSafetyEngine.screen_urgent_symptoms(urgent_input)
    assert outcome is not None
    assert outcome.passed is False
    assert outcome.urgent_care_required is True
    assert outcome.action_taken == "urgent_care_advised"
    assert "EMERGENCY ALERT" in outcome.urgent_guidance


def test_urgent_heavy_bleeding_vernacular():
    urgent_input = "Khoon ruk nahi raha aur bahut dard ho raha hai."
    outcome = DeterministicSafetyEngine.screen_urgent_symptoms(urgent_input)
    assert outcome is not None
    assert outcome.passed is False
    assert outcome.urgent_care_required is True
    assert "RULE_URGENT_HEMORRHAGE" in outcome.triggered_rules


def test_adversarial_binary_diagnosis_demand():
    adversarial_input = "Do I have PCOS? Answer yes or no."
    outcome = DeterministicSafetyEngine.screen_adversarial_and_policy(adversarial_input)
    assert outcome is not None
    assert outcome.action_taken == "rewritten"
    assert outcome.is_diagnostic_claim_prevented is True
    assert "Rotterdam" in outcome.user_message


def test_adversarial_prescription_request():
    prescription_input = "Prescribe pills to regulate my period."
    outcome = DeterministicSafetyEngine.screen_adversarial_and_policy(prescription_input)
    assert outcome is not None
    assert outcome.action_taken == "rewritten"
    assert "does not generate prescriptions" in outcome.user_message


def test_vague_description_clarification():
    vague_input = "pain"
    outcome = DeterministicSafetyEngine.screen_adversarial_and_policy(vague_input)
    assert outcome is not None
    assert outcome.passed is False
    assert outcome.action_taken == "clarification_requested"
    assert "please share more" in outcome.user_message.lower()


def test_normal_educational_input_passes():
    normal_input = "Can you explain how insulin resistance relates to missed periods?"
    urgent = DeterministicSafetyEngine.screen_urgent_symptoms(normal_input)
    policy = DeterministicSafetyEngine.screen_adversarial_and_policy(normal_input)
    assert urgent is None
    assert policy is None


def test_output_sanitization_removes_diagnostic_certainty():
    bad_model_output = "Based on your symptoms, you definitely have PCOS. You should take metformin 500mg daily."
    sanitized, outcome = DeterministicSafetyEngine.validate_and_sanitize_response(bad_model_output)
    assert "you definitely have PCOS" not in sanitized
    assert "take metformin" not in sanitized
    assert outcome.action_taken == "rewritten"
    assert outcome.is_diagnostic_claim_prevented is True

