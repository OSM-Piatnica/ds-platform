# ansible/scripts/pruner/Dockerfile

# syntax=docker/dockerfile:1

FROM ghcr.io/astral-sh/uv:python3.13-bookworm

# Compile `.pyc` files for faster application startup.
ENV UV_COMPILE_BYTECODE=1

# Always copy files in the containerized environment, suppressing `uv`'s
# hardlinking warning.
ENV UV_LINK_MODE=copy

# Increase timeout because of problems during dependency resolution.
ENV UV_HTTP_TIMEOUT=60

# Install docker (to talk to socket) and psycopg (to talk to DB).
# Use pip interface to install packages without reliance on `pyproject.toml`
# (perfectly appropriate use case, for containers requiring one-time
# installation of the packges / acting as applications instead of user
# environments).
RUN uv pip install --system --no-cache \
    "psycopg" \
    "docker"

# Security Improvement:
# Create and switch to a non-root user (UID 1000).
RUN useradd -m -u 1000 prune-admin
USER prune-admin

COPY prune_orphaned_containers.py /usr/local/bin/prune_orphaned_containers.py

ENTRYPOINT ["/usr/local/bin/prune_orphaned_containers.py"]
