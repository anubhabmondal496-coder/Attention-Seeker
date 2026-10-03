from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field
from app.state import SearchState
from models.candidate import Candidate
from models.verification import VerificationStatus

class GuidanceAction(str, Enum):
    PAN_LEFT = "PAN_LEFT"
    PAN_RIGHT = "PAN_RIGHT"
    TILT_UP = "TILT_UP"
    TILT_DOWN = "TILT_DOWN"
    MOVE_CLOSER = "MOVE_CLOSER"
    HOLD_STEADY = "HOLD_STEADY"
    OBJECT_FOUND = "OBJECT_FOUND"
    CONTINUE_SCANNING = "CONTINUE_SCANNING"

class DeviceOrientationData(BaseModel):
    pitch: float = Field(0.0, description="Device tilt forward/backward in degrees (-90 to +90)")
    roll: float = Field(0.0, description="Device roll left/right in degrees (-180 to +180)")
    azimuth: Optional[float] = Field(None, description="Compass azimuth heading (0 to 360)")

class SearchDecisionRequest(BaseModel):
    current_state: SearchState
    candidate: Optional[Candidate] = None
    verification_status: Optional[VerificationStatus] = None
    orientation: Optional[DeviceOrientationData] = None
    attempts_count: int = Field(0, description="Number of sampled search frames observed so far")

class SearchDecisionResponse(BaseModel):
    action: GuidanceAction
    guidance_text: str = Field(..., description="Short, actionable user instruction")
    next_state: SearchState
    reason: str = Field(..., description="Diagnostic rationale for guidance decision")
