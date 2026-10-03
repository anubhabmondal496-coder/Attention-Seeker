import sys
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.state import SearchState
from routes.target import router as target_router
from routes.candidate import router as candidate_router
from routes.search import router as search_router
from routes.session import router as session_router
from routes.memory import router as memory_router

app = FastAPI(
    title="Attention Seeker Visual Search API",
    version="0.1.0",
    description="Agentic multimodal visual search assistant backend powered by Gemma."
)

# Enable CORS for Flutter mobile/web clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routes
app.include_router(target_router)
app.include_router(candidate_router)
app.include_router(search_router)
app.include_router(session_router)
app.include_router(memory_router)

@app.get("/")
def root():
    """Root landing endpoint with interactive documentation and status links."""
    return {
        "service": "Attention Seeker Visual Search API",
        "tagline": "Find what you lost.",
        "status": "online",
        "docs_url": "/docs",
        "health_check_url": "/health"
    }

@app.get("/health")
def health_check():
    """Health check reporting system status and inference engine configuration."""
    return {
        "status": "healthy",
        "service": "Attention Seeker Backend",
        "search_state": SearchState.IDLE,
        "inference_backend": settings.GEMMA_BACKEND,
        "gemma_model": settings.GEMMA_ROUTER_MODEL if settings.GEMMA_BACKEND == "hf_router" else settings.GEMMA_MODEL_ID
    }

if __name__ == "__main__":
    import uvicorn
    print(f"Starting SEEK Backend on {settings.HOST}:{settings.PORT}...")
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=True)
