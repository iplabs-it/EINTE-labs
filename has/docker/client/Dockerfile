FROM python:3.11-alpine

# Install networking tools and bash for debugging
RUN apk add --no-cache \
    bash \
    curl \
    iproute2 \
    iputils \
    tcpdump

# Install Python dependencies
RUN pip install --no-cache-dir requests

# Create app directory
WORKDIR /app

# Copy client code
COPY dash_client.py /app/

# Create logs directory
RUN mkdir -p /app/logs

CMD ["python3", "/app/dash_client.py", "--mpd", "http://10.0.1.2/stream/manifest.mpd", "--output", "/app/logs", "--metrics", "--loop"]
