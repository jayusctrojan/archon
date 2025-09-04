# Use Python base image instead of Docker Compose
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the repository
COPY . .

# Install Python dependencies for the server
RUN cd python && pip install -r requirements.txt

# Expose port 3737 for the UI (main interface)
EXPOSE 3737

# Set environment variables
ENV PYTHONPATH=/app/python/src

# Start the main Archon server
CMD ["python", "-m", "uvicorn", "python.src.server.main:app", "--host", "0.0.0.0", "--port", "3737"]