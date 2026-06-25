# ─────────────────────────────────────────────────────────
# Dockerfile — Driver Guard Driver Guard
#
# For development / testing (no hardware):
#   docker build -t driver_guard .
#   docker run -it --rm \
#     -p 5000:5000 \
#     driver_guard python main.py --simulate --no-web
#
# For Raspberry Pi (arm64):
#   docker buildx build --platform linux/arm64 -t driver_guard-rpi .
#
# Note: Real camera + GPIO require --device flags:
#   docker run --device /dev/video0 --device /dev/ttyUSB0 \
#              --privileged driver_guard python main.py
# ─────────────────────────────────────────────────────────

FROM python:3.11-slim

# ── OS dependencies ───────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    build-essential \
    libopenblas-dev \
    liblapack-dev \
    libx11-dev \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# ── Working directory ─────────────────────────────────────
WORKDIR /app

# ── Python dependencies ───────────────────────────────────
# Copy requirements first for layer caching
COPY requirements.txt .

# Install without dlib first (takes a while to compile)
RUN pip install --no-cache-dir \
    numpy opencv-python-headless PyYAML Pillow \
    mediapipe ultralytics \
    pyserial pynmea2 \
    flask flask-socketio eventlet \
    playsound imutils scipy loguru python-dotenv

# Build dlib separately (needs cmake, takes ~5 min on first build)
RUN pip install --no-cache-dir dlib

# ── Application code ──────────────────────────────────────
COPY . .

# Create data directories
RUN mkdir -p data/logs assets models

# ── Expose dashboard port ─────────────────────────────────
EXPOSE 5000

# ── Default command ───────────────────────────────────────
# Override at runtime: docker run driver_guard python main.py --simulate
CMD ["python", "main.py", "--simulate"]

# ── Health check ──────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD wget -qO- http://localhost:5000/api/state || exit 1
