from models.guidance import (
    GuidanceAction,
    DeviceOrientationData,
    SearchDecisionRequest,
    SearchDecisionResponse
)
from app.state import SearchState
from models.verification import VerificationStatus

class GuidanceService:
    """
    Search guidance decision engine.
    Analyzes visual candidate positions, device orientation, and verification states
    to produce short, actionable user instructions.
    """

    # Structured panning sweep plan for unexplored areas
    SCAN_SWEEPS = [
        (GuidanceAction.PAN_LEFT, "Move camera slightly left.", "Sweep left sector."),
        (GuidanceAction.PAN_RIGHT, "Pan slowly to your right.", "Sweep right sector."),
        (GuidanceAction.TILT_DOWN, "Look lower toward surfaces.", "Inspect lower ground/table level."),
        (GuidanceAction.MOVE_CLOSER, "Move closer to surfaces.", "Explore deeper zone."),
    ]

    @classmethod
    def decide(cls, request: SearchDecisionRequest) -> SearchDecisionResponse:
        # 1. Object already confirmed
        if request.verification_status == VerificationStatus.FOUND or request.current_state == SearchState.FOUND:
            return SearchDecisionResponse(
                action=GuidanceAction.OBJECT_FOUND,
                guidance_text="Object found.",
                next_state=SearchState.FOUND,
                reason="Target object definitively verified."
            )

        # 2. Verification in flight
        if request.current_state == SearchState.VERIFYING:
            return SearchDecisionResponse(
                action=GuidanceAction.HOLD_STEADY,
                guidance_text="Hold the camera steady.",
                next_state=SearchState.VERIFYING,
                reason="Gemma forensic analysis in progress."
            )

        # 3. Candidate in view: Guide user to center and zoom in on candidate
        if request.candidate is not None:
            box = request.candidate.bounding_box
            cx = (box.xmin + box.xmax) / 2.0
            cy = (box.ymin + box.ymax) / 2.0

            # Horizontal centering
            if cx < 0.38:
                return SearchDecisionResponse(
                    action=GuidanceAction.PAN_LEFT,
                    guidance_text="Move camera slightly left.",
                    next_state=SearchState.GUIDING,
                    reason=f"Candidate located on the left (center x={cx:.2f})."
                )
            elif cx > 0.62:
                return SearchDecisionResponse(
                    action=GuidanceAction.PAN_RIGHT,
                    guidance_text="Move camera slightly right.",
                    next_state=SearchState.GUIDING,
                    reason=f"Candidate located on the right (center x={cx:.2f})."
                )

            # Vertical centering
            if cy < 0.32:
                return SearchDecisionResponse(
                    action=GuidanceAction.TILT_UP,
                    guidance_text="Tilt camera slightly up.",
                    next_state=SearchState.GUIDING,
                    reason=f"Candidate located high in frame (center y={cy:.2f})."
                )
            elif cy > 0.68:
                return SearchDecisionResponse(
                    action=GuidanceAction.TILT_DOWN,
                    guidance_text="Look lower.",
                    next_state=SearchState.GUIDING,
                    reason=f"Candidate located low in frame (center y={cy:.2f})."
                )

            # Centered: Check if progressive zoom / up to 4x crop is engaged for small object
            zoom = getattr(request.candidate, "zoom_level", 1.0)
            if zoom > 1.2 or request.candidate.area_ratio < 0.10:
                return SearchDecisionResponse(
                    action=GuidanceAction.CROPPING,
                    guidance_text="Cropping. Please hold steady.",
                    next_state=SearchState.VERIFYING,
                    reason=f"Small candidate framed with {zoom:.1f}x crop. Zooming in for forensic inspection."
                )

            return SearchDecisionResponse(
                action=GuidanceAction.HOLD_STEADY,
                guidance_text="Hold the camera steady.",
                next_state=SearchState.VERIFYING,
                reason="Candidate is centered and well-framed for verification."
            )

        # 4. No candidate: Memory-informed environmental sweep guidance
        # Use orientation tilt to give contextual feedback if device is pointed excessively high
        if request.orientation and request.orientation.pitch < -40.0:
            return SearchDecisionResponse(
                action=GuidanceAction.TILT_DOWN,
                guidance_text="Look lower toward surfaces.",
                next_state=SearchState.SEARCHING,
                reason="Camera pitched upwards toward ceiling."
            )

        # Consult Search Memory (Phase 7) to guide user toward unexplored sectors
        if request.session_id:
            try:
                from services.search_memory_service import search_memory_service
                summary = search_memory_service.get_summary(request.session_id)
                suggested = summary.suggested_direction

                if suggested == "LOOK_LEFT":
                    return SearchDecisionResponse(
                        action=GuidanceAction.PAN_LEFT,
                        guidance_text="Move camera slightly left.",
                        next_state=SearchState.SEARCHING,
                        reason="Exploring unsearched left sector based on memory."
                    )
                elif suggested == "LOOK_RIGHT":
                    return SearchDecisionResponse(
                        action=GuidanceAction.PAN_RIGHT,
                        guidance_text="Pan slowly to your right.",
                        next_state=SearchState.SEARCHING,
                        reason="Exploring unsearched right sector based on memory."
                    )
                elif suggested == "LOOK_LOWER_GROUND":
                    return SearchDecisionResponse(
                        action=GuidanceAction.TILT_DOWN,
                        guidance_text="Look lower toward the floor.",
                        next_state=SearchState.SEARCHING,
                        reason="Exploring lower floor/shelf zone based on memory."
                    )
                elif suggested == "LOOK_UPPER_SHELF":
                    return SearchDecisionResponse(
                        action=GuidanceAction.TILT_UP,
                        guidance_text="Tilt camera slightly up.",
                        next_state=SearchState.SEARCHING,
                        reason="Exploring upper surface zone based on memory."
                    )
            except Exception:
                pass

        # Alternate sweep instructions fallback
        sweep_idx = (request.attempts_count // 3) % len(cls.SCAN_SWEEPS)
        action, text, reason = cls.SCAN_SWEEPS[sweep_idx]

        return SearchDecisionResponse(
            action=action,
            guidance_text=text,
            next_state=SearchState.SEARCHING,
            reason=f"Unexplored environmental sweep: {reason}"
        )

guidance_service = GuidanceService()
