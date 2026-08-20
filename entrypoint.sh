#!/bin/bash
set -e

PGDATA=/data/postgres
DBNAME=neondb
DBUSER=neondb_owner
DBPASS=localpass

PG_BIN="$(dirname "$(find /usr/lib/postgresql -name initdb -type f | head -1)")"

echo "PostgreSQL binaries: $PG_BIN"

mkdir -p /data
chown -R postgres:postgres /data

if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "Initializing PostgreSQL..."
    su postgres -c "$PG_BIN/initdb -D '$PGDATA'"
fi

echo "Starting PostgreSQL..."

su postgres -c \
    "$PG_BIN/pg_ctl -D '$PGDATA' -o '-p 5432' -w start"

su postgres -c \
    "$PG_BIN/psql -p 5432 -c \"CREATE USER $DBUSER WITH PASSWORD '$DBPASS';\"" \
    2>/dev/null || true

su postgres -c \
    "$PG_BIN/createdb -p 5432 -O $DBUSER $DBNAME" \
    2>/dev/null || true

TABLES=$(su postgres -c \
    "$PG_BIN/psql -p 5432 -d $DBNAME -tAc \
    \"SELECT count(*) FROM information_schema.tables WHERE table_schema='public'\"")

if [ "$TABLES" = "0" ]; then
    echo "Restoring aiostreams.dump..."

    su postgres -c \
        "$PG_BIN/pg_restore \
        -p 5432 \
        -U $DBUSER \
        -d $DBNAME \
        --no-owner \
        --no-privileges \
        /app/aiostreams.dump"

    echo "Database restore complete."
else
    echo "Existing database detected. Skipping restore."
fi

export DATABASE_URI="postgres://$DBUSER:$DBPASS@127.0.0.1:5432/$DBNAME"

echo "Starting AIOStreams..."

exec node /app/packages/server/dist/server.js