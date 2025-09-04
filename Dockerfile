# Just run the FastAPI backend directly without React UI complexity
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install uv

# Copy the entire repository
COPY . .

# Install Python dependencies
RUN cd python && uv sync --all-extras --dev && uv pip install uvicorn fastapi cryptography supabase python-multipart pydantic docker requests aiohttp websockets python-socketio python-jose

# Set working directory to python folder  
WORKDIR /app/python

# Expose port 3737
EXPOSE 3737

# Set environment variables
ENV PYTHONPATH=/app/python
ENV PATH="/app/python/.venv/bin:$PATH"

# Start just the FastAPI backend on port 3737
CMD ["python", "-m", "uvicorn", "src.server.main:app", "--host", "0.0.0.0", "--port", "3737"]