import pytest
from app.services.cycle_analytics import CycleAnalyticsService
from app.database import InMemoryAsyncCollection


class MockDbManager:
    def __init__(self):
        self.cycles_collection = InMemoryAsyncCollection("menstrual_cycles")


@pytest.mark.asyncio
async def test_date_validation_rejects_future():
    service = CycleAnalyticsService(MockDbManager())
    is_valid, msg = service.validate_cycle_entry("2099-01-01", [])
    assert is_valid is False
    assert "future" in msg.lower()


@pytest.mark.asyncio
async def test_date_validation_rejects_impossibly_close_cycles():
    service = CycleAnalyticsService(MockDbManager())
    existing = ["2026-05-01"]
    is_valid, msg = service.validate_cycle_entry("2026-05-08", existing)
    assert is_valid is False
    assert "inconsistent" in msg.lower() or "days" in msg.lower()


@pytest.mark.asyncio
async def test_cycle_interval_and_irregularity_analytics():
    mock_db = MockDbManager()
    service = CycleAnalyticsService(mock_db)
    session_id = "test-session-123"

    # Add 4 cycles with irregular intervals (42, 48, 38 days)
    await service.add_cycle_entry(session_id, "2026-04-01")
    await service.add_cycle_entry(session_id, "2026-05-13") # gap 42
    await service.add_cycle_entry(session_id, "2026-06-30") # gap 48
    await service.add_cycle_entry(session_id, "2026-08-07") # gap 38

    analytics = await service.get_analytics(session_id)
    assert analytics.total_recorded_cycles == 4
    assert len(analytics.history) == 4
    assert analytics.average_gap_days is not None
    assert analytics.average_gap_days > 40
    assert analytics.min_gap_days == 38
    assert analytics.max_gap_days == 48
    assert analytics.irregularity_flag is True
    # Invariant: Must NEVER be a standalone diagnosis
    assert analytics.is_diagnostic is False
    assert "Rotterdam" in analytics.clinical_note or "ovulation" in analytics.clinical_note or "doctor" in analytics.clinical_note

