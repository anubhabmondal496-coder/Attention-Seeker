from typing import Dict, List, Optional
from datetime import datetime
from models.memory import (
    SearchMemory,
    SpatialRegion,
    RejectedCandidateRecord,
    RecordObservationRequest,
    RecordRejectionRequest,
    MemorySummaryResponse
)

class SearchMemoryService:
    """
    Lightweight spatial search memory tracking.
    Remembers searched sectors, rejected candidates, search attempts,
    and calculates unexplored directions to plan user navigation.
    """

    ALL_DIRECTIONS = [
        "LOOK_CENTER",
        "LOOK_LEFT",
        "LOOK_RIGHT",
        "LOOK_LOWER_GROUND",
        "LOOK_UPPER_SHELF"
    ]

    def __init__(self):
        self._memories: Dict[str, SearchMemory] = {}

    def _get_or_create(self, session_id: str) -> SearchMemory:
        if session_id not in self._memories:
            self._memories[session_id] = SearchMemory(session_id=session_id)
        return self._memories[session_id]

    @staticmethod
    def _bin_orientation(pitch: float, roll: float) -> tuple[str, str, str]:
        """Discretizes pitch and roll into environmental spatial bins."""
        if pitch < -30.0:
            pitch_bin = "UP"
        elif pitch > 30.0:
            pitch_bin = "DOWN"
        else:
            pitch_bin = "LEVEL"

        if roll < -25.0:
            roll_bin = "LEFT"
        elif roll > 25.0:
            roll_bin = "RIGHT"
        else:
            roll_bin = "CENTER"

        sector_id = f"{pitch_bin}_{roll_bin}"
        return pitch_bin, roll_bin, sector_id

    def record_observation(self, req: RecordObservationRequest) -> SearchMemory:
        mem = self._get_or_create(req.session_id)
        pitch_bin, roll_bin, sector_id = self._bin_orientation(req.pitch, req.roll)

        if sector_id in mem.searched_regions:
            mem.searched_regions[sector_id].visit_count += 1
            mem.searched_regions[sector_id].last_visited = datetime.utcnow().isoformat()
        else:
            mem.searched_regions[sector_id] = SpatialRegion(
                region_id=sector_id,
                pitch_bin=pitch_bin,
                roll_bin=roll_bin,
                visit_count=1,
            )

        mem.current_search_direction = f"LOOK_{roll_bin}" if pitch_bin == "LEVEL" else f"LOOK_{pitch_bin}"
        mem.total_samples += 1
        if req.guidance:
            mem.last_guidance = req.guidance
        mem.updated_at = datetime.utcnow().isoformat()
        return mem

    def record_rejection(self, req: RecordRejectionRequest) -> SearchMemory:
        mem = self._get_or_create(req.session_id)
        record = RejectedCandidateRecord(
            candidate_id=req.candidate_id,
            reason=req.reason,
            bounding_box=req.bounding_box,
            similarity_score=req.similarity_score,
        )
        mem.rejected_candidates.append(record)
        mem.updated_at = datetime.utcnow().isoformat()
        return mem

    def get_summary(self, session_id: str) -> MemorySummaryResponse:
        mem = self._get_or_create(session_id)

        # Determine unexplored sectors from standard 5 directions
        explored_keys = set(mem.searched_regions.keys())
        unexplored = []

        if "LEVEL_CENTER" not in explored_keys:
            unexplored.append("LOOK_CENTER")
        if "LEVEL_LEFT" not in explored_keys:
            unexplored.append("LOOK_LEFT")
        if "LEVEL_RIGHT" not in explored_keys:
            unexplored.append("LOOK_RIGHT")
        if "DOWN_CENTER" not in explored_keys and "DOWN_LEFT" not in explored_keys:
            unexplored.append("LOOK_LOWER_GROUND")
        if "UP_CENTER" not in explored_keys:
            unexplored.append("LOOK_UPPER_SHELF")

        if unexplored:
            suggested = unexplored[0]
        else:
            # If all visited once, suggest least visited region
            least_visited = min(mem.searched_regions.values(), key=lambda r: r.visit_count, default=None)
            if least_visited:
                suggested = f"REVISIT_{least_visited.region_id}"
            else:
                suggested = "CONTINUE_SWEEP"

        return MemorySummaryResponse(
            session_id=session_id,
            explored_regions_count=len(mem.searched_regions),
            total_samples=mem.total_samples,
            rejected_candidates_count=len(mem.rejected_candidates),
            unexplored_directions=unexplored,
            suggested_direction=suggested,
            memory=mem
        )

search_memory_service = SearchMemoryService()
