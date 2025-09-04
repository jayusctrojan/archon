# Use Python base image
FROM python:3.11-slim

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
RUN cd python && uv sync && uv pip install uvicorn fastapi python-multipart

# Expose port 3737 for the main service
EXPOSE 3737

# Set environment variables
ENV PYTHONPATH=/app/python/src
ENV PATH="/app/python/.venv/bin:$PATH"

# Start the main Archon server
CMD ["python", "-m", "uvicorn", "python.src.server.main:app", "--host", "0.0.0.0", "--port", "3737"]