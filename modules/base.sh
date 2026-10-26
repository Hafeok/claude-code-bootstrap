#!/usr/bin/env bash
# Packages every profile needs and the sandbox may lack.
#
# openssh-client: ssh-keygen, which git needs to sign with an SSH key. The
#   sandbox shipped without it when Varve measured it (2026-10-09).
# jq: claude-user.sh merges into ~/.claude/settings.json with it.
set -u

missing=""
command -v ssh-keygen >/dev/null 2>&1 || missing="$missing openssh-client"
command -v jq >/dev/null 2>&1 || missing="$missing jq"

if [ -n "$missing" ]; then
    # shellcheck disable=SC2086
    apt-get update -qq && apt-get install -y -qq $missing >/dev/null || exit 1
fi

command -v ssh-keygen >/dev/null 2>&1 && echo "ssh-keygen: $(command -v ssh-keygen)"
command -v jq >/dev/null 2>&1 && echo "jq: $(command -v jq)"
exit 0
