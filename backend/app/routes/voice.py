from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.database import db_manager
from app.models.schemas import (
    SymptomAnalysisResponse,
    VoiceAnalysisResponse,
    VoiceSynthesisRequest,
    VoiceSynthesisResponse,
)
from app.services.sarvam_service import SarvamUnavailable, sarvam_service
from app.services.symptom_extraction import SymptomAnalysisUnavailable, SymptomExtractionPipeline

router = APIRouter(prefix="/api/v1/voice", tags=["Voice"])
MAX_AUDIO_BYTES = 12 * 1024 * 1024


@router.post("/analyze", response_model=VoiceAnalysisResponse)
async def analyze_voice(
    audio: UploadFile = File(...),
    session_id: str = Form(..., min_length=1, max_length=128),
    language: str = Form("auto", max_length=32),
):
    content_type = (audio.content_type or "").lower()
    if not content_type.startswith("audio/"):
        raise HTTPException(status_code=415, detail="Upload a supported audio recording.")
    contents = await audio.read(MAX_AUDIO_BYTES + 1)
    await audio.close()
    if not contents:
        raise HTTPException(status_code=422, detail="The audio recording is empty.")
    if len(contents) > MAX_AUDIO_BYTES:
        raise HTTPException(status_code=413, detail="Audio uploads must be 12 MB or smaller.")
    try:
        transcript, detected_language = await sarvam_service.transcribe(
            contents,
            audio.filename or "recording.webm",
            content_type,
        )
        analysis = await SymptomExtractionPipeline(db_manager).analyze_symptom(
            raw_description=transcript,
            session_id=session_id,
            language_pref=detected_language or language or "auto",
        )
    except SarvamUnavailable as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from None
    except SymptomAnalysisUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from None
    return VoiceAnalysisResponse(
        transcript=transcript,
        detected_language=detected_language,
        analysis=analysis,
    )


@router.post("/synthesize", response_model=VoiceSynthesisResponse)
async def synthesize_speech(request: VoiceSynthesisRequest):
    try:
        audio = await sarvam_service.synthesize(request.text, request.language_code)
    except SarvamUnavailable as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from None
    return audio
