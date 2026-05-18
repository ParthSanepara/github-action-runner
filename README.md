# github-action-runner

[![Docker Pulls](https://img.shields.io/docker/pulls/parthsanepara/github-action-runner.svg)](https://hub.docker.com/r/parthsanepara/github-action-runner)
[![Docker Image Size](https://img.shields.io/docker/image-size/parthsanepara/github-action-runner/latest)](https://hub.docker.com/r/parthsanepara/github-action-runner)
[![Docker Image Version](https://img.shields.io/docker/v/parthsanepara/github-action-runner?sort=semver)](https://hub.docker.com/r/parthsanepara/github-action-runner/tags)
[![GHCR](https://img.shields.io/badge/ghcr.io-parthsanepara%2Fgithub--action--runner-blue?logo=github)](https://github.com/parthsanepara/github-action-runner/pkgs/container/github-action-runner)
[![Platforms](https://img.shields.io/badge/platform-linux%2Famd64%20%7C%20linux%2Farm64-lightgrey)](https://hub.docker.com/r/parthsanepara/github-action-runner/tags)

A Docker image that runs as a self-hosted [GitHub Actions runner](https://docs.github.com/en/actions/hosting-your-own-runners) on Linux. Ephemeral by default — the runner picks up one job, exits, and is re-registered on container restart.

Published to:

- **Docker Hub** — [`parthsanepara/github-action-runner`](https://hub.docker.com/r/parthsanepara/github-action-runner)
- **GitHub Container Registry** — `ghcr.io/parthsanepara/github-action-runner`

Multi-arch: `linux/amd64`, `linux/arm64`.

## Quick start (pull from a registry)

You don't need to build anything — just pull the published image.

### 1. Get an auth token

Use one of:

- **GitHub PAT (recommended)** — classic PAT with `repo` scope (repo runner) or `admin:org` (org runner). Auto-renews on every container restart.
- **Registration token** — one-shot, from your repo/org → **Settings → Actions → Runners → New runner**. Expires in ~1 hour.

### 2. Run it

**Docker Hub:**

```bash
docker run -d --restart=always \
  --name gha-runner \
  -e GITHUB_PAT=ghp_yourtokenhere \
  -e GITHUB_REPOSITORY=owner/repo \
  parthsanepara/github-action-runner:latest
```

**GitHub Container Registry:**

```bash
docker run -d --restart=always \
  --name gha-runner \
  -e GITHUB_PAT=ghp_yourtokenhere \
  -e GITHUB_REPOSITORY=owner/repo \
  ghcr.io/parthsanepara/github-action-runner:latest
```

For org-wide runners, replace `GITHUB_REPOSITORY` with `GITHUB_ORG=my-org`.

### 3. Verify

```bash
docker logs -f gha-runner
```

Then check **GitHub → Settings → Actions → Runners** — the runner should appear as **Idle**.

## docker-compose example

Create `.env`:

```
GITHUB_PAT=ghp_yourtokenhere
GITHUB_REPOSITORY=owner/repo
```

Create `compose.yml`:

```yaml
services:
  runner:
    image: parthsanepara/github-action-runner:latest   # or ghcr.io/parthsanepara/...
    restart: always
    env_file: .env
```

Start:

```bash
docker compose up -d
docker compose logs -f runner
```

## Pulling a specific version

```bash
docker pull parthsanepara/github-action-runner:1.0.0
docker pull ghcr.io/parthsanepara/github-action-runner:1.0.0
```

Tags follow the **image release version**, not the underlying actions/runner version. See [Releases](https://github.com/parthsanepara/github-action-runner/releases) for the mapping.

## Pulling from GHCR (private repos)

The image is public, no auth needed. If you fork and publish a private version, you'd authenticate first:

```bash
echo $CR_PAT | docker login ghcr.io -u <your-github-user> --password-stdin
```

Where `CR_PAT` is a GitHub PAT with `read:packages` scope.

## Configuration

All settings are environment variables.

| Variable | Required | Default | Notes |
|----------|----------|---------|-------|
| `GITHUB_PAT` | one of | — | PAT — auto-renews registration token each restart. |
| `RUNNER_TOKEN` | one of | — | One-shot registration token from GitHub UI. |
| `GITHUB_REPOSITORY` | one of | — | `owner/repo` for a repo-scoped runner. |
| `GITHUB_ORG` | one of | — | Org slug for an org-scoped runner. |
| `RUNNER_NAME` | no | container hostname | Display name in GitHub Runners UI. |
| `RUNNER_LABELS` | no | `self-hosted,linux` | Comma-separated extras, e.g. `gpu,large`. |
| `RUNNER_GROUP` | no | — | Org runner group (org scope only). |
| `RUNNER_WORKDIR` | no | `_work` | Job checkout directory inside the container. |

## Scaling

Run N parallel runners with compose:

```bash
docker compose up -d --scale runner=4
```

Each container registers with its own unique name (defaults to container hostname).

Or with plain `docker run`, give each container a unique `--name`:

```bash
for i in 1 2 3 4; do
  docker run -d --restart=always \
    --name gha-runner-$i \
    -e GITHUB_PAT=$GITHUB_PAT \
    -e GITHUB_REPOSITORY=owner/repo \
    parthsanepara/github-action-runner:latest
done
```

## Building locally

Only needed if you're modifying the image.

```bash
docker build -t github-action-runner .
```

Multi-arch build:

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t github-action-runner .
```

See [DEPLOYMENT.md](./DEPLOYMENT.md) for the full local-dev workflow and [`.env.example`](./.env.example) for every supported setting.

## Releasing

Releases are cut via the **Release** workflow (`.github/workflows/release.yml`) — go to **Actions → Release → Run workflow**, supply a semver version, and it publishes to both registries.

## Contributing

Contributions are welcome! A few ground rules:

1. **Open an issue first** for anything non-trivial (new feature, behavior change, base-image bump) — saves rework if the approach needs discussion.
2. **One change per PR.** Keep diffs focused; refactors belong in their own PR.
3. **Local sanity check** before pushing:
   ```bash
   docker build -t github-action-runner:dev .
   shellcheck entrypoint.sh
   ```
4. **Update docs** when changing user-visible behavior — `README.md`, `DEPLOYMENT.md`, and `.env.example` should stay in sync.
5. **Bumping the actions/runner version?** Update `RUNNER_VERSION` *and* both `RUNNER_SHA256_AMD64` / `RUNNER_SHA256_ARM64` in `Dockerfile`. See the bottom of [CLAUDE.md](./CLAUDE.md) for the one-liner.

For bug reports, please include: image tag, `docker version`, host OS, and the full `docker logs` output (redact tokens).
