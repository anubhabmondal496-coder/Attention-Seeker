import io
import math
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
    "brown": [
        (np.array([8, 60, 20]), np.array([24, 255, 160]))
    ],
    "dark brown": [
        (np.array([5, 50, 15]), np.array([20, 255, 90]))
    ],
    "tan": [
        (np.array([14, 25, 80]), np.array([30, 130, 225]))
    ],
    "cardboard": [
        (np.array([10, 35, 60]), np.array([26, 170, 210]))
    ],
    "wood": [
        (np.array([10, 40, 40]), np.array([25, 200, 190]))
    ],
    "gray": [
        (np.array([0, 0, 65]), np.array([180, 40, 175]))
    ],
    "silver": [
        (np.array([0, 0, 120]), np.array([180, 35, 220]))
    ],
    "purple": [
        (np.array([135, 50, 40]), np.array([160, 255, 255]))
    ],
    "pink": [
        (np.array([160, 40, 100]), np.array([175, 255, 255]))
    ],
    "cyan": [
        (np.array([80, 60, 70]), np.array([95, 255, 255]))
    ]
}

class CandidateDetectorService:
    """
    High-performance visual candidate generator (15-30ms CPU).
    Optimized for:
    - Bushy, foliage, outdoor grass terrain and congested, cluttered indoor scenes.
    - Progressive up to 4x zoom cropping for small objects (matchboxes, keys, cards).
    - Bilateral edge filtering to suppress organic foliage texture while capturing
      man-made geometric straight edges and colors.
    """

    @classmethod
    def _crop_and_encode_with_zoom(
        cls,
        image_bgr: np.ndarray,
        box: BoundingBox,
        frame_w: int,
        frame_h: int,
        area_ratio: float
    ) -> Tuple[str, float]:
        """
        Extracts candidate crop with progressive magnification up to 4x.
        Returns (base64_encoded_jpeg, zoom_level).
        """
        # Determine progressive zoom: small objects (< 0.12 area) are magnified up to 4.0x
        if area_ratio < 0.005:
            zoom_level = 4.0
        elif area_ratio < 0.015:
            zoom_level = 3.5
        elif area_ratio < 0.04:
            zoom_level = 2.5
        elif area_ratio < 0.10:
            zoom_level = 1.8
        else:
            zoom_level = 1.0

        # Margin expansion around candidate
        pad_factor = 0.12 if zoom_level > 1.5 else 0.08
        pad_x = int(box.width * frame_w * pad_factor)
        pad_y = int(box.height * frame_h * pad_factor)

        x1 = max(0, int(box.xmin * frame_w) - pad_x)
        y1 = max(0, int(box.ymin * frame_h) - pad_y)
        x2 = min(frame_w, int(box.xmax * frame_w) + pad_x)
        y2 = min(frame_h, int(box.ymax * frame_h) + pad_y)

        crop = image_bgr[y1:y2, x1:x2]
        if crop.size == 0:
            crop = image_bgr

        # Ensure high resolution for multimodal VLM: upscale small crops to at least 280x280
        ch, cw = crop.shape[:2]
        min_dim = 280
        if cw < min_dim or ch < min_dim:
            scale = max(min_dim / max(1, cw), min_dim / max(1, ch))
            new_w = min(800, int(cw * scale))
            new_h = min(800, int(ch * scale))
            crop = cv2.resize(crop, (new_w, new_h), interpolation=cv2.INTER_CUBIC)

        _, buf = cv2.imencode(".jpg", crop, [cv2.IMWRITE_JPEG_QUALITY, 90])
        b64_str = base64.b64encode(buf.tobytes()).decode("utf-8")
        return b64_str, zoom_level

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

        # Determine if target is a known small object
        target_type_lower = target_profile.object_type.lower()
        is_small_object = any(
            w in target_type_lower or w in (target_profile.user_description or "").lower()
            for w in ["match", "box", "key", "coin", "lighter", "pen", "card", "ring", "earbud", "usb", "remote"]
        )

        # 1. Congested & Bushy Clutter Filtering
        # Bilateral filter preserves sharp geometric object edges while smoothing leaf veins/grass
        smoothed = cv2.bilateralFilter(gray, 9, 65, 65)
        edges = cv2.Canny(smoothed, 35, 115)

        # Measure scene clutter density
        edge_density = float(cv2.countNonZero(edges)) / float(total_pixels)
        is_congested_or_bushy = edge_density > 0.055

        # In bushy scenes, suppress thin organic grass slivers
        kernel_size = (5, 5) if is_congested_or_bushy else (7, 7)
        kernel_edge = cv2.getStructuringElement(cv2.MORPH_RECT, kernel_size)
        closed_edges = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel_edge, iterations=2)
        saliency_contours, _ = cv2.findContours(closed_edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        # 2. Color Contours with Expanded Palette Support
        color_contours = []
        lower_name = target_profile.primary_color.lower().strip()
        matched_ranges = None
        for key in HSV_COLOR_RANGES:
            if key in lower_name:
                matched_ranges = HSV_COLOR_RANGES[key]
                break

        # Check secondary color if primary didn't match
        if not matched_ranges and target_profile.secondary_color:
            sec_name = target_profile.secondary_color.lower().strip()
            for key in HSV_COLOR_RANGES:
                if key in sec_name:
                    matched_ranges = HSV_COLOR_RANGES[key]
                    break

        if matched_ranges:
            color_mask = None
            for lower, upper in matched_ranges:
                m = cv2.inRange(hsv_img, lower, upper)
                color_mask = m if color_mask is None else cv2.bitwise_or(color_mask, m)

            # Avoid full-screen background saturation
            if color_mask is not None and (0.005 * total_pixels) < cv2.countNonZero(color_mask) < (0.80 * total_pixels):
                k_col = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
                color_mask = cv2.morphologyEx(color_mask, cv2.MORPH_OPEN, k_col, iterations=1)
                color_mask = cv2.morphologyEx(color_mask, cv2.MORPH_CLOSE, k_col, iterations=2)
                cnts, _ = cv2.findContours(color_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
                color_contours.extend(cnts)

        # Combine contour sets
        all_contours = list(saliency_contours) + list(color_contours)

        is_spherical = any(term in target_profile.shape.lower() for term in ["sphere", "spherical", "round", "ball", "circle"])
        is_rectangular = any(term in target_profile.shape.lower() for term in ["rect", "box", "square", "flat", "card", "pack"])

        candidates: List[Candidate] = []
        seen_boxes = []

        # Min area ratio: 0.002 (0.2%) for small objects or congested scenes, 0.005 otherwise
        min_area_thresh = 0.002 if (is_small_object or is_congested_or_bushy) else 0.005

        for cnt in all_contours:
            area = cv2.contourArea(cnt)
            area_ratio = area / total_pixels

            # Filter noise and overwhelming backgrounds
            if area_ratio < min_area_thresh or area_ratio > 0.85:
                continue

            x, y, w, h = cv2.boundingRect(cnt)
            aspect_ratio = float(w) / max(1.0, float(h))

            # Suppress extreme needle-like slivers typical of grass blades or wires
            if (aspect_ratio > 7.0 or aspect_ratio < 0.14) and (w < 12 or h < 12):
                continue

            # Suppress duplicate/overlapping candidate boxes
            box_tuple = (x // 18, y // 18, w // 18, h // 18)
            if box_tuple in seen_boxes:
                continue
            seen_boxes.append(box_tuple)

            # Geometric shape scoring
            shape_score = 0.75
            if is_spherical:
                shape_score = 1.0 - min(0.6, abs(aspect_ratio - 1.0))
            elif is_rectangular:
                # Polygons with straight rectangular edges favored
                peri = cv2.arcLength(cnt, True)
                approx = cv2.approxPolyDP(cnt, 0.04 * peri, True)
                if len(approx) in [4, 5, 6]:
                    shape_score = 0.92
                else:
                    shape_score = 0.80

            # Color consistency inside the candidate bounding box
            roi_hsv = hsv_img[y:y+h, x:x+w]
            color_score = 0.70
            if matched_ranges and roi_hsv.size > 0:
                roi_mask = None
                for lower, upper in matched_ranges:
                    rm = cv2.inRange(roi_hsv, lower, upper)
                    roi_mask = rm if roi_mask is None else cv2.bitwise_or(roi_mask, rm)
                if roi_mask is not None:
                    density = float(cv2.countNonZero(roi_mask)) / max(1.0, float(w * h))
                    color_score = min(1.0, 0.45 + density * 0.55)

            # Bonus for man-made geometric contrast in bushy/congested scenes
            bushy_bonus = 0.05 if (is_congested_or_bushy and shape_score > 0.85) else 0.0

            confidence = round(
                float(np.clip(
                    0.50 * shape_score +
                    0.35 * color_score +
                    0.10 * min(1.0, area_ratio * 6) +
                    bushy_bonus,
                    0.52,
                    0.97
                )),
                2
            )

            box = BoundingBox(
                ymin=round(float(y) / frame_h, 4),
                xmin=round(float(x) / frame_w, 4),
                ymax=round(float(y + h) / frame_h, 4),
                xmax=round(float(x + w) / frame_w, 4)
            )

            # Progressive up to 4x zoom cropping
            crop_b64, zoom_level = cls._crop_and_encode_with_zoom(
                image_bgr,
                box,
                frame_w,
                frame_h,
                area_ratio
            )

            env_desc = "congested/bushy area" if is_congested_or_bushy else "scene"
            reason = (
                f"Candidate matches {target_profile.primary_color} "
                f"{'rectangular' if is_rectangular else ('spherical' if is_spherical else 'target')} "
                f"profile in {env_desc} (zoom: {zoom_level:.1f}x)."
            )

            candidate = Candidate(
                id=str(uuid.uuid4())[:8],
                bounding_box=box,
                confidence=confidence,
                area_ratio=round(area_ratio, 4),
                aspect_ratio=round(aspect_ratio, 2),
                crop_base64=crop_b64,
                zoom_level=zoom_level,
                reason=reason
            )
            candidates.append(candidate)

        # Sort candidates by confidence
        candidates.sort(key=lambda c: c.confidence, reverse=True)
        top_candidates = candidates[:3]

        # In congested/bushy scenes or for small objects, threshold 0.58 allows subtle targets
        thresh = 0.58 if (is_small_object or is_congested_or_bushy) else 0.60
        if top_candidates and top_candidates[0].confidence >= thresh:
            best = top_candidates[0]
            zoom_str = f" with {best.zoom_level:.1f}x crop" if best.zoom_level > 1.0 else ""
            return CandidateDetectResponse(
                candidate_found=True,
                state=SearchState.CANDIDATE_DETECTED,
                candidates=top_candidates,
                best_candidate=best,
                message=(
                    f"Candidate detected at [{int(best.bounding_box.xmin*100)}%, {int(best.bounding_box.ymin*100)}%]{zoom_str} "
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
