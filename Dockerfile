# syntax=docker/dockerfile:1.7
FROM python:3.12-slim

# Environment defaults; can be overridden at runtime
ENV PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/usr/local/bin \
    PATH="/usr/local/bin:${PATH}" \
    PIPX_PACKAGES="" \
    PIPX_PACKAGES_FILE=""

# Install run-time essentials and pipx
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir pipx \
    && pipx --version

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Persist pipx venvs by default (optional but recommended)
VOLUME ["/opt/pipx"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Default to an interactive shell if the user doesn't pass a command
CMD ["bash"]
