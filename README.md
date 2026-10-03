# Attention Seeker — Find what you lost.

> An agentic multimodal visual search assistant that helps users locate specific lost physical objects using a reference image, descriptive context, live camera orientation, lightweight candidate generation, and Gemma multimodal reasoning.

---

## Architecture Overview

```
Attention Seeker/
│
├── backend/
│   ├── app/
│   │   ├── config.py           # Environment & inference backend configuration
│   │   └── state.py            # SearchState state-machine definitions
│   ├── models/
│   │   └── target.py           # TargetProfile & TargetAnalyzeResponse Pydantic schemas
│   ├── services/
│   │   ├── gemma_service.py    # Isolated Gemma multimodal inference layer
│   │   └── target_analyzer.py  # Reference image + description -> TargetProfile extractor
│   ├── routes/
│   │   └── target.py           # POST /target/analyze endpoint
│   ├── main.py                 # FastAPI application entrypoint & health checks
│   ├── requirements.txt        # Backend dependencies
│   └── .env                    # Secrets & provider configuration (gitignored)
│
├── frontend/                   # Flutter mobile client (Phases 2+)
├── .gitignore                  # Security & build exclusions
└── README.md
```

---

## Search State Machine

1. `IDLE` (Initial state)
2. `TARGET_READY` (Reference image + description analyzed into `TargetProfile`)
3. `SEARCHING` (Camera active, sampling frames)
4. `CANDIDATE_DETECTED` (Visual similarity layer flags potential target)
5. `VERIFYING` (Gemma multimodal reasoning validates cropped candidate)
6. `GUIDING` (Directional user instructions emitted)
7. `FOUND` (Target verified with high confidence)
8. `SEARCH_COMPLETE` (Search terminated / confirmed)

---

## Inference Layer Isolation

The backend inference layer is isolated in [backend/services/gemma_service.py](file:///c:/Users/ANUBHAB/Desktop/Attention%20Seeker/backend/services/gemma_service.py).
Supported backends:
- `hf_router`: Serverless Hugging Face Inference router using a supported multimodal Gemma checkpoint (e.g. `google/gemma-3-4b-it` or `google/gemma-4-26B-A4B-it`).
- `transformers`: Direct local execution of `google/gemma-4-E4B-it` via Hugging Face `transformers` on GPU/CPU.
- `dedicated_endpoint`: Dedicated private Hugging Face Inference Endpoint.
- `ollama`: Local edge serving via Ollama (`http://localhost:11434/v1`).

---

## Phase 1: Target Profile Extraction

### Run the Backend

```powershell
# From the repository root:
.\ai_env\Scripts\python.exe backend\main.py
```

### Test Target Analysis

```powershell
# In PowerShell:
curl.exe -X POST "http://127.0.0.1:8000/target/analyze" `
  -F "image=@reference_image.webp;type=image/webp" `
  -F "description=White SG tournament cricket ball"
```

---

## Phase 3: Fast Candidate Generation

### Endpoint: `POST /candidate/detect`
- Evaluates sampled camera frames in ~15-25ms without overloading network bandwidth or GPU.
- Combines HSV color segmentation, edge/saliency contouring, and shape aspect-ratio scoring against `TargetProfile`.
- Automatically produces normalized candidate bounding boxes (`ymin, xmin, ymax, xmax`) and cropped JPEG base64 regions for Gemma verification in Phase 4.

```powershell
curl.exe -X POST "http://127.0.0.1:8000/candidate/detect" `
  -F "frame=@reference_image.webp;type=image/jpeg" `
  -F "target_profile={\"object_type\":\"cricket ball\",\"primary_color\":\"white\",\"shape\":\"spherical\",\"material\":\"leather\",\"distinctive_features\":[],\"confidence\":0.9}"
```

---

## Phase 4: Gemma Multimodal Candidate Verification

### Endpoint: `POST /candidate/verify`
- Performs deep forensic visual comparison between the candidate crop and the `TargetProfile`.
- Compares specific identifying markings, logo graphics, seam stitching, material texture, and colors.
- Classifies candidates into: `FOUND`, `LIKELY_MATCH`, `POSSIBLE_MATCH`, or `NOT_A_MATCH`.
- Generates concise actionable guidance instructions (`"Move closer."`, `"Object found."`, `"Not a match. Keep scanning."`).

```powershell
curl.exe -X POST "http://127.0.0.1:8000/candidate/verify" `
  -F "candidate_crop=@reference_image.webp;type=image/jpeg" `
  -F "target_profile={\"object_type\":\"cricket ball\",\"primary_color\":\"white\",\"shape\":\"spherical\",\"material\":\"leather\",\"distinctive_features\":[\"green seam stitching\",\"gold SG emblem\"],\"confidence\":0.95}"
```
