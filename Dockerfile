# syntax=docker/dockerfile:1.7
FROM python:3.12-slim

# Environment defaults; can be overridden at runtime
ENV PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/opt/pipx/bin \
    PATH="/opt/pipx/bin:/usr/local/bin:${PATH}" \
    PIPX_PACKAGES="" \
    PIPX_PACKAGES_FILE="" \
    PIPX_FORCE=0

# Install run-time essentials, tini (as PID 1), and pipx
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates tini \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir pipx \
    && pipx --version

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Use tini to forward signals and reap zombies
ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/entrypoint.sh"]

# Default command: keep container alive so you can docker exec into it
CMD ["sleep","infinity"]
