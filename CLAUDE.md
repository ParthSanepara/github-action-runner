# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Docker image that runs as a **self-hosted GitHub Actions runner** on Linux. Not a GitHub Action — the container *is* the runner. Image is built from `actions/runner` releases on top of Ubuntu 24.04, registers itself on start, and is **ephemeral**: the runner exits after one job, the container restarts, and re-registers.

## Architecture

Three files form a startup contract — most changes touch more than one:

- `Dockerfile` — Ubuntu 24.04 + base tooling (git, curl, jq, sudo) + the `actions/runner` tarball pinned via `RUNNER_VERSION` (build arg). Runs as non-root `runner` user. `installdependencies.sh` from the runner tarball provides `libicu74` and friends; if you bump the base image, recheck that ICU package name. No Docker CLI inside — workflows that need it should reinstate the docker-ce-cli apt block and the socket mount in `docker-compose.yml` (they're a pair).
- `entrypoint.sh` — at container start: validates env, exchanges `GITHUB_PAT` for a short-lived **registration token** via the GitHub API (repo vs org endpoint chosen by which env var is set), runs `config.sh --ephemeral --replace --unattended`, then `run.sh`. A SIGTERM/SIGINT trap calls `config.sh remove` to deregister on graceful shutdown. `--ephemeral` makes `run.sh` exit after one job; `restart: always` in compose causes re-registration.
- `docker-compose.yml` — runtime wiring. Reads `.env` and uses `restart: always` to make the ephemeral loop work.

The PAT is **only** used at startup to mint the registration token; it is not persisted on the runner host or in the registered runner's config.

## Common commands

```bash
# First-time setup
cp .env.example .env  # then fill in GITHUB_PAT and GITHUB_REPOSITORY or GITHUB_ORG

# Build + run
docker compose up -d --build
docker compose logs -f runner

# Scale to N parallel runners (each registers with its own container hostname)
docker compose up -d --scale runner=4

# Rebuild after Dockerfile/entrypoint changes
docker compose build --no-cache && docker compose up -d

# Lint the entrypoint
shellcheck entrypoint.sh

# Quick build sanity check without compose
docker build --build-arg RUNNER_VERSION=2.334.0 -t github-action-runner .
```

## Gotchas

- **Repo XOR org**: setting both `GITHUB_REPOSITORY` and `GITHUB_ORG` is a fatal error in `entrypoint.sh` — they hit different API endpoints. Don't "helpfully" support both at once.
- **Ephemeral + restart**: `--ephemeral` is what makes the runner safe (clean workspace per job). Removing `restart: always` from compose without removing `--ephemeral` will leave you with a one-shot container that disappears after the first job.
- **Runner version**: pinned by `RUNNER_VERSION` build arg. GitHub auto-updates self-hosted runners at runtime; the pinned version is just the starting point. When bumping, also check the `actions/runner` release notes for new system deps.
- **Architecture**: `TARGETARCH` build arg is the actions/runner naming (`x64`, `arm64`), not Docker's (`amd64`, `arm64`). Don't blindly substitute `$TARGETPLATFORM`.
- **Non-root user**: the runner runs as `runner` (uid 1000). `RUNNER_ALLOW_RUNASROOT=0` is set deliberately — `config.sh` refuses to run as root without it.
