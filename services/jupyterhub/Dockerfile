# services/jupyterhub/Dockerfile

FROM jupyterhub/jupyterhub:5

# Install system-level build dependencies for psycopg
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install the spawner, authenticator, and postgres dependencies.
RUN python3 -m pip install --no-cache-dir \
    "oauthenticator==17.*" \
    "dockerspawner==14.*" \
    "psycopg" \
    "requests"

# Handle the UID 1000 conflict.
# Check if a user with such UID exists, and
# delete it to claim for "jovyan" instead.
RUN if getent passwd 1000; then userdel -f $(getent passwd 1000 | cut -d: -f1); fi

# Create the standard non-root user "jovyan" (UID 1000).
# (`-m` flag creates a home directory for files)
RUN useradd -m -s /bin/bash -u 1000 jovyan

# Ensure the "jovyan" user owns the working directory, so
# it can write lock files and secrets if needed.
RUN chown -R jovyan:jovyan /srv/jupyterhub

# Switch to the new user.
USER jovyan
