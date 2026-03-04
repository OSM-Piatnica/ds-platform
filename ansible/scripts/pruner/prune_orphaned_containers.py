#!/usr/bin/env python3

# ansible/scripts/pruner/prune_orphaned_containers.py

"""
Safely prunes "exited" JupyterHub containers that have been deleted from the
Hub's database.

Strategy:
    1. Find all Docker containers with label "jupyterhub.managed-by=jupyterhub"
    and status "exited".
    2. Read the "jupyterhub.user" and "jupyterhub.service.name" labels from the
    container.
    3. Check if that (user, server) pair still exists in the JupyterHub
    database.
    4. If not found in DB -> Prune.
"""
import os
import sys
import re
import docker
import psycopg

DB_NAME = "jupyterhub_db"
DB_USER = "jupyterhub_user"
DB_PASSWORD = os.environ.get("JUPYTERHUB_DB_PASSWORD")
DB_HOST = "postgresql"

# Labels defined in the `jupyterhub_config.py`.
LABEL_MANAGED_BY = "jupyterhub.managed-by=jupyterhub"
LABEL_USER = "jupyterhub.user"
LABEL_SERVER = "jupyterhub.service.name"

def escape_name(name):
    """
    Replicate DockerSpawner's default, internal naming logic for container
    sanitization.

    DockerSpawner doesn't allow special characters in container names ---
    it replaces them with their hex equivalent.

    Safe chars: [a-z0-9]
    Unsafe chars: replaced with -{hex code}
    Example: 'test_server' -> 'test-5fserver'
    """
    if not name:
        return ""
    # Replace any character that is not 'a-z' or '0-9' with -{hex}.
    escaped = re.sub(r"[^a-z0-9]", lambda x: f"-{ord(x.group(0)):x}", name)
    # Return lowercase result (which is standard DockerSpawner behavior).
    return escaped.lower()

def get_active_servers():
    """
    Return a set of (username, servername) tuples for all
    servers currently active in the JupyterHub's database.
    """
    active_servers = set()
    conn_string = f"dbname={DB_NAME} user={DB_USER} password={DB_PASSWORD} host={DB_HOST}"

    try:
        with psycopg.connect(conn_string) as conn:
            with conn.cursor() as cur:
                # Join users and spawners to get the human-readable names.
                cur.execute("""
                    SELECT u.name, s.name
                    FROM spawners s
                    JOIN users u ON s.user_id = u.id
                    """)
                rows = cur.fetchall()

        for username, server_name in rows:
            # Ensure server_name is an empty string if it's None/Default.
            s_name = server_name if server_name else ""

            # Sanitze the database values to match Docker labels.
            user = escape_name(username)
            s_name = escape_name(server_name)

            active_servers.add((user, s_name))

        print(f"DB Check: Found {len(active_servers)} active servers in the database.")

        return active_servers

    except Exception as e:
        print(f"FATAL: Could not connect or query database: {e}",
                file=sys.stderr)
        sys.exit(1)

def prune_orphans():
    try:
        client = docker.from_env()
        # Get all "exited" containers that have specific management label.
        containers = client.containers.list(
                all=True,
                filters={
                    "status": "exited",
                    "label": LABEL_MANAGED_BY
                }
        )
    except Exception as e:
        print(f"FATAL: Could not connect to Docker: {e}", file=sys.stderr)
        sys.exit(1)

    if not containers:
        print("No 'exited' JupyterHub containers found.")
        sys.exit(0)

    print(f"Docker Check: Found {len(containers)} 'exited' JupyterHub containers.")

    active_servers = get_active_servers()
    orphans = []

    for c in containers:
        # Extract metadata from labels.
        labels = c.labels
        user = labels.get(LABEL_USER)
        server = labels.get(LABEL_SERVER)

        # We construct the tuple exactly as it appears in the DB.
        container_key = (user, server)

        if container_key not in active_servers:
            orphans.append(c)
            print(f"  [ORPHAN] Found: {c.name}")
            print(f"           Label User: {user}")
            print(f"           Label Server: {server}")
        else:
            print(f"  [VALID] Ignoring: {c.name}")

    if not orphans:
        print("No orphans found. Everything looks consistent.")
        sys.exit(0)

    print(f"\nPruning {len(orphans)} orphaned container(s)...")

    for c in orphans:
        print(f"  Removing {c.name} ({c.id[:12]})...")
        try:
            c.remove(force=True)
        except Exception as e:
            print(f"  ...Error removing {c.id[:12]}: {e}", file=sys.stderr)

    print("Pruning complete.")

if __name__ == "__main__":
    if not DB_PASSWORD:
        print("FATAL: JUPYTERHUB_DB_PASSWORD env var is not set.",
                file=sys.stderr)
        sys.exit(1)

    prune_orphans()
