from fastapi import APIRouter
from models.guidance import SearchDecisionRequest, SearchDecisionResponse
from services.guidance_service import guidance_service

router = APIRouter(prefix="/search", tags=["Search Guidance & Planning"])

@router.post("/decision", response_model=SearchDecisionResponse)
def search_decision(request: SearchDecisionRequest):
    """
    Directional Search Guidance Endpoint (Phase 5).
    Evaluates candidate spatial centering, apparent size, orientation, and search history
    to generate short, actionable user guidance instructions.
    """
    return guidance_service.decide(request)
