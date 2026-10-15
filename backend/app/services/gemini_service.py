import json
import logging
import re
from typing import Optional, Dict, Any
from app.config import settings

logger = logging.getLogger("sakhi.gemini")


class GeminiService:
    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY
        self.model_name = settings.GEMINI_MODEL or "gemini-3.8-flash"
        self.client = None
        self._init_client()

    def _init_client(self):
        if self.api_key and self.api_key.strip():
            try:
                from google import genai
                self.client = genai.Client(api_key=self.api_key.strip())
                logger.info("Initialized Google Gen AI Client with model %s", self.model_name)
            except Exception as e:
                logger.warning("Could not initialize Google Gen AI Client (%s).", type(e).__name__)
                self.client = None
        else:
            logger.info("No GEMINI_API_KEY provided; operating in deterministic fallback / demo mode.")
            self.client = None

    @property
    def is_live(self) -> bool:
        return self.client is not None

    async def generate_json(self, prompt: str, system_instruction: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """Call Gemini API and return parsed JSON. Returns None if live call fails or client unavailable."""
        if not self.client:
            return None

        try:
            from google.genai import types
            config = types.GenerateContentConfig(
                response_mime_type="application/json",
            )
            if system_instruction:
                config.system_instruction = system_instruction

            # Run in threadpool if genai synchronous client
            import asyncio
            loop = asyncio.get_running_loop()
            response = await loop.run_in_executor(
                None,
                lambda: self.client.models.generate_content(
                    model=self.model_name,
                    contents=prompt,
                    config=config,
                )
            )

            if response and response.text:
                try:
                    return json.loads(response.text)
                except (TypeError, json.JSONDecodeError) as exc:
                    logger.warning("Gemini returned invalid JSON (%s).", type(exc).__name__)
                    return None
            logger.warning("Gemini returned no text content (model=%s).", self.model_name)
        except Exception as e:
            status = getattr(e, "status_code", None) or getattr(e, "code", None)
            message = str(getattr(e, "message", "") or "")
            message = message.replace(prompt, "[request content redacted]")
            if self.api_key:
                message = message.replace(self.api_key, "[credential redacted]")
            message = re.sub(r"AIza[0-9A-Za-z_-]{20,}", "[credential redacted]", message)
            message = re.sub(r"(?i)\bBearer\s+\S+", "Bearer [credential redacted]", message)
            message = " ".join(message.split())[:500]
            logger.error(
                "Gemini API request failed (exception=%s, status=%s, message=%s).",
                type(e).__name__, status or "unknown", message or "no provider message",
            )
            return None

        return None


gemini_service = GeminiService()

