# Sakhi backend

FastAPI service for the Sakhi Flutter Web app. The API can run without MongoDB or Gemini credentials: it uses an in-memory database and deterministic symptom extraction in that mode. In-memory records disappear when the server stops, and Gemini is not called without a key.

## Requirements

- Python 3.11 or newer
- Flutter stable with web support
- MongoDB (optional for persistent records)
- Google Gemini API key (optional for live extraction)
- Sarvam AI API key (optional for Indian-language voice input/output)

## Configure and run the API

From the `backend` directory in PowerShell:

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
uvicorn app.main:app --reload
```

The API is at `http://127.0.0.1:8000`; interactive documentation is at `/docs` and health status is at `/health`. If MongoDB is unavailable, startup falls back to in-memory storage. Set `MONGODB_URI` and `MONGODB_DATABASE` in `.env` to use a persistent MongoDB database.

Set `GEMINI_API_KEY` in the backend `.env` to enable Gemini. `GEMINI_MODEL` defaults to `gemini-2.5-flash`. Keep credentials in the backend environment and out of the Flutter app. `DEMO_MODE=true` seeds clearly tagged illustrative history; use the app's demo session to view it.

Set `SARVAM_API_KEY` in `backend/.env` to enable optional voice features. The backend uses Sarvam Saaras v4 transcription and Bulbul v3 speech synthesis; without this key, typed symptom analysis continues to work normally.

### Voice API contract for Flutter Web

- `POST /api/v1/voice/analyze` — `multipart/form-data` with `audio` (audio file, up to 12 MB), `session_id` (anonymous session identifier), and optional `language` (defaults to `auto`). Returns `{ "transcript": string, "detected_language": string|null, "analysis": <SymptomAnalysisResponse> }`. The transcript passes through the same symptom safety and Gemini flow as typed input. The route does not persist voice content; saving still requires the existing explicit-consent endpoint.
- `POST /api/v1/voice/synthesize` — JSON `{ "text": string, "language_code": string }`, where `text` is at most 2500 characters and `language_code` is one of `en-IN`, `hi-IN`, `bn-IN`, `gu-IN`, `kn-IN`, `ml-IN`, `mr-IN`, `od-IN`, `pa-IN`, `ta-IN`, `te-IN`. Returns `{ "audio_base64": string, "content_type": "audio/wav", "language_code": string, "model": "bulbul:v3" }`; Flutter decodes and plays the WAV bytes. Use the detected code or the user's selected language when requesting speech.
- Voice endpoints return a clear `503` when the Sarvam key is missing/unusable, `504` on provider timeout, and sanitized `4xx`/`5xx` errors otherwise. Keep the API key exclusively in the backend environment.
- Flutter integration remains to be done by the frontend owner: replace the current voice-coming-soon action with recording/upload to `/voice/analyze`, show/allow correction of `transcript`, render `analysis` as for typed input, and optionally send the displayed `care_navigation` plus `disclaimer` to `/voice/synthesize` and play `audio_base64`. Do not request speech output when the analysis is an urgent-care interception unless the UI intentionally reads its urgent guidance.

#### Exact Flutter request and response details

`/api/v1/voice/analyze` expects `multipart/form-data`; send the captured browser audio as the `audio` file part (not a JSON or base64 string), plus `session_id` and optional `language` (`auto` by default). Saaras detects the spoken language automatically; `language` is a preference passed into Sakhi analysis, not an STT language override. Example:

```sh
curl -X POST http://127.0.0.1:8001/api/v1/voice/analyze \
  -F 'audio=@recording.wav;type=audio/wav' \
  -F 'session_id=anonymous-session-123' \
  -F 'language=auto'
```

Successful response shape (the `analysis` object is the existing symptom-analysis response):

```json
{
  "transcript": "मुझे दो महीने से पीरियड नहीं आया",
  "detected_language": "hi-IN",
  "analysis": {
    "session_id": "anonymous-session-123",
    "extracted": {
      "original_description": "मुझे दो महीने से पीरियड नहीं आया",
      "detected_language": "Hindi",
      "explicit_symptoms": [],
      "menstrual_timing": null,
      "reported_cycle_gap_days": null,
      "duration_and_context": null,
      "uncertainties": [],
      "clarification_questions": []
    },
    "safety": {
      "passed": true,
      "triggered_rules": [],
      "action_taken": "none",
      "urgent_care_required": false,
      "urgent_guidance": null,
      "user_message": "",
      "is_diagnostic_claim_prevented": false
    },
    "knowledge_references": [],
    "care_navigation": "Non-diagnostic guidance returned by Sakhi",
    "disclaimer": "Sakhi is a non-diagnostic clinical companion...",
    "requires_consent_to_save": true
  }
}
```

`/api/v1/voice/synthesize` expects JSON and responds with JSON containing base64 audio; decode `audio_base64` to bytes and play as `audio/wav`:

```json
{
  "text": "Please discuss these symptoms with a qualified healthcare provider.",
  "language_code": "en-IN"
}
```

```json
{
  "audio_base64": "<base64 WAV bytes>",
  "content_type": "audio/wav",
  "language_code": "en-IN",
  "model": "bulbul:v3"
}
```

Supported `language_code` values are `en-IN` (English), `hi-IN` (Hindi), `bn-IN` (Bengali), `gu-IN` (Gujarati), `kn-IN` (Kannada), `ml-IN` (Malayalam), `mr-IN` (Marathi), `od-IN` (Odia), `pa-IN` (Punjabi), `ta-IN` (Tamil), and `te-IN` (Telugu). The STT REST endpoint handles short audio only (up to 30 seconds); it accepts supported audio formats such as WAV, MP3, AAC, FLAC, OGG, and WebM. The application also enforces a 12 MB upload limit. Keep recordings within both limits and use one of the listed language codes for TTS.

Errors use FastAPI's `{ "detail": "..." }` shape: `413` for audio over 12 MB, `415` for a non-audio upload, `422` for empty/unsupported audio or language, `503` for missing/rejected credentials or provider capacity, `502` for provider/service response failures, and `504` for timeouts. Provider error bodies and credentials are not returned to the browser. Voice input is analyzed but not saved; only the existing explicit-consent save flow persists symptoms.

## Run the Flutter Web app

In a second terminal, from `frontend`:

```powershell
flutter pub get
flutter run -d chrome --web-port 3000
```

The app calls `http://127.0.0.1:8000` by default. For a different backend URL, pass `--dart-define=API_BASE_URL=https://your-api.example` when running or building Flutter Web.

For browser CORS, set `ALLOWED_ORIGINS` in `backend/.env` to the frontend origin, such as `http://localhost:3000,http://127.0.0.1:3000`.

## Data and safety notes

- A fresh anonymous session is used by default. The demo session contains seeded illustrative data and is clearly marked in the interface.
- Symptom records are stored only after explicit consent.
- Symptom guidance is educational and non-diagnostic. Urgent symptom screening and response checks run deterministically.
- Without MongoDB, storage is temporary. Without Gemini, symptom extraction uses deterministic local matching; the health endpoint reports the active mode.
- Knowledge seed entries marked as needing review are demonstration content and should not be presented as clinically reviewed material.
