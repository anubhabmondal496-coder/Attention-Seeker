import os
from pathlib import Path
from dotenv import load_dotenv

# Locate backend root and load backend/.env
BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

class Settings:
    HF_TOKEN: str = os.getenv("HF_TOKEN", "")
    GEMMA_BACKEND: str = os.getenv("GEMMA_BACKEND", "hf_router")
    GEMMA_ROUTER_MODEL: str = os.getenv("GEMMA_ROUTER_MODEL", "google/gemma-3-4b-it")
    GEMMA_MODEL_ID: str = os.getenv("GEMMA_MODEL_ID", "google/gemma-4-E4B-it")
    HF_ENDPOINT_URL: str = os.getenv("HF_ENDPOINT_URL", "")
    OLLAMA_BASE_URL: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434/v1")
    HOST: str = os.getenv("HOST", "127.0.0.1")
    PORT: int = int(os.getenv("PORT", "8000"))

settings = Settings()
