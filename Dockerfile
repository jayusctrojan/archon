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

# Set Vite environment variable so React app makes API calls to the same host/port (nginx will proxy them)
ENV VITE_ARCHON_SERVER_PORT=3737

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

# Copy built React UI from builder stage and verify
COPY --from=ui-builder /app/ui/dist /var/www/html
RUN ls -la /var/www/html/ && echo "=== React build files ===" && find /var/www/html -type f -name "*.html" -o -name "*.js" -o -name "*.css" | head -10

# Configure nginx properly with corrected API routing
RUN echo 'events { worker_connections 1024; }\n\
http {\n\
    include /etc/nginx/mime.types;\n\
    default_type application/octet-stream;\n\
    \n\
    access_log /var/log/nginx/access.log;\n\
    error_log /var/log/nginx/error.log;\n\
    \n\
    server {\n\
        listen 3737 default_server;\n\
        root /var/www/html;\n\
        index index.html;\n\
        \n\
        # Serve React app for all non-API routes\n\
        location / {\n\
            try_files $uri $uri/ /index.html;\n\
        }\n\
        \n\
        # Proxy API calls to FastAPI backend (FIXED: preserve /api prefix)\n\
        location /api/ {\n\
            proxy_pass http://127.0.0.1:8000/api/;\n\
            proxy_set_header Host $host;\n\
            proxy_set_header X-Real-IP $remote_addr;\n\
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n\
            proxy_set_header X-Forwarded-Proto $scheme;\n\
            proxy_buffering off;\n\
            proxy_read_timeout 300s;\n\
            proxy_connect_timeout 75s;\n\
        }\n\
        \n\
        # Proxy docs and health endpoints\n\
        location /docs {\n\
            proxy_pass http://127.0.0.1:8000/docs;\n\
            proxy_set_header Host $host;\n\
        }\n\
        \n\
        location /health {\n\
            proxy_pass http://127.0.0.1:8000/health;\n\
            proxy_set_header Host $host;\n\
        }\n\
    }\n\
}\n\
daemon off;' > /etc/nginx/nginx.conf

# Set working directory to python folder for backend
WORKDIR /app/python

# Expose port 3737
EXPOSE 3737

# Set environment variables
ENV PYTHONPATH=/app/python
ENV PATH="/app/python/.venv/bin:$PATH"

# Create startup script with better debugging
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "=== Starting Archon Services ==="\n\
echo "Checking React build files..."\n\
ls -la /var/www/html/\n\
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
echo "Testing nginx configuration..."\n\
nginx -t\n\
\n\
echo "Starting nginx on port 3737..."\n\
nginx\n\
' > /app/start.sh && chmod +x /app/start.sh

# Start both services
CMD ["/app/start.sh"]