# Use the official Docker-in-Docker image
FROM docker/compose:latest

# Install Docker CLI
RUN apk add --no-cache docker-cli

# Set working directory
WORKDIR /app

# Copy your docker-compose.yml and other necessary files
COPY . .

# Expose the UI port
EXPOSE 3737

# Run docker-compose up
CMD ["docker-compose", "up", "--build"]