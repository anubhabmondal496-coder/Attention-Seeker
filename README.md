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

---

## Phase 5: Directional Guidance Decision Engine

### Endpoint: `POST /search/decision`
- Evaluates spatial centering (`cx`, `cy`), candidate distance (`area_ratio`), device tilt/pitch, and search sweep state.
- Generates concise, directional instructions to help the user locate and frame the object:
  - `"Move camera slightly left."`
  - `"Move camera slightly right."`
  - `"Look lower."`
  - `"Move closer."`
  - `"Hold the camera steady."`
  - `"Object found."`

```powershell
curl.exe -X POST "http://127.0.0.1:8000/search/decision" `
  -H "Content-Type: application/json" `
  -d "{\"current_state\":\"CANDIDATE_DETECTED\",\"candidate\":{\"id\":\"c1\",\"bounding_box\":{\"ymin\":0.4,\"xmin\":0.1,\"ymax\":0.6,\"xmax\":0.3},\"confidence\":0.8,\"area_ratio\":0.03,\"aspect_ratio\":1.0,\"reason\":\"test\"},\"attempts_count\":1}"
```

---

## Phase 6: Search State Machine & Lifecycle Management

### State Graph
- Explicit, enforced transitions across all 8 states:
  `IDLE` $\rightarrow$ `TARGET_READY` $\rightarrow$ `SEARCHING` $\rightleftharpoons$ `CANDIDATE_DETECTED` $\rightleftharpoons$ `VERIFYING` $\rightleftharpoons$ `GUIDING` $\rightarrow$ `FOUND` $\rightarrow$ `SEARCH_COMPLETE`.
- Transition safeguards prevent illegal state jumps (returns HTTP 400 with diagnostic reason).

### Session Endpoints
- `POST /session/start`: Initializes a session with target profile and enters `SEARCHING`.
- `GET /session/{session_id}`: Retrieves duration, attempt counts, evaluated candidates, and transition history.
- `POST /session/transition`: Formally updates state with reason validation.
- `POST /session/complete`: Terminates session with `SEARCH_COMPLETE`.

```powershell
# 1. Start Session
curl.exe -X POST "http://127.0.0.1:8000/session/start" `
  -H "Content-Type: application/json" `
  -d "{\"session_id\":\"session_demo_1\",\"target_profile\":{\"object_type\":\"cricket ball\",\"primary_color\":\"white\",\"shape\":\"spherical\",\"material\":\"leather\",\"distinctive_features\":[\"green seam\"],\"confidence\":0.95}}"

# 2. Transition State
curl.exe -X POST "http://127.0.0.1:8000/session/transition" `
  -H "Content-Type: application/json" `
  -d "{\"session_id\":\"session_demo_1\",\"to_state\":\"CANDIDATE_DETECTED\",\"reason\":\"Contour identified in frame\"}"

# 3. Complete Session
curl.exe -X POST "http://127.0.0.1:8000/session/complete" `
  -H "Content-Type: application/json" `
  -d "{\"session_id\":\"session_demo_1\",\"reason\":\"Object located and confirmed\"}"
```

---

## Phase 7: Search Memory & Environmental Spatial Tracking

### Capabilities
- **Spatial Sector Discretization**: Bins device pitch and roll into environmental sectors (`LEVEL_CENTER`, `LEVEL_LEFT`, `LEVEL_RIGHT`, `DOWN_CENTER`, `UP_CENTER`).
- **Rejected Candidate History**: Records rejected objects so the agent does not continuously re-evaluate false positives.
- **Unexplored Direction Planner**: Informs the guidance decision engine which sectors have not yet been swept.

### Memory Endpoints
- `POST /memory/observation`: Records camera viewport orientation during frame sampling.
- `POST /memory/rejection`: Logs candidate rejection reason and bounding box.
- `GET /memory/{session_id}/summary`: Returns coverage metrics, visit counts, and suggested unexplored directions.

```powershell
# Record device orientation observation
curl.exe -X POST "http://127.0.0.1:8000/memory/observation" `
  -H "Content-Type: application/json" `
  -d "{\"session_id\":\"session_demo_1\",\"pitch\":-45.0,\"roll\":30.0,\"guidance\":\"Sweep right\"}"

# Query explored sectors & unexplored planning suggestions
curl.exe "http://127.0.0.1:8000/memory/session_demo_1/summary"
```

---

## Phase 8: Real-Time Voice Guidance (TTS)

- Spoken voice feedback via `flutter_tts` for hands-free searching.
- Speaks concise user instructions in real time (*"Move camera slightly left."*, *"Look lower."*, *"Move closer."*, *"Object found!"*).
- Built-in deduplication and 1.5s rate-limiting to prevent repetitive audio spam.
- In-HUD volume toggle button allowing the user to mute or unmute audio guidance at any time.

---

## Phase 9: End-to-End Search Agentic Loop

1. **Target Registration**: User submits a reference photo + description $\rightarrow$ Gemma extracts structured `TargetProfile`.
2. **Search Activation**: Camera initiates session in `SEARCHING` state.
3. **Sampling & Fast CV**: Periodic 1800ms frames processed by lightweight HSV + edge saliency in 15–25ms.
4. **Spatial Planning**: Sensor pitch/roll recorded into search memory, guiding user towards unsearched areas.
5. **Centering & Zoom Guidance**: Direction engine advises user to center candidate and move closer.
6. **Gemma Verification**: Centered candidate crop sent to Gemma multimodal model for forensic verification.
7. **Confirmation & Resolution**:
   - `FOUND`: App alerts user via visual HUD + voice speech (*"Object found!"*) and transitions to `FoundScreen`.
   - `NOT_A_MATCH`: Candidate logged to rejection memory and sweep resumes.
