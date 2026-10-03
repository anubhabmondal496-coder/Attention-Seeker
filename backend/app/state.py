from enum import Enum
from typing import Set, Dict, List, Optional
from datetime import datetime
from pydantic import BaseModel, Field

class SearchState(str, Enum):
    IDLE = "IDLE"
    TARGET_READY = "TARGET_READY"
    SEARCHING = "SEARCHING"
    CANDIDATE_DETECTED = "CANDIDATE_DETECTED"
    VERIFYING = "VERIFYING"
    GUIDING = "GUIDING"
    FOUND = "FOUND"
    SEARCH_COMPLETE = "SEARCH_COMPLETE"

# Strict State Transition Graph
# Defines the only permitted state transitions in Attention Seeker
VALID_TRANSITIONS: Dict[SearchState, Set[SearchState]] = {
    SearchState.IDLE: {
        SearchState.TARGET_READY,
    },
    SearchState.TARGET_READY: {
        SearchState.SEARCHING,
        SearchState.IDLE,
    },
    SearchState.SEARCHING: {
        SearchState.CANDIDATE_DETECTED,
        SearchState.SEARCHING,         # frame sweep iterations
        SearchState.SEARCH_COMPLETE,   # user cancelled/timeout
        SearchState.IDLE,
    },
    SearchState.CANDIDATE_DETECTED: {
        SearchState.VERIFYING,
        SearchState.GUIDING,
        SearchState.SEARCHING,         # candidate lost or transient
        SearchState.SEARCH_COMPLETE,
    },
    SearchState.VERIFYING: {
        SearchState.FOUND,             # Gemma confirmed target match
        SearchState.GUIDING,           # Likely/possible: guide user closer
        SearchState.SEARCHING,         # Not a match: reject and resume sweep
        SearchState.SEARCH_COMPLETE,
    },
    SearchState.GUIDING: {
        SearchState.CANDIDATE_DETECTED,
        SearchState.VERIFYING,
        SearchState.SEARCHING,         # user panned away or candidate lost
        SearchState.FOUND,
        SearchState.SEARCH_COMPLETE,
    },
    SearchState.FOUND: {
        SearchState.SEARCH_COMPLETE,   # user acknowledges or finishes
        SearchState.SEARCHING,         # user chooses to resume/search another
        SearchState.IDLE,
    },
    SearchState.SEARCH_COMPLETE: {
        SearchState.IDLE,              # reset for new object
        SearchState.TARGET_READY,      # re-use profile to search again
    },
}
