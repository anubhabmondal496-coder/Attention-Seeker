from fastapi import APIRouter, HTTPException
from models.memory import (
    RecordObservationRequest,
    RecordRejectionRequest,
    MemorySummaryResponse,
    SearchMemory
)
from services.search_memory_service import search_memory_service

router = APIRouter(prefix="/memory", tags=["Search Memory (Phase 7)"])

@router.post("/observation", response_model=SearchMemory)
def record_observation(req: RecordObservationRequest):
    """
    Records device orientation coordinates during a sampled frame, updating explored sector bins.
    """
    return search_memory_service.record_observation(req)

@router.post("/rejection", response_model=SearchMemory)
def record_rejection(req: RecordRejectionRequest):
    """
    Records a candidate that was evaluated and rejected (NOT_A_MATCH), preventing repetitive checks.
    """
    return search_memory_service.record_rejection(req)

@router.get("/{session_id}/summary", response_model=MemorySummaryResponse)
def get_memory_summary(session_id: str):
    """
    Returns search coverage metrics, explored sectors, and suggested unexplored directions.
    """
    return search_memory_service.get_summary(session_id)
