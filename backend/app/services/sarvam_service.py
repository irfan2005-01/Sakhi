import base64
import logging

import httpx

from app.config import settings

logger = logging.getLogger("sakhi.sarvam")

SARVAM_API_BASE = "https://api.sarvam.ai"
STT_MODEL = "saaras:v4"
TTS_MODEL = "bulbul:v3"
SUPPORTED_LANGUAGES = {
    "en-IN": "shubh",
    "hi-IN": "priya",
    "bn-IN": "roopa",
    "gu-IN": "priya",
    "kn-IN": "ishita",
    "ml-IN": "pooja",
    "mr-IN": "priya",
    "od-IN": "ritu",
    "pa-IN": "suhani",
    "ta-IN": "ishita",
    "te-IN": "neha",
}


class SarvamUnavailable(Exception):
    def __init__(self, message: str, status_code: int = 502):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


class SarvamService:
    @property
    def is_configured(self) -> bool:
        return bool(settings.SARVAM_API_KEY and settings.SARVAM_API_KEY.strip())

    def _headers(self) -> dict[str, str]:
        if not self.is_configured:
            raise SarvamUnavailable("Voice features are unavailable because Sarvam is not configured.", 503)
        return {"api-subscription-key": settings.SARVAM_API_KEY.strip()}

    @staticmethod
    def _raise_for_provider_error(response: httpx.Response) -> None:
        if response.is_success:
            return
        status = response.status_code
        if status in (401, 403):
            message, public_status = "Sarvam rejected the configured credentials.", 503
        elif status == 429:
            message, public_status = "Sarvam voice capacity is temporarily unavailable.", 503
        elif status >= 500:
            message, public_status = "Sarvam voice service is temporarily unavailable.", 502
        else:
            message, public_status = "Sarvam could not process this audio or speech request.", 422
        logger.warning("Sarvam request failed with HTTP status %s.", status)
        raise SarvamUnavailable(message, public_status)

    async def transcribe(self, audio: bytes, filename: str, content_type: str) -> tuple[str, str | None]:
        headers = self._headers()
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(45.0, connect=10.0)) as client:
                response = await client.post(
                    f"{SARVAM_API_BASE}/speech-to-text",
                    headers=headers,
                    data={"model": STT_MODEL, "mode": "transcribe"},
                    files={"file": (filename, audio, content_type)},
                )
        except httpx.TimeoutException:
            raise SarvamUnavailable("Sarvam speech recognition timed out. Please retry.", 504) from None
        except httpx.RequestError:
            raise SarvamUnavailable("Sarvam speech recognition could not be reached.", 502) from None

        self._raise_for_provider_error(response)
        try:
            payload = response.json()
            transcript = payload.get("transcript", "").strip()
            detected_language = payload.get("language_code")
        except (ValueError, AttributeError):
            raise SarvamUnavailable("Sarvam returned an invalid transcription response.", 502) from None
        if not transcript:
            raise SarvamUnavailable("No speech was recognized. Please record a clearer utterance.", 422)
        if detected_language and detected_language not in SUPPORTED_LANGUAGES:
            raise SarvamUnavailable("The detected language is not supported for Sakhi voice responses.", 422)
        return transcript, detected_language

    async def synthesize(self, text: str, language_code: str) -> dict[str, str]:
        if language_code not in SUPPORTED_LANGUAGES:
            raise SarvamUnavailable("Unsupported language. Choose a supported Indian language code.", 422)
        headers = self._headers()
        body = {
            "text": text,
            "model": TTS_MODEL,
            "language_code": language_code,
            "speaker": SUPPORTED_LANGUAGES[language_code],
            "output_audio_codec": "wav",
            "speech_sample_rate": 24000,
        }
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(45.0, connect=10.0)) as client:
                response = await client.post(
                    f"{SARVAM_API_BASE}/text-to-speech",
                    headers=headers,
                    json=body,
                )
        except httpx.TimeoutException:
            raise SarvamUnavailable("Sarvam speech synthesis timed out. Please retry.", 504) from None
        except httpx.RequestError:
            raise SarvamUnavailable("Sarvam speech synthesis could not be reached.", 502) from None

        self._raise_for_provider_error(response)
        try:
            audio = "".join(response.json().get("audios", []))
            base64.b64decode(audio, validate=True)
        except (ValueError, TypeError, AttributeError):
            raise SarvamUnavailable("Sarvam returned an invalid audio response.", 502) from None
        if not audio:
            raise SarvamUnavailable("Sarvam returned no speech audio.", 502)
        return {"audio_base64": audio, "content_type": "audio/wav", "language_code": language_code, "model": TTS_MODEL}


sarvam_service = SarvamService()
