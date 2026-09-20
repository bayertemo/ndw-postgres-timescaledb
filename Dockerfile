# A CloudNativePG operand image with TimescaleDB installed.
#
# Built on CloudNativePG's own operand image rather than on
# `timescale/timescaledb-ha`. Both carry the extension; only this one carries
# the tooling the operator expects — its entrypoint, its instance manager, its
# backup and recovery hooks, its `postgres` UID. Running Timescale's image
# under CloudNativePG means overriding `postgresUID`/`postgresGID` to 70 and
# leaving the operator's supported path, which is a poor trade for an
# extension a package manager installs in one layer.
#
# So: the operand image, plus one apt repository, plus one package.

ARG PG_MAJOR=17

# Bookworm, not bullseye.
#
# The bullseye-based operand images are end of life: their Debian security
# pocket has moved to archive, so `apt-get install` inside one fails with 404s
# on packages the index still advertises. No extension can be layered onto
# them at all — not a flag away, the base has to change.
#
# Bookworm builds track the current PostgreSQL patch release, and the
# `17.2-N-bookworm` tags name the image build rather than the server, so a
# bookworm image pinned to an older patch does not exist. Taking bookworm
# means taking the current patch with it, which is the same major version and
# therefore a rolling restart under CloudNativePG rather than a `pg_upgrade`.
#
# Worth recording when choosing a patch version: TimescaleDB advises against
# PostgreSQL 17.1, 16.5 and 15.9, which shipped a breaking binary interface
# change that was reverted in the following patch releases.
ARG PG_IMAGE=ghcr.io/cloudnative-pg/postgresql:17-bookworm

FROM ${PG_IMAGE}

# Repeated after FROM: an ARG declared before it is out of scope afterwards.
ARG PG_MAJOR

# The extension version, pinned rather than floating.
#
# `2.30.1` is the release, `*` matches the Debian revision Timescale appends
# to it. Left unpinned, a rebuild months from now would quietly install
# whatever is newest — and an extension upgrade is a database migration, not a
# package update. Bumping this is a deliberate commit with its own changelog
# entry, which is the whole reason this repository is separate.
ARG TIMESCALE_VERSION=2.30.1

USER root

# Both `gnupg` and `lsb-release` are build-time only. They are removed in the
# same layer so the published image carries neither them nor the apt lists.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release; \
    \
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
        | gpg --dearmor -o /usr/share/keyrings/timescaledb.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/timescaledb.gpg] \
https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/timescaledb.list; \
    \
    apt-get update; \
    \
    # The Community edition, not `-oss`.
    #
    # Load-bearing. Both editions ship hypertables; only this one ships
    # compression, continuous aggregates and retention policies. `CREATE
    # EXTENSION` succeeds under either, so an `-oss` package substituted here
    # by mistake is not otherwise visible — which is why CI asserts the
    # license.
    #
    # Free to self-host. The Timescale License restricts offering TimescaleDB
    # as a database-as-a-service to third parties.
    apt-get install -y --no-install-recommends \
        "timescaledb-2-postgresql-${PG_MAJOR}=${TIMESCALE_VERSION}*"; \
    \
    apt-get purge -y --auto-remove gnupg lsb-release; \
    rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/timescaledb.list

# `timescaledb` must be in shared_preload_libraries or CREATE EXTENSION fails,
# and CloudNativePG owns postgresql.conf — it regenerates it from the Cluster
# spec on every reconciliation, so a line added here would be erased. It goes
# in the Cluster manifest instead, under
# `spec.postgresql.shared_preload_libraries`. Noted here because this is where
# somebody will look first when the extension will not create.

# Back to the unprivileged user the operator runs as. The operand image sets
# this to 26.
USER 26
