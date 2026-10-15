import uuid
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, HTTPException, Response
from pydantic import BaseModel
from app.database import db_manager
from app.services.cycle_analytics import CycleAnalyticsService
from app.services.knowledge_service import KnowledgeRetrievalService
from app.services.pdf_service import ClinicalPDFReportGenerator

router = APIRouter(prefix="/api/v1/reports", tags=["Doctor Reports & PDF Export"])

# In-memory store for generated reports in current process
GENERATED_REPORTS_CACHE: Dict[str, bytes] = {}


class GenerateReportRequest(BaseModel):
    session_id: str
    confirmed_symptoms: Optional[List[str]] = None
    patient_notes: Optional[str] = None


@router.post("/clinical-summary")
async def generate_clinical_summary_pdf(req: GenerateReportRequest):
    """
    Generate downloadable one-page doctor preparation report PDF.
    Contains confirmed symptoms, cycle analytics, retrieved sources, and doctor questions.
    """
    cycle_service = CycleAnalyticsService(db_manager)
    analytics = await cycle_service.get_analytics(req.session_id)

    # Get symptoms from request or from database
    symptoms = req.confirmed_symptoms
    if not symptoms:
        col = db_manager.symptom_logs_collection
        cursor = col.find({"session_id": req.session_id})
        logs = await cursor.to_list(10)
        symptoms = []
        for l in logs:
            symptoms.extend(l.get("confirmed_symptoms", []))
        symptoms = list(set(symptoms))

    # Retrieve relevant knowledge
    knowledge_service = KnowledgeRetrievalService(db_manager)
    refs = await knowledge_service.retrieve_relevant_knowledge(
        symptoms=symptoms or ["general"],
        query_text=" ".join(symptoms) if symptoms else "PCOS clinical overview",
        limit=3
    )

    pdf_bytes = ClinicalPDFReportGenerator.generate_doctor_report(
        session_id=req.session_id,
        confirmed_symptoms=symptoms or ["Irregular menstrual cycles", "Consultation preparation"],
        cycle_analytics=analytics.model_dump(),
        knowledge_refs=[r.model_dump() for r in refs],
        patient_notes=req.patient_notes
    )

    report_id = str(uuid.uuid4())
    GENERATED_REPORTS_CACHE[report_id] = pdf_bytes

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="Sakhi_Doctor_Summary_{req.session_id}.pdf"',
            "X-Report-ID": report_id,
        }
    )


@router.get("/{report_id}")
async def get_report_pdf(report_id: str):
    """Download previously generated PDF report by ID."""
    if report_id not in GENERATED_REPORTS_CACHE:
        raise HTTPException(status_code=404, detail="Report ID not found or expired.")

    pdf_bytes = GENERATED_REPORTS_CACHE[report_id]
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="Sakhi_Report_{report_id[:8]}.pdf"'
        }
    )

