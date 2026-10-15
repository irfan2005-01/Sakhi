from fastapi import APIRouter, HTTPException, Query
from app.database import db_manager
from app.models.schemas import CycleEntryCreate, CycleAnalyticsResult
from app.services.cycle_analytics import CycleAnalyticsService

router = APIRouter(prefix="/api/v1/cycles", tags=["Menstrual Cycle Analytics"])


@router.post("", response_model=dict)
async def record_cycle_start(entry: CycleEntryCreate):
    """
    Record a verified menstrual cycle start date.
    Validates formatting and rejects physiologically impossible/inconsistent dates.
    """
    service = CycleAnalyticsService(db_manager)
    try:
        doc = await service.add_cycle_entry(
            session_id=entry.session_id,
            period_start_date=entry.period_start_date,
            flow_intensity=entry.flow_intensity or "medium",
            is_demo=False
        )
        return {
            "status": "success",
            "message": "Menstrual start date recorded.",
            "entry": doc
        }
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to record cycle: {str(e)}")


@router.get("/analytics", response_model=CycleAnalyticsResult)
async def get_cycle_analytics(session_id: str = Query(..., description="Anonymous session ID")):
    """
    Retrieve longitudinal menstrual interval analysis for up to 6 months.
    Calculates consecutive intervals, variation, and highlights missing data intervals.
    """
    service = CycleAnalyticsService(db_manager)
    return await service.get_analytics(session_id=session_id)

