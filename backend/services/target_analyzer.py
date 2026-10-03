import json
import re
from typing import Optional
from models.target import TargetProfile, TargetAnalyzeResponse
from services.gemma_service import gemma_service
from app.state import SearchState

TARGET_ANALYSIS_SYSTEM_PROMPT = """You are SEEK, an expert computer-vision target profiling engine.
Your task is to analyze a reference photo of an object that the user has lost and wants to find.
Extract physical characteristics with high precision so that this EXACT physical object can be verified later.
You MUST output valid, parseable JSON only. Do not output conversational preamble or markdown explanations outside the JSON."""

class TargetAnalyzerService:
    @staticmethod
    def _extract_json(raw_text: str) -> dict:
        """Robustly extracts JSON from raw model output, handling code fences."""
        cleaned = raw_text.strip()
        # Remove ```json and ``` fences if present
        if "```" in cleaned:
            match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", cleaned, re.DOTALL)
            if match:
                cleaned = match.group(1)
            else:
                # Fallback: extract substring between first '{' and last '}'
                start = cleaned.find("{")
                end = cleaned.rfind("}")
                if start != -1 and end != -1:
                    cleaned = cleaned[start:end+1]
        else:
            start = cleaned.find("{")
            end = cleaned.rfind("}")
            if start != -1 and end != -1:
                cleaned = cleaned[start:end+1]

        return json.loads(cleaned)

    @classmethod
    def analyze(cls, image_bytes: bytes, user_description: Optional[str] = None) -> TargetAnalyzeResponse:
        user_context_clause = (
            f"User provided context/clue: \"{user_description}\"\n"
            if user_description and user_description.strip()
            else "No additional description provided by the user.\n"
        )

        prompt = f"""{user_context_clause}
Carefully examine the reference image of the lost object.
Provide a structured target profile in the following JSON format:
{{
    "object_type": "<e.g. cricket ball, keychain, wallet, earbuds case>",
    "primary_color": "<dominant visible color>",
    "secondary_color": "<accent or secondary color, or null>",
    "shape": "<geometric shape or form factor>",
    "material": "<perceived material: leather, metal, hard plastic, fabric, etc.>",
    "distinctive_features": [
        "<feature 1, e.g. dark green cross-stitched raised seam>",
        "<feature 2, e.g. gold SG emblem with laurel graphic>",
        "<feature 3, e.g. text inscribed 'believe become'>"
    ],
    "confidence": <float between 0.8 and 1.0 based on clarity of features>
}}

Return ONLY valid JSON matching this structure.
"""

        raw_output = gemma_service.generate_multimodal(
            image_bytes=image_bytes,
            prompt=prompt,
            system_prompt=TARGET_ANALYSIS_SYSTEM_PROMPT
        )

        try:
            parsed_data = cls._extract_json(raw_output)
            # Ensure user_description is preserved
            parsed_data["user_description"] = user_description.strip() if user_description else None

            # Validate against Pydantic schema
            profile = TargetProfile(**parsed_data)
        except Exception as err:
            # Fallback if model returned unstructured text
            profile = TargetProfile(
                object_type="unknown object",
                primary_color="unspecified",
                shape="unspecified",
                material="unspecified",
                distinctive_features=[raw_output[:200]],
                user_description=user_description,
                confidence=0.5
            )

        summary = (
            f"Target profile established for {profile.primary_color} {profile.object_type}. "
            f"Identified {len(profile.distinctive_features)} distinctive feature(s)."
        )

        return TargetAnalyzeResponse(
            target_profile=profile,
            state=SearchState.TARGET_READY,
            summary=summary
        )

target_analyzer_service = TargetAnalyzerService()
