#!/usr/bin/env bash
# The whole "Setup script" field of a Claude Code cloud environment.
#
# Paste this into the field at claude.ai/code, changing only PROFILE (and REF
# when you release). It clones this repository at a pinned ref and hands over to
# setup.sh. Everything else lives in the repository, so every environment runs
# the same code and a change reaches an environment only when its REF moves.
#
# Pinned, not main: a bad push to main must not break every environment at
# once, and a session should be able to say which setup it ran.
#
# Never fails the session. Exit non-zero and the session does not start, so a
# failed clone is reported and the environment comes up unprovisioned instead.
set -u

PROFILE=default
REF=v1
REPO=https://github.com/Hafeok/claude-code-bootstrap
DIR=/opt/claude-profile

rm -rf "$DIR"
if git clone -q --depth 1 --branch "$REF" "$REPO" "$DIR"; then
    bash "$DIR/setup.sh" "$PROFILE"
else
    echo "claude-code-bootstrap: could not clone $REPO at $REF; this environment is unprovisioned" >&2
fi
exit 0
