#!/usr/bin/env bash
# Entry point for every Claude Code cloud environment's "Setup script" field:
#
#   curl -fsSL https://raw.githubusercontent.com/Hafeok/claude-code-bootstrap/v1/bootstrap.sh | bash -s v1
#
# The ref appears twice on purpose: the URL fetches this file at that ref, and
# the argument makes it clone the rest of the repository at the same ref. Use
# main in both places to track main instead, as Varve's one-liner did.
#
# This file arrives on its own through a pipe, so it fetches the rest of the
# repository and hands over to setup.sh. raw.githubusercontent.com serves only
# public repositories without a token, so this one is public; nothing in it is
# secret.
#
# Never fails the session. Exit non-zero and the session does not start, so a
# failed clone is reported and the environment comes up unprovisioned instead.
set -u

REF="${1:-main}"
REPO="${BOOTSTRAP_REPO:-https://github.com/Hafeok/claude-code-bootstrap}"
DIR=/opt/claude-code-bootstrap

rm -rf "$DIR"
if git -c advice.detachedHead=false clone -q --depth 1 --branch "$REF" "$REPO" "$DIR"; then
    bash "$DIR/setup.sh"
else
    echo "claude-code-bootstrap: could not clone $REPO at $REF; this environment is unprovisioned" >&2
fi
exit 0
