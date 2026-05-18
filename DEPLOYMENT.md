# Deployment Guide

Get a self-hosted GitHub Actions runner up in ~5 minutes.

## Prerequisites

- Docker + Docker Compose installed (`docker --version`, `docker compose version`)
- A GitHub repo or org where you can add a self-hosted runner
- One of:
  - A **Personal Access Token** (recommended) — auto-renews, runner can restart forever
  - A **registration token** — one-shot, expires in ~1 hour

## 1. Get your auth token

### Option A — PAT (recommended)

1. Go to https://github.com/settings/tokens
2. **Generate new token (classic)** with scope:
   - Repo runner: `repo`
   - Org runner: `admin:org`
3. Copy the `ghp_...` value.

### Option B — Registration token (one-shot)

1. Go to your repo → **Settings → Actions → Runners → New self-hosted runner**.
2. Copy the token from the `./config.sh --token <TOKEN>` line (starts with `A...`).
3. Use it within 1 hour.

## 2. Configure

```bash
cp .env.example .env
nano .env   # or your editor of choice
```

Fill in **one** of `GITHUB_PAT` or `RUNNER_TOKEN`, and confirm `GITHUB_REPOSITORY` (or switch to `GITHUB_ORG`).

Verify it's there:

```bash
ls -la .env
```

## 3. Build & start

```bash
docker compose up -d --build
```

## 4. Watch the logs

```bash
docker compose logs -f runner
```

You should see:

```
√ Connected to GitHub
√ Runner successfully added
Listening for Jobs
```

Then check **github.com/<owner>/<repo> → Settings → Actions → Runners** — your runner should appear as **Idle**.

## 5. Run more runners in parallel

```bash
docker compose up -d --scale runner=4
```

Each container registers with its own name (container hostname).

## Day-to-day commands

| Goal | Command |
|------|---------|
| Tail logs | `docker compose logs -f runner` |
| Restart | `docker compose restart runner` |
| Stop | `docker compose down` |
| Stop and remove image | `docker compose down --rmi local` |
| Rebuild after Dockerfile change | `docker compose up -d --build` |
| Shell into container | `docker compose exec runner bash` |
| See container status | `docker compose ps` |

## Updating the runner version

Edit `Dockerfile`:

```dockerfile
ARG RUNNER_VERSION=2.334.0
ARG RUNNER_SHA256=<new-sha-from-release-page>
```

Get the new SHA from https://github.com/actions/runner/releases, then rebuild:

```bash
docker compose up -d --build
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Set either GITHUB_PAT (recommended) or RUNNER_TOKEN` | `.env` is missing or both vars are blank |
| `Failed to obtain registration token` | PAT lacks scope, expired, or repo path is wrong |
| Runner registers then disappears immediately | Expected with `--ephemeral` after a job finishes; container will restart and re-register |
| `unauthorized` from GitHub API | Regenerate PAT, make sure it has `repo` (or `admin:org`) |
| Runner doesn't appear in GitHub UI | Check `docker compose logs runner` for errors; confirm `GITHUB_REPOSITORY` matches `owner/repo` exactly |

## Uninstalling

```bash
docker compose down --rmi local --volumes
rm .env
```

Also remove the runner from **GitHub → Settings → Actions → Runners** (the entrypoint deregisters on graceful shutdown, but stale entries can appear after force kills).
