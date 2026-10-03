import io
from typing import Optional
from PIL import Image
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from models.target import TargetAnalyzeResponse
from services.target_analyzer import target_analyzer_service

router = APIRouter(prefix="/target", tags=["Target"])

@router.post("/analyze", response_model=TargetAnalyzeResponse)
async def analyze_target(
    image: UploadFile = File(..., description="Reference photo of the lost object"),
    description: Optional[str] = Form(None, description="Optional text description from user")
):
    """
    Receives a reference photo and optional description of the lost object,
    analyzes it using Gemma multimodal reasoning, and returns a structured TargetProfile.
    """
    # Some mobile HTTP clients send generic 'application/octet-stream' for multipart files.
    # We validate actual image integrity via PIL below rather than strictly trusting the header.
    if image.content_type and not (image.content_type.startswith("image/") or image.content_type == "application/octet-stream"):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type '{image.content_type}'. Must be an image (JPEG, PNG, WebP, etc.)."
        )

    try:
        image_bytes = await image.read()
        if len(image_bytes) == 0:
            raise HTTPException(status_code=400, detail="Uploaded image file is empty.")

        # Validate that the bytes form a readable image
        try:
            with Image.open(io.BytesIO(image_bytes)) as img:
                img.verify()
        except Exception as img_err:
            raise HTTPException(status_code=400, detail=f"Corrupt or unreadable image: {img_err}")

        # Run Gemma target profile analysis
        result = target_analyzer_service.analyze(
            image_bytes=image_bytes,
            user_description=description
        )
        return result

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Target analysis failed: {str(exc)}")
