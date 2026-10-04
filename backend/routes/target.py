import io
from typing import Optional
from PIL import Image
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from models.target import TargetAnalyzeResponse
from services.target_analyzer import target_analyzer_service

router = APIRouter(prefix="/target", tags=["Target"])

@router.post("/analyze", response_model=TargetAnalyzeResponse)
async def analyze_target(
    image: Optional[UploadFile] = File(None, description="Optional reference photo of the lost object"),
    description: Optional[str] = Form(None, description="Optional text or voice description from user")
):
    """
    Receives an optional reference photo and/or voice description of the lost object,
    analyzes it using Gemma multimodal/text reasoning, and returns a structured TargetProfile.
    """
    if not image and (not description or not description.strip()):
        raise HTTPException(
            status_code=400,
            detail="Please provide either a photo of the lost object or describe it using voice typing."
        )

    image_bytes = None
    if image is not None:
        try:
            read_bytes = await image.read()
            if len(read_bytes) > 0:
                # Validate readable image
                try:
                    with Image.open(io.BytesIO(read_bytes)) as img:
                        img.verify()
                    image_bytes = read_bytes
                except Exception as img_err:
                    raise HTTPException(status_code=400, detail=f"Corrupt or unreadable image: {img_err}")
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Failed to process image: {e}")

    try:
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
