from app.routes.health import router as health_router
from app.routes.knowledge import router as knowledge_router
from app.routes.symptoms import router as symptoms_router
from app.routes.cycles import router as cycles_router
from app.routes.reports import router as reports_router
from app.routes.safety import router as safety_router
from app.routes.voice import router as voice_router

__all__ = [
    "health_router",
    "knowledge_router",
    "symptoms_router",
    "cycles_router",
    "reports_router",
    "safety_router",
    "voice_router",
]

