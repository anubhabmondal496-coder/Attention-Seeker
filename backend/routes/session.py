from fastapi import APIRouter, HTTPException
from models.state import (
    SearchSession,
    SessionStartRequest,
    StateTransitionRequest,
    SessionCompleteRequest,
    SessionResponse,
    SearchState
)
from services.search_session_service import search_session_service

router = APIRouter(prefix="/session", tags=["Search Session State Machine"])

@router.post("/start", response_model=SessionResponse)
def start_session(request: SessionStartRequest):
    """
    Initializes a new Search Session with state TARGET_READY -> SEARCHING (Phase 6).
    Associates the TargetProfile and tracks search lifecycle duration and attempts.
    """
    try:
        session = search_session_service.start_session(
            target_profile=request.target_profile,
            session_id=request.session_id
        )
        return SessionResponse(
            success=True,
            session=session,
            message="Search session created in SEARCHING state."
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to start session: {str(e)}")

@router.get("/{session_id}", response_model=SessionResponse)
def get_session(session_id: str):
    """
    Retrieves current state machine status, active metrics, and state history for a session.
    """
    session = search_session_service.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found.")
    return SessionResponse(
        success=True,
        session=session,
        message=f"Session in state {session.state.value}"
    )

@router.post("/transition", response_model=SessionResponse)
def transition_state(request: StateTransitionRequest):
    """
    Enforces and executes an explicit state machine transition.
    Rejects illegal transitions with 400 Bad Request if the state diagram does not permit it.
    """
    success, session, message = search_session_service.transition_state(
        session_id=request.session_id,
        to_state=request.to_state,
        reason=request.reason
    )
    if not success:
        raise HTTPException(status_code=400, detail=message)

    return SessionResponse(
        success=True,
        session=session,
        message=message
    )

@router.post("/complete", response_model=SessionResponse)
def complete_session(request: SessionCompleteRequest):
    """
    Formally completes the search session transitioning state to SEARCH_COMPLETE.
    """
    session = search_session_service.complete_session(
        session_id=request.session_id,
        reason=request.reason
    )
    if not session:
        raise HTTPException(status_code=404, detail=f"Session '{request.session_id}' not found.")

    return SessionResponse(
        success=True,
        session=session,
        message="Search session marked as SEARCH_COMPLETE."
    )
