import io
import cv2
import uuid
import base64
import numpy as np
from typing import List, Optional, Tuple, Dict
from PIL import Image

from models.target import TargetProfile
from models.candidate import BoundingBox, Candidate, CandidateDetectResponse
from app.state import SearchState

HSV_COLOR_RANGES: Dict[str, List[Tuple[np.ndarray, np.ndarray]]] = {
    "white": [
        (np.array([0, 0, 180]), np.array([180, 50, 255]))
    ],
    "black": [
        (np.array([0, 0, 0]), np.array([180, 255, 60]))
    ],
    "red": [
        (np.array([0, 70, 50]), np.array([10, 255, 255])),
        (np.array([170, 70, 50]), np.array([180, 255, 255]))
    ],
    "green": [
        (np.array([35, 50, 40]), np.array([85, 255, 255]))
    ],
    "blue": [
        (np.array([90, 60, 40]), np.array([135, 255, 255]))
    ],
    "yellow": [
        (np.array([18, 70, 80]), np.array([35, 255, 255]))
    ],
    "gold": [
        (np.array([15, 80, 80]), np.array([35, 255, 240]))
    ],
    "orange": [
        (np.array([10, 90, 80]), np.array([22, 255, 255]))
    ],
    "gray": [
        (np.array([0, 0, 65]), np.array([180, 40, 175]))
    ],
    "silver": [
        (np.array([0, 0, 120]), np.array([180, 35, 220]))
    ]
}

