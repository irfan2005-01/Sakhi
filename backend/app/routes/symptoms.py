from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query
from app.database import db_manager
from app.models.schemas import (
    SymptomInput,
    SymptomAnalysisResponse,
    SymptomConfirmationRequest,
    PatientSymptomLog
)
from app.services.symptom_extraction import SymptomAnalysisUnavailable, SymptomExtractionPipeline

router = APIRouter(prefix="/api/v1/symptoms", tags=["Symptom Analysis & Logging"])


@router.post("/analyze", response_model=SymptomAnalysisResponse)
async def analyze_symptom(input_data: SymptomInput):
    """
    Multilingual vernacular symptom analysis pipeline.
    Sequence: Urgent screening -> Extraction -> Retrieval -> Validation -> Interception -> Response -> Audit
    """
    pipeline = SymptomExtractionPipeline(db_manager)
    try:
        return await pipeline.analyze_symptom(
            raw_description=input_data.description,
            session_id=input_data.session_id,
            language_pref=input_data.language or "auto"
        )
    except SymptomAnalysisUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from None


@router.post("", response_model=dict)
async def save_confirmed_symptoms(request: SymptomConfirmationRequest):
    """
    Save confirmed symptom observations to MongoDB.
    Strict Invariant: Requires explicit user consent before storing.
    """
    if not request.consent_given:
        raise HTTPException(
            status_code=400,
            detail="Consent is required to store symptom records. User chose not to consent."
        )

    log_doc = {
        "session_id": request.session_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "original_description": request.original_description,
        "input_language": "user_confirmed",
        "confirmed_symptoms": request.confirmed_symptoms,
        "reported_cycle_gap_days": request.reported_cycle_gap_days,
        "duration_and_context": request.duration_and_context,
        "notes": request.notes,
        "consent_status": True,
        "is_demo": False,
    }

    collection = db_manager.symptom_logs_collection
    result = await collection.insert_one(log_doc)

    return {
        "status": "success",
        "message": "Symptom observations saved securely with user consent.",
        "record_id": str(result.inserted_id)
    }


@router.get("/history")
async def get_symptom_history(session_id: str = Query(..., description="Anonymous session identifier")):
    """Retrieve logged symptoms strictly isolated to the requesting session ID."""
    collection = db_manager.symptom_logs_collection
    cursor = collection.find({"session_id": session_id})
    records = await cursor.to_list(length=50)

    # Format output cleanly
    clean_records = []
    for r in records:
        clean_records.append({
            "id": str(r.get("_id", "")),
            "session_id": r.get("session_id"),
            "timestamp": r.get("timestamp"),
            "original_description": r.get("original_description"),
            "confirmed_symptoms": r.get("confirmed_symptoms", []),
            "reported_cycle_gap_days": r.get("reported_cycle_gap_days"),
            "duration_and_context": r.get("duration_and_context"),
            "notes": r.get("notes"),
            "is_demo": r.get("is_demo", False),
        })

    return {"session_id": session_id, "count": len(clean_records), "records": clean_records}

