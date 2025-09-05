# Multi-stage build: React UI + FastAPI backend
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

# Production stage - Python backend + React UI
FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Install system dependencies including nginx
RUN apt-get update && apt-get install -y \
    curl \
    nginx \
    && rm -rf /var/lib/apt/lists/* \
    && pip install uv

# Copy the entire repository for backend
COPY . .

# Install Python dependencies
RUN cd python && \
    uv sync --all-extras --dev && \
    uv pip install uvicorn fastapi cryptography supabase python-multipart pydantic docker requests aiohttp websockets python-socketio python-jose playwright crawl4ai && \
    .venv/bin/playwright install --with-deps chromium

# Copy built React UI from builder stage
COPY --from=ui-builder /app/ui/dist /var/www/html

# Configure nginx to serve React UI and proxy API calls
RUN echo 'server { \
    listen 3737 default_server; \
    root /var/www/html; \
    index index.html; \
    \
    # Serve React app for all non-API routes \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    \
    # Proxy all API calls to FastAPI backend \
    location /api/ { \
        proxy_pass http://127.0.0.1:8000/; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
        proxy_set_header X-Forwarded-Proto $scheme; \
        proxy_buffering off; \
        proxy_read_timeout 300s; \
        proxy_connect_timeout 75s; \
    } \
    \
    # Health check endpoint \
    location /health { \
        proxy_pass http://127.0.0.1:8000/health; \
        proxy_set_header Host $host; \
    } \
}' > /etc/nginx/sites-available/default

# Remove nginx daemon mode
RUN echo 'daemon off;' >> /etc/nginx/nginx.conf

# Set working directory to python folder for backend
WORKDIR /app/python

# Expose port 3737
EXPOSE 3737

# Set environment variables
ENV PYTHONPATH=/app/python
ENV PATH="/app/python/.venv/bin:$PATH"

# Create startup script that properly manages both services
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Starting FastAPI backend on port 8000..."\n\
python -m uvicorn src.server.main:app --host 127.0.0.1 --port 8000 --log-level info &\n\
BACKEND_PID=$!\n\
\n\
echo "Backend started with PID: $BACKEND_PID"\n\
echo "Waiting 10 seconds for backend to initialize..."\n\
sleep 10\n\
\n\
echo "Testing backend health..."\n\
curl -f http://127.0.0.1:8000/health || echo "Backend not ready yet, continuing..."\n\
\n\
echo "Starting nginx on port 3737..."\n\
nginx\n\
' > /app/start.sh && chmod +x /app/start.sh

# Start both services
CMD ["/app/start.sh"]