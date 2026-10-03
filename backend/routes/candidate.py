import json
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from models.target import TargetProfile
from models.candidate import CandidateDetectResponse
from services.candidate_detector import candidate_detector_service

router = APIRouter(prefix="/candidate", tags=["Candidate Detection"])

@router.post("/detect", response_model=CandidateDetectResponse)
async def detect_candidate(
    frame: UploadFile = File(..., description="Sampled camera frame image"),
    target_profile: str = Form(..., description="Serialized JSON of TargetProfile")
):
    """
    Fast candidate proposal endpoint (Phase 3).
    Analyzes a sampled live camera frame against the target profile using lightweight CV.
    Returns candidate bounding box(es) and region crops if a match is plausible.
    """
    # Parse target profile
    try:
        profile_dict = json.loads(target_profile)
        profile = TargetProfile(**profile_dict)
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid target_profile JSON payload: {str(e)}"
        )

    # Read frame bytes
    try:
        frame_bytes = await frame.read()
        if len(frame_bytes) == 0:
            raise HTTPException(status_code=400, detail="Uploaded camera frame is empty.")

        response = candidate_detector_service.detect(
            frame_bytes=frame_bytes,
            target_profile=profile
        )
        return response

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Candidate detection failed: {str(exc)}"
        )
