from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field
from app.state import SearchState, VALID_TRANSITIONS
from models.target import TargetProfile

class StateTransitionRecord(BaseModel):
    from_state: SearchState
    to_state: SearchState
    reason: str
    timestamp: str = Field(default_factory=lambda: datetime.utcnow().isoformat())

class SearchSession(BaseModel):
    session_id: str
    state: SearchState = SearchState.TARGET_READY
    target_profile: Optional[TargetProfile] = None
    created_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    updated_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    duration_seconds: float = 0.0
    attempts_count: int = 0
    candidates_evaluated: int = 0
    history: List[StateTransitionRecord] = Field(default_factory=list)
    is_active: bool = True

class SessionStartRequest(BaseModel):
    session_id: Optional[str] = None
    target_profile: TargetProfile

class StateTransitionRequest(BaseModel):
    session_id: str
    to_state: SearchState
    reason: str = Field("State transition requested", description="Context or trigger for transition")

class SessionCompleteRequest(BaseModel):
    session_id: str
    reason: str = Field("Search session completed", description="Reason for finishing session")

class SessionResponse(BaseModel):
    success: bool
    session: SearchSession
    message: str
