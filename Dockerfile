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

# Install system dependencies including uv and nginx for serving static files
RUN apt-get update && apt-get install -y \
    curl \
    nginx \
    && rm -rf /var/lib/apt/lists/* \
    && pip install uv

# Copy the entire repository for backend
COPY . .

# Install Python dependencies
RUN cd python && uv sync --all-extras --dev && uv pip install uvicorn fastapi cryptography supabase python-multipart pydantic crawl4ai playwright docker requests aiohttp websockets python-socketio python-jose streamlit

# Copy built React UI from builder stage
COPY --from=ui-builder /app/ui/dist /var/www/html

# Configure nginx to serve React app and proxy API calls
RUN echo 'server { \
    listen 3737; \
    root /var/www/html; \
    index index.html; \
    \
    # Serve React app \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    \
    # Proxy API calls to FastAPI backend \
    location /api/ { \
        proxy_pass http://localhost:8000/; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
        proxy_set_header X-Forwarded-Proto $scheme; \
    } \
}' > /etc/nginx/sites-available/default

# Set working directory to python folder for backend
WORKDIR /app/python

# Expose port 3737
EXPOSE 3737

# Set environment variables
ENV PYTHONPATH=/app/python
ENV PATH="/app/python/.venv/bin:$PATH"

# Create startup script
RUN echo '#!/bin/bash\n\
# Start nginx in background\n\
nginx\n\
\
# Start FastAPI backend\n\
python -m uvicorn src.server.main:app --host 0.0.0.0 --port 8000 &\n\
\
# Keep container running\n\
wait' > /app/start.sh && chmod +x /app/start.sh

# Start both nginx (for React UI) and FastAPI backend
CMD ["/app/start.sh"]