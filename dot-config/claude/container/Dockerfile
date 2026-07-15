# Claude Code container image, built and run by ./cclaude.
#
# The host username, uid, and home dir are baked in at build time so bind
# mounts keep their host paths and ownership inside the container - the
# config dir, workspace, and stow symlink targets all resolve exactly as on
# the host. CLAUDE_VERSION mirrors the host CLI (cclaude build reads it from
# `claude --version`) so host and container never drift apart.
FROM node:22-bookworm-slim

ARG CLAUDE_VERSION
ARG HOST_USER
ARG HOST_UID
ARG HOST_HOME

RUN test -n "$CLAUDE_VERSION" && test -n "$HOST_USER" \
    && test -n "$HOST_UID" && test -n "$HOST_HOME"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        fd-find \
        git \
        jq \
        less \
        openssh-client \
        procps \
        ripgrep \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "$(command -v fdfind)" /usr/local/bin/fd

# prettier is the one dependency the shared PostToolUse hooks invoke without
# a guard; the terraform and tmux hooks silence themselves when their tools
# are absent.
RUN npm install -g prettier "@anthropic-ai/claude-code@${CLAUDE_VERSION}"

# Bind-mounted repos trip git's dubious-ownership check under virtiofs even
# with matching uids; this is a single-user container, so the check buys
# nothing here.
RUN git config --system safe.directory '*'

RUN useradd --uid "$HOST_UID" --user-group --create-home \
    --home-dir "$HOST_HOME" --shell /bin/bash "$HOST_USER"

COPY entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh

ENV CLAUDE_CONFIG_DIR=${HOST_HOME}/.config/claude

USER $HOST_USER
ENTRYPOINT ["/entrypoint.sh"]
