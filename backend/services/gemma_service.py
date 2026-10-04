import io
import base64
from typing import Optional
from PIL import Image
from huggingface_hub import InferenceClient
from app.config import settings

class GemmaInferenceService:
    """
    Isolated multimodal inference service for Gemma.
    Supports serverless Hugging Face router, local transformers, or dedicated endpoints.
    """

    def __init__(self):
        self.backend = settings.GEMMA_BACKEND
        self.router_model = settings.GEMMA_ROUTER_MODEL
        self.canonical_model = settings.GEMMA_MODEL_ID
        self.token = settings.HF_TOKEN

        # Initialize InferenceClient for Hugging Face router mode
        if self.backend == "hf_router":
            self.client = InferenceClient(api_key=self.token)
        else:
            self.client = None

    def _prepare_image_b64(self, image_bytes: bytes) -> str:
        """Converts raw image bytes to a clean JPEG base64 data URI."""
        with Image.open(io.BytesIO(image_bytes)) as img:
            rgb_img = img.convert("RGB")
            buffer = io.BytesIO()
            rgb_img.save(buffer, format="JPEG", quality=90)
            b64_str = base64.b64encode(buffer.getvalue()).decode("utf-8")
            return f"data:image/jpeg;base64,{b64_str}"

    def generate_multimodal(self, image_bytes: bytes, prompt: str, system_prompt: Optional[str] = None) -> str:
        """
        Executes multimodal inference comparing an image and prompt.
        """
        if self.backend == "hf_router":
            return self._call_hf_router(image_bytes, prompt, system_prompt)
        elif self.backend == "transformers":
            return self._call_local_transformers(image_bytes, prompt, system_prompt)
        elif self.backend == "dedicated_endpoint":
            return self._call_dedicated_endpoint(image_bytes, prompt, system_prompt)
        elif self.backend == "ollama":
            return self._call_ollama(image_bytes, prompt, system_prompt)
        else:
            raise ValueError(f"Unsupported GEMMA_BACKEND: '{self.backend}'")

    def generate_text(self, prompt: str, system_prompt: Optional[str] = None) -> str:
        """Executes text-only inference for Gemma (e.g., voice-dictated item profile without image)."""
        if self.backend == "hf_router":
            messages = []
            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})
            messages.append({"role": "user", "content": prompt})
            response = self.client.chat.completions.create(
                model=self.router_model,
                messages=messages,
                max_tokens=800,
                temperature=0.2
            )
            return response.choices[0].message.content
        elif self.backend == "ollama":
            import httpx
            payload = {
                "model": "gemma4:e4b",
                "messages": [{"role": "user", "content": prompt}],
                "stream": False
            }
            res = httpx.post(f"{settings.OLLAMA_BASE_URL}/chat", json=payload, timeout=60.0)
            res.raise_for_status()
            return res.json()["message"]["content"]
        else:
            # Fallback to multimodal passing empty transparent 1x1 image or router
            transparent_pixel = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\rIDATx\x9cc`\x00\x00\x00\x02\x00\x01H\xaf\xa4q\x00\x00\x00\x00IEND\xaeB`\x82'
            return self.generate_multimodal(transparent_pixel, prompt, system_prompt)

    def _call_hf_router(self, image_bytes: bytes, prompt: str, system_prompt: Optional[str] = None) -> str:
        data_uri = self._prepare_image_b64(image_bytes)

        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})

        messages.append({
            "role": "user",
            "content": [
                {
                    "type": "image_url",
                    "image_url": {"url": data_uri}
                },
                {
                    "type": "text",
                    "text": prompt
                }
            ]
        })

        try:
            response = self.client.chat.completions.create(
                model=self.router_model,
                messages=messages,
                max_tokens=800,
                temperature=0.2
            )
            return response.choices[0].message.content
        except Exception as e:
            raise RuntimeError(f"Hugging Face Router inference failed ({self.router_model}): {e}") from e

    def _call_local_transformers(self, image_bytes: bytes, prompt: str, system_prompt: Optional[str] = None) -> str:
        """Local execution fallback using transformers AutoModelForMultimodalLM."""
        try:
            import torch
            from transformers import AutoProcessor, AutoModelForMultimodalLM
        except ImportError as exc:
            raise RuntimeError(
                "Local transformers backend selected but transformers/torch are not installed. "
                "Install them or switch GEMMA_BACKEND='hf_router' in .env."
            ) from exc

        model_id = self.canonical_model
        processor = AutoProcessor.from_pretrained(model_id, token=self.token)
        model = AutoModelForMultimodalLM.from_pretrained(
            model_id,
            torch_dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32,
            device_map="auto" if torch.cuda.is_available() else None,
            token=self.token
        )

        pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "image", "image": pil_image},
                    {"type": "text", "text": prompt}
                ]
            }
        ]

        inputs = processor.apply_chat_template(
            messages,
            tokenize=True,
            return_dict=True,
            return_tensors="pt",
            add_generation_prompt=True,
        ).to(model.device)

        with torch.no_grad():
            outputs = model.generate(**inputs, max_new_tokens=800)
            input_len = inputs["input_ids"].shape[-1]
            return processor.decode(outputs[0][input_len:], skip_special_tokens=True)

    def _call_dedicated_endpoint(self, image_bytes: bytes, prompt: str, system_prompt: Optional[str] = None) -> str:
        client = InferenceClient(base_url=settings.HF_ENDPOINT_URL, api_key=self.token)
        data_uri = self._prepare_image_b64(image_bytes)
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "image_url", "image_url": {"url": data_uri}},
                    {"type": "text", "text": prompt}
                ]
            }
        ]
        response = client.chat.completions.create(messages=messages, max_tokens=800)
        return response.choices[0].message.content

    def _call_ollama(self, image_bytes: bytes, prompt: str, system_prompt: Optional[str] = None) -> str:
        import httpx
        b64_raw = base64.b64encode(image_bytes).decode("utf-8")
        payload = {
            "model": "gemma4:e4b",
            "messages": [
                {
                    "role": "user",
                    "content": prompt,
                    "images": [b64_raw]
                }
            ],
            "stream": False
        }
        res = httpx.post(f"{settings.OLLAMA_BASE_URL}/chat", json=payload, timeout=60.0)
        res.raise_for_status()
        return res.json()["message"]["content"]

# Singleton instance
gemma_service = GemmaInferenceService()
