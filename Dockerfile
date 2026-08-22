FROM python:3.11-slim

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Application code
COPY . .

# Pre-cache IndicWhisper model for offline use
# If builder has internet, model downloads into HF_HOME.
# If builder is offline, this step is skipped gracefully.
ENV HF_HOME=/models/hf-cache
RUN mkdir -p /models/hf-cache && \
    python -c "from faster_whisper import WhisperModel; WhisperModel('parthiv11/indic-whisper-nodcil', device='cpu', compute_type='int8')" || true

EXPOSE 8000

# Production: gunicorn with Flask WSGI; fallback to built-in server if gunicorn unavailable
CMD ["gunicorn", "-b", "0.0.0.0:8000", "server:flask_app", "--timeout", "120"]
