from datetime import datetime, timedelta
from typing import List, Dict, Any

DEMO_CYCLE_RECORDS: List[Dict[str, Any]] = [
    {
        "session_id": "demo-pcos-patient-001",
        "period_start_date": "2026-04-10",
        "cycle_gap_days": None,  # Baseline
        "flow_intensity": "medium",
        "is_demo": True,
        "created_at": "2026-04-10T08:00:00Z",
    },
    {
        "session_id": "demo-pcos-patient-001",
        "period_start_date": "2026-05-22",
        "cycle_gap_days": 42,
        "flow_intensity": "heavy",
        "is_demo": True,
        "created_at": "2026-05-22T08:00:00Z",
    },
    {
        "session_id": "demo-pcos-patient-001",
        "period_start_date": "2026-07-09",
        "cycle_gap_days": 48,
        "flow_intensity": "light",
        "is_demo": True,
        "created_at": "2026-07-09T08:00:00Z",
    },
    {
        "session_id": "demo-pcos-patient-001",
        "period_start_date": "2026-08-30",
        "cycle_gap_days": 52,
        "flow_intensity": "medium",
        "is_demo": True,
        "created_at": "2026-08-30T08:00:00Z",
    },
    {
        "session_id": "demo-pcos-patient-001",
        "period_start_date": "2026-10-08",
        "cycle_gap_days": 39,
        "flow_intensity": "heavy",
        "is_demo": True,
        "created_at": "2026-10-08T08:00:00Z",
    },
]

DEMO_SYMPTOM_LOGS: List[Dict[str, Any]] = [
    {
        "session_id": "demo-pcos-patient-001",
        "timestamp": "2026-10-08T10:30:00Z",
        "original_description": "Mera period pichle 5 mahine se irregular hai, chin pe hair growth aur weight badh gaya hai.",
        "input_language": "Hinglish",
        "confirmed_symptoms": ["Irregular periods", "Facial hair growth (hirsutism)", "Weight gain"],
        "reported_cycle_gap_days": 45,
        "knowledge_references": ["kb-cycle-irregularity", "kb-hyperandrogenism", "kb-insulin-resistance"],
        "safety_outcome": {
            "passed": True,
            "action_taken": "none",
            "urgent_care_required": False,
            "is_diagnostic_claim_prevented": True
        },
        "consent_status": True,
        "is_demo": True,
    }
]


async def seed_demo_data(db_manager):
    """Seed demo data with clear labels if not already present."""
    cycles_col = db_manager.cycles_collection
    count = await cycles_col.count_documents({"session_id": "demo-pcos-patient-001"})
    if count == 0:
        await cycles_col.insert_many(DEMO_CYCLE_RECORDS)

    symptoms_col = db_manager.symptom_logs_collection
    count_sym = await symptoms_col.count_documents({"session_id": "demo-pcos-patient-001"})
    if count_sym == 0:
        await symptoms_col.insert_many(DEMO_SYMPTOM_LOGS)

