FROM python:3.11-slim AS base

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY scripts/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Training stage
FROM base AS trainer
ENTRYPOINT ["python", "scripts/train.py"]
CMD ["--config", "configs/routenet-gnn.yaml"]

# Inference/API stage
FROM base AS server
EXPOSE 8000
ENTRYPOINT ["uvicorn", "scripts.serve:app", "--host", "0.0.0.0", "--port", "8000"]
