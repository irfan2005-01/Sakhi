from fastapi import APIRouter
from app.database import db_manager
from app.services.gemini_service import gemini_service
from app.config import settings

router = APIRouter(tags=["Health & Status"])


@router.get("/health")
async def health_check():
    """Health check endpoint validating database connectivity and Gemini availability."""
    db_status = "connected" if db_manager.is_connected else ("in_memory_fallback" if db_manager.use_fallback else "disconnected")
    service_status = "healthy" if db_manager.is_connected else "degraded"
    ai_status = "live_gemini" if gemini_service.is_live else ("deterministic_demo_mode" if settings.DEMO_MODE else "unavailable")

    return {
        "status": service_status,
        "service": "Sakhi Clinical API",
        "database": {
            "status": db_status,
            "database_name": settings.MONGODB_DATABASE,
            "is_resilient_fallback_active": db_manager.use_fallback,
            "persistence_available": db_manager.is_connected,
            "connection_error": db_manager.last_error,
        },
        "ai_engine": {
            "status": ai_status,
            "model": settings.GEMINI_MODEL,
            "is_live_gemini_active": gemini_service.is_live,
            "demo_mode": settings.DEMO_MODE
        },
        "clinical_safety_engine": "active"
    }

