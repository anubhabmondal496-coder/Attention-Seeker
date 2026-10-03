import uuid
from datetime import datetime
from typing import Dict, Optional, Tuple
from models.state import (
    SearchState,
    VALID_TRANSITIONS,
    SearchSession,
    StateTransitionRecord
)
from models.target import TargetProfile

class SearchSessionService:
    """
    Search session state machine controller.
    Enforces valid state transitions across IDLE -> TARGET_READY -> SEARCHING ->
    CANDIDATE_DETECTED -> VERIFYING -> GUIDING -> FOUND -> SEARCH_COMPLETE.
    Tracks session lifecycle, elapsed duration, attempt metrics, and state history.
    """

    def __init__(self):
        self._sessions: Dict[str, SearchSession] = {}
        self._created_timestamps: Dict[str, datetime] = {}

    def start_session(
        self,
        target_profile: TargetProfile,
        session_id: Optional[str] = None
    ) -> SearchSession:
        sid = session_id or f"seek_{uuid.uuid4().hex[:12]}"
        now = datetime.utcnow()
        now_iso = now.isoformat()

        initial_history = [
            StateTransitionRecord(
                from_state=SearchState.IDLE,
                to_state=SearchState.TARGET_READY,
                reason="Target profile configured and confirmed",
                timestamp=now_iso
            ),
            StateTransitionRecord(
                from_state=SearchState.TARGET_READY,
                to_state=SearchState.SEARCHING,
                reason="Camera search session initiated",
                timestamp=now_iso
            )
        ]

        session = SearchSession(
            session_id=sid,
            state=SearchState.SEARCHING,
            target_profile=target_profile,
            created_at=now_iso,
            updated_at=now_iso,
            duration_seconds=0.0,
            attempts_count=0,
            candidates_evaluated=0,
            history=initial_history,
            is_active=True
        )

        self._sessions[sid] = session
        self._created_timestamps[sid] = now
        return session

    def get_session(self, session_id: str) -> Optional[SearchSession]:
        session = self._sessions.get(session_id)
        if session and session.is_active:
            created_dt = self._created_timestamps.get(session_id)
            if created_dt:
                session.duration_seconds = round((datetime.utcnow() - created_dt).total_seconds(), 2)
        return session

    def transition_state(
        self,
        session_id: str,
        to_state: SearchState,
        reason: str
    ) -> Tuple[bool, SearchSession, str]:
        """
        Transitions the specified session to a new state if valid in the state graph.
        Returns (success: bool, session: SearchSession, message: str).
        """
        session = self.get_session(session_id)
        if not session:
            # Auto-create ephemeral session if ID does not exist yet
            session = self.start_session(
                target_profile=TargetProfile(
                    object_type="Generic Target",
                    primary_color="Unknown",
                    shape="Unknown",
                    material="Unknown",
                    distinctive_features=[],
                    confidence=1.0
                ),
                session_id=session_id
            )

        current = session.state

        # Same state transition is allowed as a heartbeat / no-op
        if current == to_state:
            session.updated_at = datetime.utcnow().isoformat()
            return True, session, f"State refreshed in {current.value}"

        allowed_next = VALID_TRANSITIONS.get(current, set())
        if to_state not in allowed_next:
            err_msg = f"Invalid state transition: Cannot transition from '{current.value}' to '{to_state.value}'. Allowed transitions: {[s.value for s in allowed_next]}"
            return False, session, err_msg

        # Record transition
        now_iso = datetime.utcnow().isoformat()
        session.history.append(
            StateTransitionRecord(
                from_state=current,
                to_state=to_state,
                reason=reason,
                timestamp=now_iso
            )
        )
        session.state = to_state
        session.updated_at = now_iso

        # Update metrics
        if to_state == SearchState.SEARCHING:
            session.attempts_count += 1
        elif to_state == SearchState.VERIFYING:
            session.candidates_evaluated += 1
        elif to_state == SearchState.SEARCH_COMPLETE:
            session.is_active = False

        return True, session, f"Transitioned from {current.value} to {to_state.value}: {reason}"

    def complete_session(self, session_id: str, reason: str = "Search finished") -> Optional[SearchSession]:
        session = self.get_session(session_id)
        if not session:
            return None

        success, session, _ = self.transition_state(
            session_id=session_id,
            to_state=SearchState.SEARCH_COMPLETE,
            reason=reason
        )
        return session

search_session_service = SearchSessionService()
