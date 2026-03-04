# Makefile
# =============================================================================
# DATA SCIENCE PLATFORM ADMINISTRATION
# =============================================================================

# Default service for generic targets.
SERVICE ?= jupyterhub

# Docker Compose command wrapper.
COMPOSE := docker compose -f compose/docker-compose.yml

.PHONY: all deploy soft-redeploy hard-redeploy check vault-edit help \
        up down restart logs shell status \
        reload-caddy reload-prom reload-grafana \
        validate-compose validate-caddy validate-authelia \
        psql valkey forgejo-admin authelia-hash \
        prune-jupyter prune-images snapshots backup

# -----------------------------------------------------------------------------
# CORE COMMANDS
# -----------------------------------------------------------------------------

# Default: Deploy infrastructure
all: deploy

deploy:
	@echo "Deploying infrastructure with Ansible..."
	@ansible-playbook ansible/playbook.yml

soft-redeploy:
	@echo "Soft-redeploying infrastructure..."
	@$(COMPOSE) down -v --remove-orphans
	@docker container prune -f
	@docker network prune -f
	@ansible-playbook ansible/playbook.yml

hard-redeploy:
	@echo "Hard-redeploying infrastructure..."
	@$(COMPOSE) down -v --remove-orphans
	@docker system prune -af
	@ansible-playbook ansible/playbook.yml

check:
	@echo "Running Ansible in check mode..."
	@ansible-playbook ansible/playbook.yml --check

# -----------------------------------------------------------------------------
# SERVICE MANAGEMENT
# -----------------------------------------------------------------------------

status:
	@echo "Checking container status..."
	@$(COMPOSE) ps -a

up:
	@$(COMPOSE) up -d

down:
	@$(COMPOSE) down

# Usage: make restart SERVICE=authelia
restart:
	@echo "Restarting service: $(SERVICE)"
	@$(COMPOSE) restart $(SERVICE)

# Usage: make logs SERVICE=caddy
logs:
	@$(COMPOSE) logs -f --tail=100 $(SERVICE)

# Usage: make shell SERVICE=postgres
shell:
	@echo "Entering container: $(SERVICE)"
	@$(COMPOSE) exec -it $(SERVICE) sh -c "(bash || sh)"

# -----------------------------------------------------------------------------
# CONFIGURATION VALIDATION
# -----------------------------------------------------------------------------

validate-compose:
	@echo "Validating Docker Compose configuration..."
	@$(COMPOSE) config -q && echo "OK: Docker Compose configuration is valid."

validate-caddy:
	@echo "Validating Caddy configuration..."
	@$(COMPOSE) exec -w /etc/caddy caddy caddy validate

# Spawn a temporary container to validate config files on disk.
validate-authelia:
	@echo "Validating Authelia configuration..."
	@docker run --rm \
		-v $(PWD)/config/authelia/configuration.yml:/config/configuration.yml \
		-v $(PWD)/config/authelia/users_database.yml:/config/users_database.yml \
		authelia/authelia:4 authelia config validate

# -----------------------------------------------------------------------------
# ADMIN TOOLS
# -----------------------------------------------------------------------------

vault-edit:
	@echo "Editing Ansible Vault..."
	@ansible-vault edit secrets/vault.yml

psql:
	@echo "Connecting to PostgreSQL..."
	@$(COMPOSE) exec -it postgresql psql -U postgres_root -d postgres

valkey:
	@echo "Connecting to Valkey..."
	@$(COMPOSE) exec -it valkey valkey-cli -a $$(cat secrets/valkey_password.txt)

authelia-hash:
	@echo "Generating Argon2id hash..."
	@echo "Enter password to hash:"
	@docker run --rm -it authelia/authelia:4 authelia crypto hash generate argon2id --parallelism 4 --memory 65536 --iterations 3 --salt-length 16 --key-length 32

# -----------------------------------------------------------------------------
# MAINTENANCE & BACKUP
# -----------------------------------------------------------------------------

prune-images:
	@echo "Pruning orphaned images..."
	@docker image prune -f

prune-jupyter:
	@echo "Pruning orphaned JupyterHub containers..."
	@docker run --rm \
		--network ds-backend-net \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-e JUPYTERHUB_DB_PASSWORD=$$(cat secrets/jupyterhub_db_password.txt) \
		jupyterhub-pruner:latest

# Trigger a manual backup immediately.
# Use `tee` to show output in the console AND write it 
# to the log file so that Alloy/Loki can pick up the event.
backup:
	@echo "Triggering manual backup..."
	@sudo /usr/local/bin/run-backup.sh 2>&1 | sudo tee -a /var/log/backup.log

snapshots:
	@echo "Listing Restic snapshots..."
	@sudo sh -c 'export RESTIC_PASSWORD=$$(cat secrets/restic_password.txt); export RESTIC_REPOSITORY=/srv/backups/restic_repo; restic snapshots'

# -----------------------------------------------------------------------------
# HELP
# -----------------------------------------------------------------------------

help:
	@echo "Data Science Platform Administration"
	@echo "===================================="
	@echo "Deployment:"
	@echo "  make deploy              : Run full Ansible deployment."
	@echo "  make soft-redeploy       : Recreate containers/networks (keeps images/volumes)."
	@echo "  make hard-redeploy       : Wipe everything (containers/images/cache) & redeploy."
	@echo "  make check               : Run Ansible dry-run."
	@echo ""
	@echo "Service Management:"
	@echo "  make status              : Check status of all containers."
	@echo "  make up                  : Start all services."
	@echo "  make down                : Stop all services."
	@echo "  make restart SERVICE=... : Restart specific service (default: jupyterhub)."
	@echo "  make logs SERVICE=...    : Tail logs (default: jupyterhub)."
	@echo "  make shell SERVICE=...   : Open shell in container."
	@echo ""
	@echo "Validation:"
	@echo "  make validate-compose    : Validate Docker Compose syntax."
	@echo "  make validate-caddy      : Validate Caddyfile syntax."
	@echo "  make validate-authelia   : Validate Authelia config."
	@echo ""
	@echo "Admin Tools:"
	@echo "  make vault-edit          : Edit Ansible Vault."
	@echo "  make psql                : Postgres console."
	@echo "  make valkey              : Valkey CLI."
	@echo "  make authelia-hash       : Generate password hash."
	@echo ""
	@echo "Maintenance:"
	@echo "  make prune-images        : Remove orphaned images."
	@echo "  make prune-jupyter       : *Manually* run orphaned container pruner."
	@echo "  make backup              : *Manually* trigger immediate backup."
	@echo "  make snapshots           : List backup snapshots."
