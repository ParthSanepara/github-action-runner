#!/usr/bin/env bash
set -euo pipefail

# Exactly one auth method:
#   GITHUB_PAT            Personal access token — entrypoint mints a fresh
#                         registration token each start. Recommended for
#                         ephemeral runners. Scopes: repo→`repo`, org→`admin:org`.
#   RUNNER_TOKEN          Short-lived registration token from
#                         Settings → Actions → Runners → New runner (~1h, one-shot).
# Exactly one of:
#   GITHUB_REPOSITORY     "owner/repo" — registers as a repository runner.
#   GITHUB_ORG            "my-org"    — registers as an organization runner.
# Optional:
#   RUNNER_NAME           Defaults to the container hostname.
#   RUNNER_LABELS         Comma-separated extra labels (e.g. "self-hosted,linux,gpu").
#   RUNNER_GROUP          Org runner group (org scope only).
#   RUNNER_WORKDIR        Defaults to _work.

if [[ -n "${GITHUB_PAT:-}" && -n "${RUNNER_TOKEN:-}" ]]; then
    echo "Set GITHUB_PAT OR RUNNER_TOKEN, not both." >&2
    exit 1
fi
if [[ -z "${GITHUB_PAT:-}" && -z "${RUNNER_TOKEN:-}" ]]; then
    echo "Set either GITHUB_PAT (recommended) or RUNNER_TOKEN." >&2
    exit 1
fi

if [[ -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_ORG:-}" ]]; then
    echo "Set GITHUB_REPOSITORY OR GITHUB_ORG, not both." >&2
    exit 1
fi

if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    api_url="https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runners/registration-token"
    config_url="https://github.com/${GITHUB_REPOSITORY}"
elif [[ -n "${GITHUB_ORG:-}" ]]; then
    api_url="https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token"
    config_url="https://github.com/${GITHUB_ORG}"
else
    echo "Set either GITHUB_REPOSITORY or GITHUB_ORG." >&2
    exit 1
fi

runner_name="${RUNNER_NAME:-$(hostname)}"
runner_labels="${RUNNER_LABELS:-}"
runner_group="${RUNNER_GROUP:-}"
runner_workdir="${RUNNER_WORKDIR:-_work}"

if [[ -n "${GITHUB_PAT:-}" ]]; then
    echo "Minting registration token from ${api_url}"
    reg_token="$(curl -fsSL -X POST \
        -H "Authorization: Bearer ${GITHUB_PAT}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${api_url}" | jq -r .token)"

    if [[ -z "${reg_token}" || "${reg_token}" == "null" ]]; then
        echo "Failed to obtain registration token." >&2
        exit 1
    fi
else
    echo "Using supplied RUNNER_TOKEN (one-shot; container restart will fail once it expires)."
    reg_token="${RUNNER_TOKEN}"
fi

config_args=(
    --url "${config_url}"
    --token "${reg_token}"
    --name "${runner_name}"
    --work "${runner_workdir}"
    --unattended
    --replace
    --ephemeral
)
[[ -n "${runner_labels}" ]] && config_args+=(--labels "${runner_labels}")
[[ -n "${runner_group}" ]]  && config_args+=(--runnergroup "${runner_group}")

# Deregister on exit. With --ephemeral the runner self-removes after one job,
# but this also handles SIGTERM/SIGINT during idle waits.
cleanup() {
    echo "Removing runner registration..."
    ./config.sh remove --token "${reg_token}" || true
}
trap 'cleanup; exit 130' SIGINT SIGTERM

./config.sh "${config_args[@]}"
./run.sh & wait $!
