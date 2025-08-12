# Use official Python base image
FROM python:3.11-slim

# Install system dependencies for sqlite3 and wget
RUN apt-get update && apt-get install -y \
    sqlite3 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir requests mercantile mbutil

# Create working directory
WORKDIR /app

# Copy your shell script into container
COPY mapmaker.sh .

# Make script executable
RUN chmod +x mapmaker.sh

# Set default command (can be overridden)
ENTRYPOINT ["./mapmaker.sh"]
CMD []