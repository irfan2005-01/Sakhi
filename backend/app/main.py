import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.database import db_manager
from app.seed.knowledge_seed import seed_knowledge_base
from app.seed.demo_data import seed_demo_data
from app.routes import (
    health_router,
    knowledge_router,
    symptoms_router,
    cycles_router,
    reports_router,
    safety_router,
    voice_router,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("sakhi.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Safe Startup
    logger.info("Starting Sakhi Clinical API backend...")
    await db_manager.connect()
    
    # Seed knowledge base with verifiable guidelines
    k_count = await seed_knowledge_base(db_manager)
    logger.info("Clinical knowledge base verified (%d entries)", k_count)

    # Seed clearly labeled demo patient history
    if settings.DEMO_MODE:
        await seed_demo_data(db_manager)
        logger.info("Seeded illustrative demo patient data (demo-pcos-patient-001)")

    yield

    # Safe Shutdown
    logger.info("Shutting down Sakhi backend...")
    await db_manager.disconnect()


app = FastAPI(
    title="Sakhi: PCOS Vernacular Companion & Clinical Bridge API",
    description=(
        "Backend clinical bridge providing multilingual symptom analysis, deterministic medical safety, "
        "6-month longitudinal cycle analytics, verified guideline retrieval, and doctor consultation PDF summaries."
    ),
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register API Routers
app.include_router(health_router)
app.include_router(knowledge_router)
app.include_router(symptoms_router)
app.include_router(cycles_router)
app.include_router(reports_router)
app.include_router(safety_router)
app.include_router(voice_router)


@app.get("/")
async def root():
    return {
        "name": "Sakhi API",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
        "description": "PCOS Vernacular Companion & Clinical Bridge API"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=True)

