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

# Install system dependencies including uv and nginx
RUN apt-get update && apt-get install -y \
    curl \
    nginx \
    && rm -rf /var/lib/apt/lists/* \
    && pip install uv

# Copy the entire repository for backend
COPY . .

# Install Python dependencies
RUN cd python && uv sync --all-extras --dev && uv pip install uvicorn fastapi cryptography supabase python-multipart pydantic crawl4ai playwright docker requests aiohttp websockets python-socketio python-jose streamlit

# Copy built React UI from builder stage to nginx directory
COPY --from=ui-builder /app/ui/dist /var/www/html

# Configure nginx properly
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
    } \
}' > /etc/nginx/sites-available/default

# Remove nginx default config and daemon mode
RUN echo 'daemon off;' >> /etc/nginx/nginx.conf

# Set working directory to python folder for backend
WORKDIR /app/python

# Expose port 3737
EXPOSE 3737

# Set environment variables
ENV PYTHONPATH=/app/python
ENV PATH="/app/python/.venv/bin:$PATH"

# Create startup script that runs both services
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Starting FastAPI backend..."\n\
python -m uvicorn src.server.main:app --host 127.0.0.1 --port 8000 &\n\
BACKEND_PID=$!\n\
\n\
echo "Waiting for backend to start..."\n\
sleep 5\n\
\n\
echo "Starting nginx..."\n\
nginx\n\
\n\
echo "Services started. Backend PID: $BACKEND_PID"\n\
wait $BACKEND_PID\n\
' > /app/start.sh && chmod +x /app/start.sh

# Start both services
CMD ["/app/start.sh"]