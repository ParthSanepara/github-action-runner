FROM ubuntu:24.04

ARG RUNNER_VERSION=2.334.0
# TARGETARCH is provided automatically by `docker buildx` (values: amd64, arm64, ...).
# Per-arch SHA-256 sums for the runner tarball. Update these when bumping
# RUNNER_VERSION — published on https://github.com/actions/runner/releases
ARG RUNNER_SHA256_AMD64=048024cd2c848eb6f14d5646d56c13a4def2ae7ee3ad12122bee960c56f3d271
ARG RUNNER_SHA256_ARM64=f44255bd3e80160eb25f71bc83d06ea025f6908748807a584687b3184759f7e4
ARG TARGETARCH=amd64

ENV DEBIAN_FRONTEND=noninteractive \
    RUNNER_ALLOW_RUNASROOT=0 \
    RUNNER_VERSION=${RUNNER_VERSION}

# Base tools the runner and most workflows need.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        libicu74 \
        sudo \
        tar \
        unzip \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Non-root user the runner executes as.
RUN useradd -m -s /bin/bash runner \
    && usermod -aG sudo runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner

# Install the GitHub Actions runner.
# Map Docker's TARGETARCH (amd64/arm64) → actions/runner naming (x64/arm64)
# and pick the matching checksum.
WORKDIR /home/runner
RUN case "${TARGETARCH}" in \
        amd64) runner_arch="x64";   runner_sha="${RUNNER_SHA256_AMD64}" ;; \
        arm64) runner_arch="arm64"; runner_sha="${RUNNER_SHA256_ARM64}" ;; \
        *)     echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL -o runner.tar.gz \
        "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${runner_arch}-${RUNNER_VERSION}.tar.gz" \
    && echo "${runner_sha}  runner.tar.gz" | sha256sum -c - \
    && tar xzf runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && chown -R runner:runner /home/runner

COPY --chown=runner:runner entrypoint.sh /home/runner/entrypoint.sh
RUN chmod +x /home/runner/entrypoint.sh

USER runner
ENTRYPOINT ["/home/runner/entrypoint.sh"]
