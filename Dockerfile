# Multi-stage build for React UI
FROM node:18-slim as ui-builder

# Set working directory for UI build
WORKDIR /app/ui

# Copy UI package files
COPY archon-ui-main/package*.json ./

# Install UI dependencies
RUN npm ci

# Copy UI source code
COPY archon-ui-main/ ./

# Build the React application for production
RUN npm run build

# Production stage - Python backend + serve React UI
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies including uv for serving static files
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install uv

# Copy the entire repository for backend
COPY . .

# Install Python dependencies
RUN cd python && uv sync --all-extras --dev && uv pip install uvicorn fastapi cryptography supabase python-multipart pydantic crawl4ai playwright docker requests aiohttp websockets python-socketio python-jose streamlit

# Copy built React UI from builder stage
COPY --from=ui-builder /app/ui/dist /app/static

# Set working directory to python folder for backend
WORKDIR /app/python

# Expose port 3737
EXPOSE 3737

# Set environment variables
ENV PYTHONPATH=/app/python
ENV PATH="/app/python/.venv/bin:$PATH"

# Create a simple startup script that serves both the React UI and FastAPI backend
RUN echo '#!/bin/bash\n\
# Start FastAPI backend in background\n\
python -m uvicorn src.server.main:app --host 0.0.0.0 --port 8000 &\n\
\
# Start a simple HTTP server for the React UI on port 3737\n\
cd /app/static\n\
python -m http.server 3737\n\
' > /app/start.sh && chmod +x /app/start.sh

# Start both services
CMD ["/app/start.sh"]