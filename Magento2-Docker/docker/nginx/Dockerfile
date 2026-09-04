# ==========================================================
# Custom nginx image
#
# The stock nginx:1.30 image does not include curl, but the
# healthcheck defined in docker-compose.yml for this service
# uses curl. Without it, the container's healthcheck always
# fails, nginx never reports "healthy", and Varnish (which
# depends on nginx being healthy) never starts.
# ==========================================================

FROM nginx:1.30

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
