FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# ffmpeg is used by pydub / edge-tts when Speech features are enabled.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install core deps by default. Pass --build-arg REQUIREMENTS=requirements-ai.txt
# to build an image that also includes the AI/ML + Speech stack (large).
ARG REQUIREMENTS=requirements.txt
COPY requirements.txt requirements-ai.txt ./
RUN pip install --upgrade pip && pip install -r ${REQUIREMENTS}

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
