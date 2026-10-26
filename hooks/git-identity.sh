#!/usr/bin/env bash
# Cloud sessions sign their commits with this environment's agent key.
#
# Generalized from Varve's .claude/hooks/cloud-git-identity.sh (Varve ADR 0034).
#
# A cloud sandbox starts with a fresh home directory and no key the user
# controls. This hook runs at session start, only in the cloud, and only when
# the environment carries the key in CLAUDE_GIT_SIGNING_KEY: it writes the key,
# then makes git author, commit and sign as the agent identity config.env names
# (/etc/claude-code-bootstrap.env, written by setup.sh). Called by session-start.sh.
#
# One key per environment, not one shared key: each environment's variables
# hold its own private key, and every public half is registered as a signing
# key on GitHub. A leak from one sandbox is revoked without touching the rest.
#
# A local session is left alone: it signs with the user's own key. A cloud
# session without the variable is left alone too, and says so, rather than
# failing the session. Safe to run any number of times.
set -u

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

# shellcheck disable=SC1091
[ -f /etc/claude-code-bootstrap.env ] && . /etc/claude-code-bootstrap.env
name="${GIT_AGENT_NAME:-Claude (Emil)}"
email="${GIT_AGENT_EMAIL:-claude+emil@okkels-klein.dk}"

if [ -z "${CLAUDE_GIT_SIGNING_KEY:-}" ]; then
    echo "git-identity: CLAUDE_GIT_SIGNING_KEY is not set in this environment; commits are unsigned." >&2
    exit 0
fi

if ! command -v ssh-keygen >/dev/null 2>&1; then
    echo "git-identity: ssh-keygen is missing, which git needs for SSH signing; commits are unsigned. The base module installs it." >&2
    exit 0
fi

key="$HOME/.ssh/claude-signing"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
umask 077
printf '%s\n' "$CLAUDE_GIT_SIGNING_KEY" > "$key"

if ! ssh-keygen -y -f "$key" > "$key.pub" 2>/dev/null; then
    rm -f "$key" "$key.pub"
    echo "git-identity: CLAUDE_GIT_SIGNING_KEY is not a readable, unencrypted private key; commits are unsigned." >&2
    exit 0
fi

git config --global user.name "$name"
git config --global user.email "$email"
git config --global gpg.format ssh
git config --global user.signingkey "$key"
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# Lets git verify what it signs. Without it every signed commit prints "error:
# gpg.ssh.allowedSignersFile needs to be configured" and `%G?` reports N even
# for a good signature. Trusts only this environment's own key.
printf '%s namespaces="git" %s\n' "$email" "$(cat "$key.pub")" > "$HOME/.ssh/allowed_signers"
git config --global gpg.ssh.allowedSignersFile "$HOME/.ssh/allowed_signers"

echo "git-identity: commits are signed as $name <$email> with $(ssh-keygen -lf "$key.pub" | cut -d' ' -f2)."
