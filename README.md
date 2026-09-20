# PostgreSQL + TimescaleDB container images for CloudNativePG

CloudNativePG operand images with the TimescaleDB extension installed, built
so they can be used as a drop-in `imageName` in a CloudNativePG `Cluster`.

These images are built **on top of** the official
[CloudNativePG operand images](https://github.com/cloudnative-pg/postgres-containers),
adding a single package. Everything the operator expects — its entrypoint,
its instance manager, its backup and recovery hooks, the `postgres` UID — is
inherited unchanged from the base.

## Supported tags

```
ghcr.io/bayertemo/ndw-postgres-timescaledb:latest
ghcr.io/bayertemo/ndw-postgres-timescaledb:<commit-sha>
```

| | |
| --- | --- |
| PostgreSQL | 17 (bookworm) |
| TimescaleDB | 2.30.1 |
| Edition | Community |
| Platform | `linux/amd64` |

`latest` follows `main`. Pin a `<commit-sha>` tag where a reproducible image
is required.

## Edition

The **Community** edition is installed, not `-oss`.

Both editions provide hypertables. Only Community provides compression,
continuous aggregates and retention policies. `CREATE EXTENSION` succeeds
under either, so an `-oss` package substituted by mistake is not otherwise
visible; each build therefore asserts that `SHOW timescaledb.license` returns
`timescale`.

The Timescale License permits self-hosting without charge. It restricts
offering TimescaleDB as a database-as-a-service to third parties.

## PostgreSQL versions

Bookworm-based images are used. The bullseye-based operand images are end of
life: their Debian security pocket has moved to archive, and `apt-get install`
inside them fails with 404 on packages the index still advertises, so no
extension can be layered onto them.

Bookworm builds track the current PostgreSQL patch release. The
`17.2-N-bookworm` tags identify the image build rather than the server
version, so a bookworm image pinned to an older patch is not available.

> **NOTE:** TimescaleDB advises against PostgreSQL 17.1, 16.5, 15.9, 14.14,
> 13.17 and 12.21, which introduced a breaking binary interface change that
> was reverted in the following patch releases.

## Usage

`timescaledb` must be present in `shared_preload_libraries`. Declare it in the
`Cluster` spec rather than in the image: CloudNativePG manages
`postgresql.conf` and regenerates it from the spec on every reconciliation.

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: example
spec:
  instances: 3
  imageName: ghcr.io/bayertemo/ndw-postgres-timescaledb:latest
  postgresql:
    shared_preload_libraries:
      - timescaledb
```

Then, in each database:

```sql
CREATE EXTENSION timescaledb;
```

The package is public; no `imagePullSecret` is required.

> **IMPORTANT:** Changing `imageName` on a running cluster triggers a rolling
> restart, ending in a switchover of the primary. Reverting is possible until
> the first hypertable is created; after that, an image without the extension
> cannot read the data. PostgreSQL does not support downgrading a patch
> release in place.

## Building images

```sh
docker build --platform linux/amd64 \
  --build-arg PG_MAJOR=17 \
  --build-arg TIMESCALE_VERSION=2.30.1 \
  --build-arg PG_IMAGE=ghcr.io/cloudnative-pg/postgresql:17-bookworm \
  -t ndw-postgres-timescaledb .
```

All three are build arguments, so other pairings can be built without editing
the Dockerfile. The TimescaleDB version must support the PostgreSQL major
version in the base image.

Images are built and published on every push to `main`, built without
publishing on pull requests, and rebuilt weekly to pick up base image updates.
Each build starts the resulting image and verifies that the extension loads,
a hypertable can be created, compression can be enabled, and the edition is
Community.

## License and copyright

The contents of this repository are distributed under the Apache License 2.0.

The images include software distributed under its own terms:

- PostgreSQL — [PostgreSQL License](https://www.postgresql.org/about/licence/)
- TimescaleDB — [Timescale License](https://github.com/timescale/timescaledb/blob/main/tsl/LICENSE-TIMESCALE)
- CloudNativePG operand images — [Apache License 2.0](https://github.com/cloudnative-pg/postgres-containers/blob/main/LICENSE)

## Trademarks

*Postgres* and *PostgreSQL* are trademarks or registered trademarks of the
PostgreSQL Community Association of Canada, and used with their permission.
*Timescale* and *TimescaleDB* are trademarks of Timescale, Inc. *CloudNativePG*
is a trademark of The CloudNativePG Contributors. This project is not
affiliated with, endorsed by, or sponsored by any of them.