class CandidateDetectorService:
    """
    Lightweight, fast visual candidate generator (15-30ms CPU).
    Samples frames, proposes candidate regions of interest, and generates crops
    prior to invoking multimodal LLM reasoning in Phase 4.
    """

    @classmethod
    def _crop_and_encode(
        cls,
        image_bgr: np.ndarray,
        box: BoundingBox,
        frame_w: int,
        frame_h: int
    ) -> str:
        """Crops candidate box with small margin and encodes to JPEG base64."""
        pad_x = int(box.width * frame_w * 0.08)
        pad_y = int(box.height * frame_h * 0.08)

        x1 = max(0, int(box.xmin * frame_w) - pad_x)
        y1 = max(0, int(box.ymin * frame_h) - pad_y)
        x2 = min(frame_w, int(box.xmax * frame_w) + pad_x)
        y2 = min(frame_h, int(box.ymax * frame_h) + pad_y)

        crop = image_bgr[y1:y2, x1:x2]
        if crop.size == 0:
            crop = image_bgr

        _, buf = cv2.imencode(".jpg", crop, [cv2.IMWRITE_JPEG_QUALITY, 85])
        return base64.b64encode(buf.tobytes()).decode("utf-8")

    @classmethod
    def detect(
        cls,
        frame_bytes: bytes,
        target_profile: TargetProfile
    ) -> CandidateDetectResponse:
        # Decode frame
        np_arr = np.frombuffer(frame_bytes, np.uint8)
        image_bgr = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

        if image_bgr is None:
            return CandidateDetectResponse(
                candidate_found=False,
                state=SearchState.SEARCHING,
                message="Unable to decode frame bytes."
            )

        frame_h, frame_w = image_bgr.shape[:2]
        total_pixels = frame_h * frame_w

        gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
        hsv_img = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2HSV)

        # 1. Edge and Saliency Contours
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        edges = cv2.Canny(blurred, 30, 110)
        kernel_edge = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
        closed_edges = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel_edge, iterations=3)
        saliency_contours, _ = cv2.findContours(closed_edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        # 2. Color Contours
        color_contours = []
        lower_name = target_profile.primary_color.lower().strip()
        matched_ranges = None
        for key in HSV_COLOR_RANGES:
            if key in lower_name:
                matched_ranges = HSV_COLOR_RANGES[key]
                break

        if matched_ranges:
            color_mask = None
            for lower, upper in matched_ranges:
                m = cv2.inRange(hsv_img, lower, upper)
                color_mask = m if color_mask is None else cv2.bitwise_or(color_mask, m)

            # Avoid full-screen background saturation (e.g. if >75% of the frame is that color)
            if color_mask is not None and (0.01 * total_pixels) < cv2.countNonZero(color_mask) < (0.75 * total_pixels):
                k_col = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
                color_mask = cv2.morphologyEx(color_mask, cv2.MORPH_OPEN, k_col, iterations=1)
                color_mask = cv2.morphologyEx(color_mask, cv2.MORPH_CLOSE, k_col, iterations=2)
                cnts, _ = cv2.findContours(color_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
                color_contours.extend(cnts)

        # Combine contour sets
        all_contours = list(saliency_contours) + list(color_contours)

        is_spherical = any(term in target_profile.shape.lower() for term in ["sphere", "spherical", "round", "ball", "circle"])

        candidates: List[Candidate] = []
        seen_boxes = []

        for cnt in all_contours:
            area = cv2.contourArea(cnt)
            area_ratio = area / total_pixels

            # Filter noise and overwhelming backgrounds
            if area_ratio < 0.008 or area_ratio > 0.85:
                continue

            x, y, w, h = cv2.boundingRect(cnt)
            aspect_ratio = float(w) / max(1.0, float(h))

            # Suppress duplicate/overlapping boxes
            box_tuple = (x // 20, y // 20, w // 20, h // 20)
            if box_tuple in seen_boxes:
                continue
            seen_boxes.append(box_tuple)

            # Score based on shape compactness and aspect ratio
            if is_spherical:
                # Target is spherical; aspect ratio close to 1.0 is favored
                shape_score = 1.0 - min(0.6, abs(aspect_ratio - 1.0))
            else:
                shape_score = 0.8

            # Sample color consistency inside the bounding box
            roi_hsv = hsv_img[y:y+h, x:x+w]
            color_score = 0.7
            if matched_ranges and roi_hsv.size > 0:
                roi_mask = None
                for lower, upper in matched_ranges:
                    rm = cv2.inRange(roi_hsv, lower, upper)
                    roi_mask = rm if roi_mask is None else cv2.bitwise_or(roi_mask, rm)
                if roi_mask is not None:
                    density = float(cv2.countNonZero(roi_mask)) / max(1.0, float(w * h))
                    color_score = min(1.0, 0.4 + density * 0.6)

            confidence = round(float(np.clip(0.55 * shape_score + 0.35 * color_score + 0.1 * min(1.0, area_ratio * 5), 0.50, 0.96)), 2)

            box = BoundingBox(
                ymin=round(float(y) / frame_h, 4),
                xmin=round(float(x) / frame_w, 4),
                ymax=round(float(y + h) / frame_h, 4),
                xmax=round(float(x + w) / frame_w, 4)
            )

            crop_b64 = cls._crop_and_encode(image_bgr, box, frame_w, frame_h)

            candidate = Candidate(
                id=str(uuid.uuid4())[:8],
                bounding_box=box,
                confidence=confidence,
                area_ratio=round(area_ratio, 4),
                aspect_ratio=round(aspect_ratio, 2),
                crop_base64=crop_b64,
                reason=(
                    f"Candidate matches {target_profile.primary_color} "
                    f"{'spherical' if is_spherical else 'target'} form factor."
                )
            )
            candidates.append(candidate)

        # Sort candidates by confidence
        candidates.sort(key=lambda c: c.confidence, reverse=True)
        top_candidates = candidates[:3]

        if top_candidates and top_candidates[0].confidence >= 0.60:
            best = top_candidates[0]
            return CandidateDetectResponse(
                candidate_found=True,
                state=SearchState.CANDIDATE_DETECTED,
                candidates=top_candidates,
                best_candidate=best,
                message=(
                    f"Candidate detected at [{int(best.bounding_box.xmin*100)}%, {int(best.bounding_box.ymin*100)}%] "
                    f"with {int(best.confidence*100)}% match potential."
                )
            )
        else:
            return CandidateDetectResponse(
                candidate_found=False,
                state=SearchState.SEARCHING,
                candidates=[],
                best_candidate=None,
                message="No target candidates detected in current camera frame. Continue scanning."
            )

candidate_detector_service = CandidateDetectorService()
