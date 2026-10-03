from typing import List, Optional
from pydantic import BaseModel, Field
from app.state import SearchState

class BoundingBox(BaseModel):
    ymin: float = Field(..., ge=0.0, le=1.0, description="Normalized top coordinate")
    xmin: float = Field(..., ge=0.0, le=1.0, description="Normalized left coordinate")
    ymax: float = Field(..., ge=0.0, le=1.0, description="Normalized bottom coordinate")
    xmax: float = Field(..., ge=0.0, le=1.0, description="Normalized right coordinate")

    @property
    def width(self) -> float:
        return max(0.0, self.xmax - self.xmin)

    @property
    def height(self) -> float:
        return max(0.0, self.ymax - self.ymin)

class Candidate(BaseModel):
    id: str = Field(..., description="Unique candidate identifier")
    bounding_box: BoundingBox
    confidence: float = Field(..., ge=0.0, le=1.0, description="Candidate detection confidence score")
    area_ratio: float = Field(..., description="Fraction of total frame area occupied by candidate")
    aspect_ratio: float = Field(..., description="Width-to-height ratio of candidate")
    crop_base64: Optional[str] = Field(None, description="Base64 JPEG crop of candidate region for Gemma verification")
    reason: str = Field(..., description="Reason for candidate proposal (e.g. color match, shape alignment)")

class CandidateDetectResponse(BaseModel):
    candidate_found: bool
    state: SearchState
    candidates: List[Candidate] = Field(default_factory=list)
    best_candidate: Optional[Candidate] = None
    message: str
