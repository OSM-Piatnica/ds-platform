#!/bin/bash

# compose/init-db.sh

set -e

# Fuction to create user and database
create_usr_db() {
	local service_name=$1
    local user_name="${service_name}_user"
    local db_name="${service_name}_db"
    # Passwords are read from the secret files mounted by Docker
    local password=$(cat "/run/secrets/${service_name}_db_password")

    echo "Initizalizing database for service: ${service_name}"

	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        DO
        \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname =
            '${user_name}') THEN
                CREATE USER ${user_name} WITH PASSWORD '${password}';
            ELSE
                ALTER USER ${user_name} WITH PASSWORD '${password}';
            END IF;
        END
        \$\$;

        SELECT 'CREATE DATABASE ${db_name} OWNER ${user_name}' 
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}')\gexec
EOSQL

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${db_name}" <<-EOSQL
        GRANT ALL ON SCHEMA public TO ${user_name};
EOSQL

    echo "Database initialization for service ${service_name} complete."
}

# Create users and databases for each service
create_usr_db "authelia"
create_usr_db "forgejo"
create_usr_db "jupyterhub"
create_usr_db "grafana"
