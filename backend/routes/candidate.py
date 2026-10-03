import json
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from models.target import TargetProfile
from models.candidate import CandidateDetectResponse
from models.verification import VerifyCandidateResponse
from services.candidate_detector import candidate_detector_service
from services.verifier_service import verifier_service

router = APIRouter(prefix="/candidate", tags=["Candidate Detection & Verification"])

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
    try:
        profile_dict = json.loads(target_profile)
        profile = TargetProfile(**profile_dict)
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid target_profile JSON payload: {str(e)}"
        )

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

@router.post("/verify", response_model=VerifyCandidateResponse)
async def verify_candidate(
    candidate_crop: UploadFile = File(..., description="Cropped candidate region image"),
    target_profile: str = Form(..., description="Serialized JSON of TargetProfile"),
    reference_image: Optional[UploadFile] = File(None, description="Optional original reference image")
):
    """
    Deep multimodal verification endpoint (Phase 4).
    Sends the cropped candidate image to Gemma for rigorous comparison against the TargetProfile.
    Returns classification: FOUND, LIKELY_MATCH, POSSIBLE_MATCH, or NOT_A_MATCH.
    """
    try:
        profile_dict = json.loads(target_profile)
        profile = TargetProfile(**profile_dict)
    except Exception as e:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid target_profile JSON payload: {str(e)}"
        )

    try:
        crop_bytes = await candidate_crop.read()
        if len(crop_bytes) == 0:
            raise HTTPException(status_code=400, detail="Uploaded candidate crop is empty.")

        ref_bytes = await reference_image.read() if reference_image else None

        response = verifier_service.verify(
            candidate_crop_bytes=crop_bytes,
            target_profile=profile,
            reference_image_bytes=ref_bytes
        )
        return response

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Gemma candidate verification failed: {str(exc)}"
        )
