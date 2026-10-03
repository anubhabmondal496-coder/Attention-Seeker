import json
import re
from typing import Optional, List
from models.target import TargetProfile
from models.verification import VerificationStatus, VerificationResult, VerifyCandidateResponse
from services.gemma_service import gemma_service
from app.state import SearchState

VERIFIER_SYSTEM_PROMPT = """You are Attention Seeker's expert multimodal verification agent.
Your mission is to perform rigorous forensic visual verification:
Determine whether a cropped image candidate found in the user's environment is the EXACT lost physical object described in the Target Profile.

Compare the candidate against the target profile:
- Primary and secondary colors
- Geometric shape and form factor
- Material texture and finish
- Distinctive features (logos, text, markings, seam stitching, serial numbers, wear)
- User's context and clues

Classification rules:
- FOUND: Definite match. The candidate clearly displays the target's distinctive features, markings, and material.
- LIKELY_MATCH: High resemblance (shape, colors, layout match) but fine details are partially occluded or slightly distant.
- POSSIBLE_MATCH: Shares general color/shape, but insufficient resolution to confirm identity.
- NOT_A_MATCH: Definitively a different object or background element.

Guidance instructions must be short and actionable (e.g. "Move closer.", "Object found.", "Hold camera steady.", "Not a match. Keep scanning.").

You MUST output ONLY valid JSON matching the requested schema. No markdown explanations outside the JSON."""

class VerifierService:
    @staticmethod
    def _extract_json(raw_text: str) -> dict:
        """Robustly extracts JSON from raw model output, handling code fences."""
        cleaned = raw_text.strip()
        if "```" in cleaned:
            match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", cleaned, re.DOTALL)
            if match:
                cleaned = match.group(1)
            else:
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
    def verify(
        cls,
        candidate_crop_bytes: bytes,
        target_profile: TargetProfile,
        reference_image_bytes: Optional[bytes] = None
    ) -> VerifyCandidateResponse:
        features_str = "\n".join(f"- {f}" for f in target_profile.distinctive_features) if target_profile.distinctive_features else "- Standard appearance"

        prompt = f"""[TARGET PROFILE]
- Object Type: {target_profile.object_type}
- Primary Color: {target_profile.primary_color}
- Secondary Color: {target_profile.secondary_color or 'None'}
- Shape: {target_profile.shape}
- Material: {target_profile.material}
- Distinctive Features:
{features_str}
- User Context: {target_profile.user_description or 'None'}

[TASK]
Carefully examine the attached image crop of the candidate object.
Determine if this candidate is the exact target object.

Output valid JSON only matching this schema:
{{
    "status": "FOUND | LIKELY_MATCH | POSSIBLE_MATCH | NOT_A_MATCH",
    "confidence": <float between 0.0 and 1.0>,
    "reason": "<Specific factual findings: which features matched or differed>",
    "guidance": "<Short actionable user instruction, max 6 words>",
    "matching_features": ["<feature 1>", "<feature 2>"],
    "missing_or_differing_features": ["<feature missing or different>"]
}}
"""

        raw_output = gemma_service.generate_multimodal(
            image_bytes=candidate_crop_bytes,
            prompt=prompt,
            system_prompt=VERIFIER_SYSTEM_PROMPT
        )

        try:
            parsed = cls._extract_json(raw_output)
            raw_status = str(parsed.get("status", "POSSIBLE_MATCH")).upper().strip()

            # Normalize status
            if "FOUND" in raw_status:
                status = VerificationStatus.FOUND
            elif "LIKELY" in raw_status:
                status = VerificationStatus.LIKELY_MATCH
            elif "NOT" in raw_status:
                status = VerificationStatus.NOT_A_MATCH
            else:
                status = VerificationStatus.POSSIBLE_MATCH

            result = VerificationResult(
                status=status,
                confidence=float(parsed.get("confidence", 0.7)),
                reason=str(parsed.get("reason", "Candidate evaluated against profile.")),
                guidance=str(parsed.get("guidance", "Checking candidate...")),
                matching_features=list(parsed.get("matching_features", [])),
                missing_or_differing_features=list(parsed.get("missing_or_differing_features", []))
            )
        except Exception as e:
            # Fallback if model returned unstructured text
            result = VerificationResult(
                status=VerificationStatus.POSSIBLE_MATCH,
                confidence=0.5,
                reason=raw_output[:200],
                guidance="Move closer.",
                matching_features=[],
                missing_or_differing_features=[]
            )

        # State transition according to verification status
        if result.status == VerificationStatus.FOUND:
            new_state = SearchState.FOUND
            message = "Target object verified and confirmed."
        elif result.status in (VerificationStatus.LIKELY_MATCH, VerificationStatus.POSSIBLE_MATCH):
            new_state = SearchState.GUIDING
            message = f"{result.status.value}: {result.reason}"
        else:
            new_state = SearchState.SEARCHING
            message = "Candidate rejected. Continuing environmental search."

        return VerifyCandidateResponse(
            status=result.status,
            state=new_state,
            result=result,
            message=message
        )

verifier_service = VerifierService()
