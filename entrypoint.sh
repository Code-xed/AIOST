#!/bin/bash
set -e

PGDATA=/data/postgres
DBNAME=neondb
DBUSER=neondb_owner
DBPASS=localpass

mkdir -p /data
chown -R postgres:postgres /data

# Initialize PostgreSQL only on first run
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "Initializing PostgreSQL..."
    su postgres -c "initdb -D '$PGDATA'"
fi

echo "Starting PostgreSQL..."
su postgres -c "pg_ctl -D '$PGDATA' -o '-p 5432' -w start"

# Create user/database if they don't exist
su postgres -c \
    "psql -p 5432 -c \"CREATE USER $DBUSER WITH PASSWORD '$DBPASS';\"" \
    2>/dev/null || true

su postgres -c \
    "createdb -p 5432 -O $DBUSER $DBNAME" \
    2>/dev/null || true

# Restore the bundled Neon dump only if this is a fresh database
TABLES=$(su postgres -c \
    "psql -p 5432 -d $DBNAME -tAc \"SELECT count(*) FROM information_schema.tables WHERE table_schema='public'\"")

if [ "$TABLES" = "0" ]; then
    echo "Restoring aiostreams.dump..."

    su postgres -c \
        "pg_restore \
        -p 5432 \
        -U $DBUSER \
        -d $DBNAME \
        --no-owner \
        --no-privileges \
        /app/aiostreams.dump"

    echo "Database restored."
else
    echo "Existing database found. Skipping restore."
fi

# Make AIOStreams use local PostgreSQL instead of Neon
export DATABASE_URI="postgres://$DBUSER:$DBPASS@127.0.0.1:5432/$DBNAME"

echo "Starting AIOStreams..."

exec node /app/packages/server/dist/server.js