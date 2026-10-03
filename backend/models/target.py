from typing import List, Optional
from pydantic import BaseModel, Field
from app.state import SearchState

class TargetProfile(BaseModel):
    object_type: str = Field(..., description="Category or name of the physical object (e.g. cricket ball, keychain)")
    primary_color: str = Field(..., description="Dominant visual color of the object")
    secondary_color: Optional[str] = Field(None, description="Accent or secondary color, if present")
    shape: str = Field(..., description="Geometric shape or physical form factor")
    material: str = Field(..., description="Surface material or perceived texture (e.g. leather, plastic, metal)")
    distinctive_features: List[str] = Field(
        default_factory=list,
        description="List of specific distinctive features, markings, logos, stitches, or text that identify this exact instance"
    )
    user_description: Optional[str] = Field(None, description="Original user-provided context or description")
    confidence: float = Field(default=0.9, ge=0.0, le=1.0, description="Model confidence score for profile extraction")

class TargetAnalyzeResponse(BaseModel):
    target_profile: TargetProfile
    state: SearchState = SearchState.TARGET_READY
    summary: str
