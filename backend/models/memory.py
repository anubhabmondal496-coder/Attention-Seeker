from typing import List, Optional, Dict
from pydantic import BaseModel, Field
from datetime import datetime
from app.state import SearchState
from models.candidate import BoundingBox

class SpatialRegion(BaseModel):
    region_id: str = Field(..., description="Unique sector identifier (e.g., sector_pitch_neg_roll_pos)")
    pitch_bin: str = Field(..., description="Pitch range (e.g., 'UP', 'LEVEL', 'DOWN')")
    roll_bin: str = Field(..., description="Roll/pan range (e.g., 'LEFT', 'CENTER', 'RIGHT')")
    visit_count: int = 1
    last_visited: str = Field(default_factory=lambda: datetime.utcnow().isoformat())

class RejectedCandidateRecord(BaseModel):
    candidate_id: str
    reason: str
    rejection_timestamp: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    bounding_box: Optional[BoundingBox] = None
    similarity_score: float = 0.0

class SearchMemory(BaseModel):
    session_id: str
    searched_regions: Dict[str, SpatialRegion] = Field(default_factory=dict)
    rejected_candidates: List[RejectedCandidateRecord] = Field(default_factory=list)
    current_search_direction: str = "CENTER"
    total_samples: int = 0
    last_guidance: Optional[str] = None
    created_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())
    updated_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())

class RecordObservationRequest(BaseModel):
    session_id: str
    pitch: float
    roll: float
    azimuth: Optional[float] = None
    guidance: Optional[str] = None

class RecordRejectionRequest(BaseModel):
    session_id: str
    candidate_id: str
    reason: str
    bounding_box: Optional[BoundingBox] = None
    similarity_score: float = 0.0

class MemorySummaryResponse(BaseModel):
    session_id: str
    explored_regions_count: int
    total_samples: int
    rejected_candidates_count: int
    unexplored_directions: List[str]
    suggested_direction: str
    memory: SearchMemory
