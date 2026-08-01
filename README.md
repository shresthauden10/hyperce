# my-shop

This project was generated with [`@vendure/create`](https://github.com/vendurehq/vendure/tree/master/packages/create).

Useful links:

- [Vendure docs](https://www.vendure.io/docs)
- [Vendure Discord community](https://www.vendure.io/community)
- [Vendure on GitHub](https://github.com/vendurehq/vendure)
- [Vendure plugin template](https://github.com/vendurehq/plugin-template)

## Directory structure

* `/src` contains the source code of your Vendure server. All your custom code and plugins should reside here.
* `/static` contains static (non-code) files such as assets (e.g. uploaded images) and email templates.

## Development

```
npm run dev
```

will start the Vendure server, [worker](https://www.vendure.io/docs/developer-guide/vendure-worker/) and Dashboard.

## Build

```
npm run build
```

will compile the TypeScript sources and build the Dashboard into the `/dist` directory.

## Production

For production, there are many possibilities which depend on your operational requirements as well as your production
hosting environment.

### Running directly

You can run the built files directly with the `start` script:

```
npm run start
```

You could also consider using a process manager like [pm2](https://pm2.keymetrics.io/) to run and manage
the server & worker processes.

### Using Docker

We've included a sample [Dockerfile](./Dockerfile) which you can build with the following command:

```
docker build -t vendure .
```

This builds an image and tags it with the name "vendure". We can then run it with:

```
# Run the server
docker run -dp 3000:3000 -e "DB_HOST=host.docker.internal" --name vendure-server vendure npm run start:server

# Run the worker
docker run -dp 3000:3000 -e "DB_HOST=host.docker.internal" --name vendure-worker vendure npm run start:worker
```

Here is a breakdown of the command used above:

- `docker run` - run the image we created with `docker build`
- `-dp 3000:3000` - the `-d` flag means to run in "detached" mode, so it runs in the background and does not take
control of your terminal. `-p 3000:3000` means to expose port 3000 of the container (which is what Vendure listens
on by default) as port 3000 on your host machine.
- `-e "DB_HOST=host.docker.internal"` - the `-e` option allows you to define environment variables. In this case we
are setting the `DB_HOST` to point to a special DNS name that is created by Docker desktop which points to the IP of
the host machine. Note that `host.docker.internal` only exists in a Docker Desktop environment and thus should only be
used in development.
- `--name vendure-server` - we give the container a human-readable name.
- `vendure` - we are referencing the tag we set up during the build.
- `npm run start:server` - this last part is the actual command that should be run inside the container.

### Docker Compose

We've included a [docker-compose.yml](./docker-compose.yml) file which includes configuration for commonly-used
services such as PostgreSQL, MySQL, MariaDB, Elasticsearch and Redis.

To use Docker Compose, you will need to have Docker installed on your machine. Here are installation
instructions for [Mac](https://docs.docker.com/desktop/install/mac-install/), [Windows](https://docs.docker.com/desktop/install/windows-install/),
and [Linux](https://docs.docker.com/desktop/install/linux/).

You can start the services with:

```shell
docker-compose up <service>

# examples:
docker-compose up postgres_db
docker-compose up redis
```

## Plugins

In Vendure, your custom functionality will live in [plugins](https://www.vendure.io/docs/plugins/).
These should be located in the `./src/plugins` directory.

To create a new plugin run:

```
npx vendure add
```

and select `[Plugin] Create a new Vendure plugin`.

## Migrations

[Migrations](https://www.vendure.io/docs/developer-guide/migrations/) allow safe updates to the database schema. Migrations
will be required whenever you make changes to the `customFields` config or define new entities in a plugin.

To generate a new migration, run:

```
npx vendure migrate
```

The generated migration file will be found in the `./src/migrations/` directory, and should be committed to source control.
Next time you start the server, and outstanding migrations found in that directory will be run by the `runMigrations()`
function in the [index.ts file](./src/index.ts).

If, during initial development, you do not wish to manually generate a migration on each change to customFields etc, you
can set `dbConnectionOptions.synchronize` to `true`. This will cause the database schema to get automatically updated
on each start, removing the need for migration files. Note that this is **not** recommended once you have production
data that you cannot lose.

---

You can also run any pending migrations manually, without starting the server via the "vendure migrate" command.

---

## CI/CD Pipeline

This repo uses four GitHub Actions workflows:

- **[`ci.yaml`](./.github/workflows/ci.yaml)** — runs on every PR into `main`. Three parallel jobs: builds the app (`npm ci && npm run build`), lints and validates the Helm chart (`helm lint` + render + dry-run apply against a `kind` cluster), and builds the production Docker image without pushing it.
- **[`docker-publish.yml`](./.github/workflows/docker-publish.yml)** — runs on push to `main`. Builds the production image, scans it with [Trivy](https://trivy.dev) (fails the build on CRITICAL/HIGH CVEs not listed in [`.trivyignore`](./.trivyignore)), pushes it to `ghcr.io/<owner>/hyperce`, and signs it keylessly with [cosign](https://github.com/sigstore/cosign).
- **[`deploy-compose.yaml`](./.github/workflows/deploy-compose.yaml)** — runs after `docker-publish.yml` succeeds on `main`. Checks out the triggering commit, ships the repo's [`docker-compose.prod.yml`](./docker-compose.prod.yml) to the production server over SSH, and runs `docker compose pull && up -d` there.
- **[`deploy-k8s.yaml`](./.github/workflows/deploy-k8s.yaml)** — manual (`workflow_dispatch`), so it doesn't fire on every `main` push alongside the Compose deploy. Runs against the **same server** as the Compose deploy, over the same SSH secrets. First SSH session: transfers and runs [`scripts/bootstrap-server.sh`](./scripts/bootstrap-server.sh), which idempotently installs Docker, kind, kubectl, and Helm (skipping anything already present). Second, fresh SSH session (needed so a just-added `docker` group membership actually takes effect): creates a local `kind` cluster named `vendure` if one doesn't exist yet, installs the `ingress-nginx` controller for kind if missing, renders app secrets and the GHCR pull secret from GitHub Actions secrets, then applies the manifests in [`k8s/`](./k8s) with `kubectl` in order: namespace → service account/config → secrets → Postgres (waits for it to be ready) → migration Job (waits for completion, deletes+recreates the Job each run since Job specs are immutable) → app Deployment/Service/Ingress (waits for rollout). Run it from the **Actions** tab, optionally passing an `image_tag` input; it defaults to `sha-<HEAD commit>`.

### Required GitHub Actions secrets

| Secret | Purpose | Used by |
| --- | --- | --- |
| `SSH_HOST`, `SSH_USER`, `SSH_PORT`, `SSH_PRIVATE_KEY` | SSH access to the deploy server (shared by both workflows) | `deploy-compose.yaml`, `deploy-k8s.yaml` |
| `GHCR_USER`, `GHCR_PAT` | Pulling the image from GHCR | `deploy-compose.yaml`, `deploy-k8s.yaml` |
| `DB_USERNAME`, `DB_PASSWORD`, `COOKIE_SECRET`, `SUPERADMIN_USERNAME`, `SUPERADMIN_PASSWORD` | Rendered into the `vendure-secrets` Kubernetes Secret at deploy time | `deploy-k8s.yaml` |

Unlike the Compose path (where these values live in a `.env` file created once by hand on the server), the Kubernetes pipeline injects them fresh from GitHub secrets on every run — nothing sensitive needs to be pre-staged on the cluster.

The SSH user needs **passwordless sudo** on the server — `bootstrap-server.sh` uses it for `apt-get`/installing binaries to `/usr/local/bin`. No cloud Kubernetes account or kubeconfig secret is needed: the cluster is a local `kind` cluster living in Docker on the same box, created on first run.

### Server prerequisites

The deploy workflow writes `docker-compose.prod.yml` to `/opt/vendure-shop` on every run (creating the directory if it doesn't exist), but it does **not** manage runtime secrets. Before the first deploy, create `/opt/vendure-shop/.env` on the server (filename must be exactly `.env` for Compose to auto-load it) containing:

```
DB_USERNAME=...
DB_PASSWORD=...
COOKIE_SECRET=...
SUPERADMIN_USERNAME=...
SUPERADMIN_PASSWORD=...
```

(see [`.env.production`](./.env.production) locally for the full set of keys used by the app — do not commit this file).

### Kubernetes alternative

A [Helm chart](./helm/vendure) is included and validated in CI (`helm lint` + render + dry-run apply). It's the source of truth for the manifest shape — the static files in [`k8s/`](./k8s) mirror its rendered output and are what [`deploy-k8s.yaml`](./.github/workflows/deploy-k8s.yaml) actually applies with `kubectl`. If you change the Helm chart, re-render and update the `k8s/` files to match (`helm template vendure ./helm/vendure ... > /tmp/out.yaml`, then copy the relevant resources over) so the two don't drift.

## Running the project

### Locally

**Option A — Node directly**, against a Postgres container:

```shell
docker compose up postgres -d      # starts Postgres on localhost:6543
npm ci
npm run dev                        # server + worker + dashboard, reads ./.env
```

**Option B — everything in Docker**:

```shell
docker compose up                  # app (hot-reloading) + Postgres
```

Both read config from [`.env`](./.env) (gitignored — copy the keys documented in the [Migrations](#migrations) section / `.env.production` below and fill in your own values). The app is served at `http://localhost:3000`.

### In the cloud

**Docker Compose (default production path):** push to `main` — `docker-publish.yml` builds/scans/signs the image, then `deploy-compose.yaml` ships [`docker-compose.prod.yml`](./docker-compose.prod.yml) to the server over SSH and runs `docker compose up -d`. See [Server prerequisites](#server-prerequisites) above. No manual CLI steps needed once the secrets are configured.

**Kubernetes (via the CI pipeline):** from the **Actions** tab, run **Deploy to Kubernetes** (`deploy-k8s.yaml`) against `main` (or any branch/tag), after configuring the secrets listed above. This is the recommended way to deploy to a k8s cluster — it's what keeps the `image_tag`, migration ordering, and rollout waits consistent.

**Kubernetes (manual `kubectl`/`helm`, e.g. for a first-time cluster setup or local `kind` testing):**

```shell
# Point kubectl at your cluster first (kubeconfig, `aws eks update-kubeconfig`, `doctl kubernetes cluster kubeconfig save`, etc.)
kubectl config current-context

# Optional: spin up a local cluster for testing
kind create cluster --config kind-cluster.yaml

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/serviceaccount.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/assets-pvc.yaml

# GHCR pull secret (or use your own `ghcr-secret.yaml`, gitignored)
kubectl create secret docker-registry ghcr-secret \
  --namespace vendure --docker-server=ghcr.io \
  --docker-username=<gh-username> --docker-password=<gh-pat>

# App secrets: copy k8s/vendure-secrets.templates.yaml, fill in real values, apply it
# (or use values.secrets.yaml with Helm — see below)
kubectl apply -f k8s/secret.yaml

kubectl apply -f k8s/postgres-statefulset.yaml
kubectl apply -f k8s/migration-job.yaml   # replace ${IMAGE_TAG:-latest} with a real tag first
kubectl apply -f k8s/deployment.yaml      # same
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

Or via Helm, using the chart directly:

```shell
helm upgrade --install vendure ./helm/vendure \
  --namespace vendure --create-namespace \
  -f values.secrets.yaml \
  --set image.tag=<image-tag>
```

## Troubleshooting

### Error: Could not load the "sharp" module using the \[OS\]-x\[Architecture\] runtime when running Vendure server.

- Make sure your Node version is ^18.17.0 || ^20.3.0 || >=21.0.0 to support the Sharp library.
- Make sure your package manager is up to date.
- **Not recommended**: if none of the above helps to resolve the issue, install sharp specifying your machines OS and Architecture. For example: `pnpm install sharp --config.platform=linux --config.architecture=x64` or `npm install sharp --os linux --cpu x64`
