#!/bin/bash
# entrypoint.sh

set -e

# This script runs as the root user inside the container before switching to jovyan
# It prepares the user's project directory based on environment variables set
# by the Hub.

# =============================================================================
# Environment Variable Validation
# =============================================================================
if [[ -z "$JUPYTER_PROJECT_NAME" ]]; then
    echo "FATAL: JUPYTER_PROJECT_NAME is not set. Cannot proceed." >&2
    exit 1
fi
if [[ -z "$JUPYTER_IMAGE_SPEC" ]]; then
    echo "FATAL: JUPYTER_IMAGE_SPEC is not set. Cannot proceed." >&2
    exit 1
fi

# =============================================================================
# Path and Variable Setup
#
# The user's home directory is mounted from the host, so these changes will persist.
# =============================================================================

# The container runs as ROOT initially (see Dockerfile).
# The ownership of the bind-mounted directory (which comes from the host)
# must be fixed, because the host directory might be owned by root or a
# different UID.
echo "Entrypoint: Ensuring 'jovyan' user owns bind-mounted user directory."
chown -R jovyan:users "/home/jovyan"

PROJECT_PATH_IN_CONTAINER="/home/jovyan/${JUPYTER_PROJECT_NAME}"

# Use `gosu` to drop privileges from ROOT to JOVYAN before executing commands.
# This ensures that files created here are owned by the user, not root.
echo "Entrypoint: Ensuring project directory exists at ${PROJECT_PATH_IN_CONTAINER} and has correct permissions."
gosu jovyan bash -c "mkdir -p ${PROJECT_PATH_IN_CONTAINER}"

# =============================================================================
# Project File / Metadata Population
# =============================================================================

# Parse the short image name from the full image spec (e.g.,
# git.mydomain.com/user/image:tag -> image).
IMAGE_NAME_SHORT=$(basename "${JUPYTER_IMAGE_SPEC}" | cut -d':' -f1 | sed "s/_image//")

# -----------------------------------------------------------------------------
# uv's Project Dependency File
# -----------------------------------------------------------------------------

PYPROJECT_SOURCE="/etc/jupyterhub/image-meta/${IMAGE_NAME_SHORT}/pyproject.toml"

DEST_PYPROJECT="${PROJECT_PATH_IN_CONTAINER}/pyproject.toml"

if [[ -f "${PYPROJECT_SOURCE}" ]]; then
    if [[ ! -f "${DEST_PYPROJECT}" ]]; then
        echo "Entrypoint: Copying pyproject.toml for "${IMAGE_NAME_SHORT}" to
        project directory and setting correct permissions."
        cp "$PYPROJECT_SOURCE" "$DEST_PYPROJECT"
        chown -R jovyan:users "$DEST_PYPROJECT"

        # Only generate a lock file if it's not the base image
        if [[ "${IMAGE_NAME_SHORT}" != "base" ]]; then
            echo "Entrypoint: Generating uv.lock file for project..."
            # Run uv lock as the jovyan user to ensure correct file permissions
            gosu jovyan bash -c "cd ${PROJECT_PATH_IN_CONTAINER} && uv lock"
        fi
    else
        echo "Entrypoint: '${DEST_PYPROJECT}' already exists, skipping copy."
    fi
else
    echo "Entrypoint: No pyproject.toml found for image '${IMAGE_NAME_SHORT}' at ${PYPROJECT_SOURCE}"
fi

# -----------------------------------------------------------------------------
# Default `.gitignore` Injection
# -----------------------------------------------------------------------------

GITIGNORE_SOURCE="/etc/jupyterhub/image-meta/gitignore"
DEST_GITIGNORE="${PROJECT_PATH_IN_CONTAINER}/.gitignore"

# Only copy if it doesn't exist (respect user customization).
if [[ -f "${GITIGNORE_SOURCE}" ]]; then
    if [[ ! -f "${DEST_GITIGNORE}" ]]; then
        echo "Entrypoint: Injecting default .gitignore for '${IMAGE_NAME_SHORT}'..."
        cp "$GITIGNORE_SOURCE" "$DEST_GITIGNORE"
        chown jovyan:users "$DEST_GITIGNORE"
    fi
fi

# -----------------------------------------------------------------------------
# Jupytext Configuration (Auto-Paring)
# -----------------------------------------------------------------------------

# Source the default config from the image metadata directory.
JUPYTEXT_SOURCE="/etc/jupyterhub/image-meta/jupytext.toml"
DEST_JUPYTEXT="${PROJECT_PATH_IN_CONTAINER}/jupytext.toml"

# Only copy if it doesn't exist (respect user cutomization).
if [[ -f "${JUPYTEXT_SOURCE}" ]]; then
    if [[ ! -f "${DEST_JUPYTEXT}" ]]; then
        echo "Entrypoint: Configuring Jupytext auto-pairing for '${IMAGE_NAME_SHORT}'..."
        cp "$JUPYTEXT_SOURCE" "$DEST_JUPYTEXT"
        chown jovyan:users "$DEST_JUPYTEXT"
    fi
fi

# =============================================================================
# Helper Script Population
# =============================================================================

DEST_SCRIPT="${PROJECT_PATH_IN_CONTAINER}/del_proj_dir.sh"

if [[ ! -f "${DEST_SCRIPT}" ]]; then
    echo "Entrypoint: Copying helper script to project directory and setting
    permissions."
    cp "/etc/jupyterhub/scripts/del_proj_dir.sh" "$DEST_SCRIPT"
    chown -R jovyan:users "$DEST_SCRIPT"
fi

# =============================================================================
# SSH Key Generation (Zero-Touch)
# =============================================================================
SSH_DIR="/home/jovyan/.ssh"
SSH_KEY="$SSH_DIR/id_ed25519"

if [[ ! -f "$SSH_KEY" ]]; then
    echo "Entrypoint: Generating new SSH key for persistent usage..."
    # Create directory with correct permissions.
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    
    # Generate key non-interactively (-N "" means no passphrase).
    ssh-keygen -t ed25519 -C "jupyterhub-generated-key" -N "" -f "$SSH_KEY"
    
    # Ensure correct ownership immediately.
    chown -R jovyan:users "$SSH_DIR"
    chmod 600 "$SSH_KEY"
    chmod 644 "$SSH_KEY.pub"
fi

# =============================================================================
# Final Setup and Execution
# =============================================================================

# Set the working directory to the project path.
cd "${PROJECT_PATH_IN_CONTAINER}"

echo "Entrypoint: Setup complete. Handing over to command..."
# Switch to the jovyan user, preserving the environment, and execute the main
# command.
exec gosu jovyan "$@"
