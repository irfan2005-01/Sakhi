import math
from datetime import datetime, date, timezone
from typing import List, Dict, Any, Optional, Tuple
from app.models.schemas import CycleAnalyticsResult, CycleRecord
import logging

logger = logging.getLogger("sakhi.cycle_analytics")


class CycleAnalyticsService:
    def __init__(self, db_manager):
        self.db_manager = db_manager

    @staticmethod
    def validate_cycle_entry(date_str: str, existing_dates: List[str]) -> Tuple[bool, str]:
        """Validate date format, reasonableness, and reject physiologically impossible entries."""
        try:
            entry_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            return False, "Invalid date format. Expected YYYY-MM-DD."

        today = date.today()
        if entry_date > today:
            return False, "Menstrual start date cannot be in the future."

        # Cannot be more than 2 years in the past
        if (today - entry_date).days > 730:
            return False, "Date is too far in the past (> 2 years)."

        # Reject duplicate or impossibly close cycle starts (< 14 days apart)
        for existing in existing_dates:
            try:
                ex_date = datetime.strptime(existing, "%Y-%m-%d").date()
                gap = abs((entry_date - ex_date).days)
                if gap < 14:
                    return False, f"Inconsistent entry: date is only {gap} days from another recorded start ({existing})."
            except ValueError:
                continue

        return True, "Valid"

    async def add_cycle_entry(self, session_id: str, period_start_date: str, flow_intensity: str = "medium", is_demo: bool = False) -> Dict[str, Any]:
        collection = self.db_manager.cycles_collection

        # Retrieve existing dates for session
        cursor = collection.find({"session_id": session_id})
        existing_records = await cursor.to_list(100)
        existing_dates = [r.get("period_start_date") for r in existing_records if r.get("period_start_date")]

        is_valid, err_msg = self.validate_cycle_entry(period_start_date, existing_dates)
        if not is_valid:
            raise ValueError(err_msg)

        new_doc = {
            "session_id": session_id,
            "period_start_date": period_start_date,
            "flow_intensity": flow_intensity,
            "is_demo": is_demo,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        await collection.insert_one(new_doc)
        return new_doc

    async def get_analytics(self, session_id: str) -> CycleAnalyticsResult:
        collection = self.db_manager.cycles_collection

        # Fetch records sorted by start date
        cursor = collection.find({"session_id": session_id})
        records = await cursor.to_list(100)

        if not records:
            return CycleAnalyticsResult(
                session_id=session_id,
                total_recorded_cycles=0,
                observation_window_months=6,
                history=[],
                clinical_note="No menstrual cycles recorded yet. Log your dates over consecutive months to visualize patterns.",
                is_diagnostic=False,
            )

        # Sort chronologically
        valid_records = []
        for r in records:
            try:
                parsed_dt = datetime.strptime(r["period_start_date"], "%Y-%m-%d").date()
                valid_records.append((parsed_dt, r))
            except Exception:
                continue

        valid_records.sort(key=lambda x: x[0])

        # Compute consecutive gaps
        history = []
        gaps: List[int] = []
        missing_intervals: List[str] = []

        for i, (dt, doc) in enumerate(valid_records):
            gap_days = None
            if i > 0:
                prev_dt = valid_records[i - 1][0]
                gap_days = (dt - prev_dt).days
                gaps.append(gap_days)

                # Check for skipped cycles (> 65 days between starts)
                if gap_days > 65:
                    missing_intervals.append(
                        f"Significant gap between {prev_dt.strftime('%b %Y')} and {dt.strftime('%b %Y')} ({gap_days} days). Possible missing data or prolonged amenorrhea."
                    )

            history.append({
                "period_start_date": dt.isoformat(),
                "cycle_gap_days": gap_days,
                "flow_intensity": doc.get("flow_intensity", "medium"),
                "is_demo": doc.get("is_demo", False),
            })

        # Calculate statistics
        avg_gap = round(sum(gaps) / len(gaps), 1) if gaps else None
        min_gap = min(gaps) if gaps else None
        max_gap = max(gaps) if gaps else None

        variation_sd = None
        if len(gaps) >= 2:
            mean = sum(gaps) / len(gaps)
            variance = sum((g - mean) ** 2 for g in gaps) / (len(gaps) - 1)
            variation_sd = round(math.sqrt(variance), 1)

        # Irregularity assessment based on clinical criteria (cycle > 35 days or SD > 7 days)
        irregularity = False
        if gaps:
            if any(g > 35 or g < 21 for g in gaps) or (variation_sd and variation_sd > 7.0):
                irregularity = True

        # Construct educational clinical note (strictly non-diagnostic)
        if len(gaps) == 0:
            note = f"1 period recorded on {valid_records[0][0].strftime('%d %b %Y')}. At least 2 recorded cycles are required to calculate intervals."
        elif irregularity:
            note = (
                f"Observed cycle variation shows intervals ranging between {min_gap} and {max_gap} days "
                f"(average: {avg_gap} days). A variation of > 7 days or cycles longer than 35 days can indicate "
                f"infrequent ovulation. This is common in PCOS and other hormonal patterns, and warrants clinical assessment with your doctor."
            )
        else:
            note = (
                f"Recorded intervals are relatively regular with an average gap of {avg_gap} days. "
                f"Continue tracking to identify your individual baseline over 6 months."
            )

        return CycleAnalyticsResult(
            session_id=session_id,
            total_recorded_cycles=len(valid_records),
            observation_window_months=6,
            average_gap_days=avg_gap,
            min_gap_days=min_gap,
            max_gap_days=max_gap,
            variation_sd=variation_sd,
            irregularity_flag=irregularity,
            missing_data_intervals=missing_intervals,
            history=history,
            clinical_note=note,
            is_diagnostic=False,
        )
