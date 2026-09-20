#!/bin/bash
#
# Starts the image and makes it do the thing it exists for.
#
# A database image that builds but cannot load its extension fails at a
# rolling restart of a primary otherwise, which is the wrong place to find
# out. So every build runs this: initdb, start with the library preloaded,
# create the extension, create a hypertable, enable compression, and check
# the edition.
#
# A file rather than a script inlined in the workflow, because the SQL needs
# single quotes and nesting those through YAML and `docker run -c` is how the
# first version of this ended up passing literal backslashes to psql.

set -euo pipefail

export PGDATA=/tmp/verify
mkdir -p "$PGDATA"
chown postgres "$PGDATA"

run() { su postgres -c "psql -v ON_ERROR_STOP=1 -tAc \"$1\""; }

su postgres -c "initdb -D $PGDATA -A trust" > /dev/null
su postgres -c "pg_ctl -D $PGDATA -o '-c shared_preload_libraries=timescaledb' -w start" > /dev/null

run "CREATE EXTENSION timescaledb" > /dev/null

echo "server:    $(run 'SHOW server_version')"
echo "extension: $(run "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb'")"

# Community, not Apache. Both provide hypertables; only Community provides
# compression, and CREATE EXTENSION succeeds under either — so nothing above
# would notice an -oss package substituted by mistake.
license=$(run 'SHOW timescaledb.license')
echo "license:   $license"
if [ "$license" != "timescale" ]; then
  echo "expected the Community edition, got '$license'" >&2
  exit 1
fi

run "CREATE TABLE t (at timestamptz NOT NULL, v double precision)" > /dev/null
run "SELECT create_hypertable('t', 'at')" > /dev/null
run "ALTER TABLE t SET (timescaledb.compress)" > /dev/null
echo "hypertable and compression: ok"
