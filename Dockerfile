# Use Python base image
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies including uv for Python package management
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install uv

# Copy the entire repository
COPY . .

# Install Python dependencies using uv and pyproject.toml
RUN cd python && uv sync --all-extras --dev && uv pip install uvicorn fastapi cryptography supabase python-multipart pydantic crawl4ai playwright docker requests aiohttp websockets python-socketio

# Expose port 3737 for the main service
EXPOSE 3737

# Set environment variables
WORKDIR /app/python
ENV PYTHONPATH=/app/python/
ENV PATH="/app/python/.venv/bin:$PATH"

# Start the main Archon server
CMD ["python", "-m", "uvicorn", "python.src.server.main:app", "--host", "0.0.0.0", "--port", "3737"]