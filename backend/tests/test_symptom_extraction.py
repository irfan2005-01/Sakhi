import pytest
from app.services.symptom_extraction import SymptomExtractionPipeline
from app.database import InMemoryAsyncCollection
from app.config import settings
from app.services.gemini_service import gemini_service


class MockDbManager:
    def __init__(self):
        self.knowledge_collection = InMemoryAsyncCollection("clinical_knowledge_base")
        self.safety_audit_collection = InMemoryAsyncCollection("safety_audit_logs")
        self.symptom_logs_collection = InMemoryAsyncCollection("patient_symptom_logs")
        self.cycles_collection = InMemoryAsyncCollection("menstrual_cycles")


@pytest.mark.asyncio
async def test_hinglish_symptom_extraction(monkeypatch):
    monkeypatch.setattr(settings, "DEMO_MODE", True)
    db = MockDbManager()
    pipeline = SymptomExtractionPipeline(db)
    user_input = "Mera period 45 days se late hai aur chehre par baal aa rahe hain."
    
    response = await pipeline.analyze_symptom(
        raw_description=user_input,
        session_id="test-hinglish-01"
    )

    assert response.session_id == "test-hinglish-01"
    assert "Hinglish" in response.extracted.detected_language or "Hindi" in response.extracted.detected_language
    # Symptoms identified
    assert any("Irregular" in s for s in response.extracted.explicit_symptoms)
    assert any("Facial Hair" in s or "Hirsutism" in s for s in response.extracted.explicit_symptoms)
    assert response.extracted.reported_cycle_gap_days == 45
    # Strict Invariant: No diagnosis
    assert "definitely have PCOS" not in response.care_navigation
    assert response.safety.is_diagnostic_claim_prevented is True or response.safety.passed is True
    # Audit event was saved
    audit_count = await db.safety_audit_collection.count_documents({})
    assert audit_count >= 1


@pytest.mark.asyncio
async def test_adversarial_request_is_intercepted_before_gemini(monkeypatch):
    monkeypatch.setattr(settings, "DEMO_MODE", False)
    monkeypatch.setattr(gemini_service, "client", object())

    async def should_not_call_model(*args, **kwargs):
        raise AssertionError("Gemini must not receive an intercepted diagnostic request")

    monkeypatch.setattr(gemini_service, "generate_json", should_not_call_model)
    db = MockDbManager()
    response = await SymptomExtractionPipeline(db).analyze_symptom(
        raw_description="Do I have PCOS? Answer yes or no.",
        session_id="test-adversarial"
    )
    assert response.safety.action_taken == "rewritten"
    assert response.requires_consent_to_save is False
    assert "yes" in response.care_navigation.lower()

