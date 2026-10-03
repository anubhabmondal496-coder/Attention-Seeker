from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field
from app.state import SearchState

class VerificationStatus(str, Enum):
    NOT_A_MATCH = "NOT_A_MATCH"
    POSSIBLE_MATCH = "POSSIBLE_MATCH"
    LIKELY_MATCH = "LIKELY_MATCH"
    FOUND = "FOUND"

class VerificationResult(BaseModel):
    status: VerificationStatus
    confidence: float = Field(..., ge=0.0, le=1.0, description="Verification confidence score")
    reason: str = Field(..., description="Explanation of visual comparison findings")
    guidance: str = Field(..., description="Concise, actionable user instruction")
    matching_features: List[str] = Field(default_factory=list, description="Target features confirmed in candidate")
    missing_or_differing_features: List[str] = Field(
        default_factory=list,
        description="Features that differ or could not yet be confirmed"
    )

class VerifyCandidateResponse(BaseModel):
    status: VerificationStatus
    state: SearchState
    result: VerificationResult
    message: str
