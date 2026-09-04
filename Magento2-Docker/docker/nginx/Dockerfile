
FROM nginx:1.30

# ==========================================================
# Install curl for Docker healthcheck
# ==========================================================

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
