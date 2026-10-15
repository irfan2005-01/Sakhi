from typing import List
from fastapi import APIRouter, Query
from app.database import db_manager
from app.models.schemas import SafetyAuditLog

router = APIRouter(prefix="/api/v1/safety", tags=["Safety & Compliance Audit"])


@router.get("/audit", response_model=List[SafetyAuditLog])
async def get_safety_audit_logs(limit: int = Query(50, le=100)):
    """
    Query append-only safety audit log records.
    CRITICAL: This endpoint is strictly read-only. No modification or deletion is permitted.
    """
    col = db_manager.safety_audit_collection
    cursor = col.find({}, sort=[("timestamp", -1)])
    records = await cursor.to_list(limit)

    return [
        SafetyAuditLog(
            request_id=r.get("request_id", ""),
            timestamp=r.get("timestamp", ""),
            rule_triggered=r.get("rule_triggered", ""),
            action_taken=r.get("action_taken", ""),
            blocked_or_rewritten=r.get("blocked_or_rewritten", False),
            final_safety_status=r.get("final_safety_status", "UNKNOWN"),
            redacted_summary=r.get("redacted_summary", ""),
        )
        for r in records
    ]

