# postgres-timescaledb

**PostgreSQL with TimescaleDB, for CloudNativePG.** The official
[CloudNativePG operand image](https://github.com/cloudnative-pg/postgres-containers)
with [TimescaleDB](https://github.com/timescale/timescaledb) installed — a
drop-in `imageName` for a `Cluster`, with nothing the operator relies on
changed.

The **Community** edition is installed, not `-oss`, so compression, continuous
aggregates and retention policies all work.

## Quick start

Point a `Cluster` at it and preload the library:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: example
spec:
  instances: 3
  imageName: ghcr.io/bayertemo/ndw-postgres-timescaledb:17.11-ts2.30.1
  postgresql:
    shared_preload_libraries:
      - timescaledb
```

> **IMPORTANT:** use the version tag. CloudNativePG derives the PostgreSQL
> major version from the tag string — it rejects `latest` outright (*"Can't
> use 'latest' as image tag as we can't detect upgrades"*), and it reads the
> leading digits of whatever else it is given as a version number. A commit
> SHA beginning with digits is therefore parsed as a version: pinning
> `989820a6…` makes the operator believe it is being asked to upgrade to major
> version 989820, and it will start a `pg_upgrade` to get there.

Then, in each database:

```sql
CREATE EXTENSION timescaledb;
```

That's it — the package is public, so there is no `imagePullSecret` to create.
Everything below is reference detail.

## Why you might want this

- **Drop-in for CloudNativePG** — built on the operand image, so the
  entrypoint, instance manager, backup and recovery hooks and `postgres` UID
  are the ones the operator expects. No `postgresUID`/`postgresGID` overrides.
- **Community edition, verified** — every build asserts
  `SHOW timescaledb.license` returns `timescale`. `CREATE EXTENSION` succeeds
  under `-oss` too, so nothing else would notice the difference until you tried
  to compress something.
- **Public, so no pull secret** — a registry credential that expires is a
  database that will not start the next time a pod is rescheduled.
- **Proven before it ships** — CI boots the image and creates the extension, a
  hypertable and a compressed table before publishing. An image that builds but
  cannot load its extension otherwise fails at a rolling restart of a primary.

## What's in it

| | |
|---|---|
| PostgreSQL | 17 (bookworm) |
| TimescaleDB | 2.30.1, Community |
| Base | `ghcr.io/cloudnative-pg/postgresql:17-bookworm` |
| Platform | `linux/amd64` |

```
ghcr.io/bayertemo/ndw-postgres-timescaledb:17.11-ts2.30.1
ghcr.io/bayertemo/ndw-postgres-timescaledb:17.11
ghcr.io/bayertemo/ndw-postgres-timescaledb:latest
```

The version tags are the ones to use with CloudNativePG, for the reason above.
`latest` follows `main` and is there for `docker run`.

## Notes

- **`shared_preload_libraries` belongs in the `Cluster`, not the image.**
  CloudNativePG owns `postgresql.conf` and regenerates it from the spec on
  every reconciliation, so a line baked into the image is erased. This is the
  first thing to check when `CREATE EXTENSION` fails.
- **Bookworm, not bullseye.** The bullseye-based operand images are end of
  life: their Debian security pocket has moved to archive, so `apt-get install`
  inside one fails with 404s on packages the index still advertises — no
  extension can be layered onto them at all. Bookworm builds track the current
  PostgreSQL patch release, and the `17.2-N-bookworm` tags name the image build
  rather than the server, so a bookworm image pinned to an older patch does not
  exist.
- **Mind the patch version when upgrading.** TimescaleDB advises against
  PostgreSQL 17.1, 16.5, 15.9, 14.14, 13.17 and 12.21, which shipped a breaking
  binary interface change that was reverted in the following patch releases.
- **Switching a running cluster is close to one-way.** Changing `imageName`
  triggers a rolling restart ending in a switchover of the primary. Reverting
  works until the first hypertable exists; after that an image without the
  extension cannot read the data, and PostgreSQL does not downgrade a patch
  release in place either.
- **Versions are build args**, so another pairing needs no edit to the
  Dockerfile — though the TimescaleDB version must support the PostgreSQL major
  in the base image:

  ```bash
  docker build --platform linux/amd64 \
    --build-arg PG_MAJOR=17 \
    --build-arg TIMESCALE_VERSION=2.30.1 \
    --build-arg PG_IMAGE=ghcr.io/cloudnative-pg/postgresql:17-bookworm .
  ```

- CI builds and publishes on every push to `main`, builds without publishing on
  pull requests, and rebuilds weekly to pick up base image updates — which also
  fails loudly if a pinned package has been withdrawn.

## License

The wrapper is provided as-is. PostgreSQL is under the
[PostgreSQL License](https://www.postgresql.org/about/licence/); the
CloudNativePG operand images are **Apache-2.0**; TimescaleDB's Community
features are under the
[**Timescale License**](https://github.com/timescale/timescaledb/blob/main/tsl/LICENSE-TIMESCALE),
which permits self-hosting free of charge and restricts offering TimescaleDB as
a database-as-a-service to third parties.

*Postgres* and *PostgreSQL* are trademarks of the PostgreSQL Community
Association of Canada. *Timescale* and *TimescaleDB* are trademarks of
Timescale, Inc. *CloudNativePG* is a trademark of The CloudNativePG
Contributors. This project is not affiliated with, endorsed by, or sponsored by
any of them.

---

<sub>Crafted with care by [ndw.ai](https://ndw.ai/)</sub>
