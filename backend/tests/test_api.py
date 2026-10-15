import pytest
from httpx import AsyncClient, ASGITransport
from app.database import db_manager
from app.main import app
from app.config import settings
from app.services.gemini_service import gemini_service


@pytest.mark.asyncio
async def test_health_endpoint(monkeypatch):
    monkeypatch.setattr(db_manager, "is_connected", False)
    monkeypatch.setattr(db_manager, "use_fallback", False)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "degraded"
    assert data["database"]["status"] == "disconnected"
    assert data["database"]["persistence_available"] is False
    assert "clinical_safety_engine" in data


@pytest.mark.asyncio
async def test_knowledge_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/knowledge")
    assert response.status_code == 200
    items = response.json()
    assert len(items) > 0
    # Must have authentic verifiable medical sources
    assert any("ACOG" in i["source_org"] or "Monash" in i["source_org"] or "NIH" in i["source_org"] for i in items)


@pytest.mark.asyncio
async def test_symptom_analyze_and_consent_saving(monkeypatch):
    monkeypatch.setattr(settings, "DEMO_MODE", True)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # 1. Analyze symptoms
        analyze_res = await ac.post("/api/v1/symptoms/analyze", json={
            "description": "My cycle is delayed by 40 days and I have adult acne",
            "session_id": "test-session-api",
            "language": "en"
        })
        assert analyze_res.status_code == 200
        data = analyze_res.json()
        assert "extracted" in data
        assert "care_navigation" in data

        # 2. Try saving without consent (must fail with 400)
        no_consent_res = await ac.post("/api/v1/symptoms", json={
            "session_id": "test-session-api",
            "original_description": "My cycle is delayed by 40 days and I have adult acne",
            "confirmed_symptoms": ["Irregular Periods", "Acne Skin Issues"],
            "consent_given": False
        })
        assert no_consent_res.status_code == 400

        # 3. Save with consent (must succeed)
        consent_res = await ac.post("/api/v1/symptoms", json={
            "session_id": "test-session-api",
            "original_description": "My cycle is delayed by 40 days and I have adult acne",
            "confirmed_symptoms": ["Irregular Periods", "Acne Skin Issues"],
            "consent_given": True
        })
        assert consent_res.status_code == 200
        assert consent_res.json()["status"] == "success"

        # 4. Fetch history
        history_res = await ac.get("/api/v1/symptoms/history?session_id=test-session-api")
        assert history_res.status_code == 200
        hist_data = history_res.json()
        assert hist_data["count"] >= 1


@pytest.mark.asyncio
async def test_symptom_analysis_fails_safely_without_gemini_outside_demo(monkeypatch):
    monkeypatch.setattr(settings, "DEMO_MODE", False)
    monkeypatch.setattr(gemini_service, "client", None)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.post("/api/v1/symptoms/analyze", json={
            "description": "My cycle has been delayed for several weeks",
            "session_id": "test-no-gemini",
            "language": "en"
        })
    assert response.status_code == 503
    assert "temporarily unavailable" in response.json()["detail"].lower() or "unavailable" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_pdf_report_generation():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        report_res = await ac.post("/api/v1/reports/clinical-summary", json={
            "session_id": "demo-pcos-patient-001",
            "confirmed_symptoms": ["Irregular Menstrual Cycles", "Hirsutism"]
        })
        assert report_res.status_code == 200
        assert report_res.headers["content-type"] == "application/pdf"
        assert len(report_res.content) > 1000
        # Check PDF header bytes %PDF
        assert report_res.content.startswith(b"%PDF")

