"""
IndicASR Service for ASHA Tele-Triage System
Provides offline speech-to-text for 22 Indian languages using faster-whisper + IndicWhisper.
"""

import os
import tempfile
import logging
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

_WhisperModel = None
try:
    from faster_whisper import WhisperModel
    _WhisperModel = WhisperModel
except ImportError:
    logger.warning("faster-whisper not installed. ASR will fall back to browser Web Speech API. Install with: pip install faster-whisper")


LANG_CODE_MAP = {
    "hi-IN": "hi",
    "en-IN": "en",
    "ta-IN": "ta",
    "te-IN": "te",
    "bn-IN": "bn",
    "mr-IN": "mr",
    "kn-IN": "kn",
    "ml-IN": "ml",
    "gu-IN": "gu",
    "pa-IN": "pa",
    "or-IN": "or",
    "ur-IN": "ur",
}

MODEL_NAME = "parthiv11/indic-whisper-nodcil"


class IndicASRService:
    """Wrapper around faster-whisper + IndicWhisper for the ASHA Tele-Triage backend."""

    def __init__(self, model_name: str = MODEL_NAME, device: str = "cpu", compute_type: str = "int8"):
        self._model = None
        self._model_name = model_name
        self._device = device
        self._compute_type = compute_type
        if _WhisperModel is not None:
            try:
                self._model = _WhisperModel(model_name, device=device, compute_type=compute_type)
                logger.info("IndicASR service initialized with model: %s", model_name)
            except Exception as e:
                logger.error("Failed to initialize IndicASR service: %s", e)
                self._model = None
        else:
            logger.info("faster-whisper package not available. Service running in fallback mode.")

    @property
    def available(self) -> bool:
        return self._model is not None

    def transcribe(self, audio_path: str, language: str = "hi-IN") -> Dict[str, Any]:
        """
        Transcribe an audio file to text.

        Args:
            audio_path: Path to audio file (WAV/FLAC/MP3, 16kHz mono preferred)
            language: BCP-47 language tag (e.g., "hi-IN", "ta-IN")

        Returns:
            Dict with keys: text, language, confidence, engine, duration
        """
        if not self.available:
            return {
                "text": "",
                "language": language,
                "confidence": 0.0,
                "engine": "none",
                "error": "IndicWhisper model not loaded"
            }

        lang_code = LANG_CODE_MAP.get(language, "hi")
        try:
            segments, info = self._model.transcribe(
                audio_path,
                beam_size=5,
                language=lang_code,
                condition_on_previous_text=False,
                vad_filter=True,
                vad_parameters=dict(min_silence_duration_ms=500),
            )

            text_parts = []
            for segment in segments:
                text_parts.append(segment.text.strip())

            text = " ".join(text_parts).strip()
            return {
                "text": text,
                "language": language,
                "confidence": round(info.language_probability, 2),
                "engine": f"faster-whisper + {self._model_name}",
                "duration": round(info.duration, 1) if info.duration else None,
            }
        except Exception as e:
            logger.error("IndicASR transcription failed: %s", e)
            return {
                "text": "",
                "language": language,
                "confidence": 0.0,
                "engine": "faster-whisper",
                "error": str(e)
            }

    def transcribe_bytes(self, audio_bytes: bytes, language: str = "hi-IN") -> Dict[str, Any]:
        """
        Transcribe raw audio bytes to text.

        Args:
            audio_bytes: Raw audio data (WAV/WebM/MP3)
            language: BCP-47 language tag

        Returns:
            Dict with keys: text, language, confidence, engine, duration
        """
        tmp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
                tmp.write(audio_bytes)
                tmp_path = tmp.name
            return self.transcribe(tmp_path, language=language)
        except Exception as e:
            logger.error("IndicASR bytes transcription failed: %s", e)
            return {
                "text": "",
                "language": language,
                "confidence": 0.0,
                "engine": "faster-whisper",
                "error": str(e)
            }
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.remove(tmp_path)
                except Exception:
                    pass


# Global singleton (lazy-loaded)
_asr_service: Optional[IndicASRService] = None


def get_asr_service() -> IndicASRService:
    """Get or create the global IndicASR service instance."""
    global _asr_service
    if _asr_service is None:
        _asr_service = IndicASRService()
    return _asr_service
