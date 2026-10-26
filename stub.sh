#!/usr/bin/env bash
# The whole "Setup script" field of every Claude Code cloud environment.
#
# Identical in every environment: paste it in unchanged, and move REF when you
# release. It clones this repository at a pinned ref and runs setup.sh, which
# prepares what every session shares. The repository a session is started in
# brings its own setup, .claude/cloud-setup.sh, which the session-start hook
# runs once that repository is checked out.
#
# Pinned, not main: a bad push to main must not break every environment at
# once, and a session should be able to say which setup it ran.
#
# Never fails the session. Exit non-zero and the session does not start, so a
# failed clone is reported and the environment comes up unprovisioned instead.
set -u

REF=v1
REPO=https://github.com/Hafeok/claude-code-bootstrap
DIR=/opt/claude-code-bootstrap

rm -rf "$DIR"
if git clone -q --depth 1 --branch "$REF" "$REPO" "$DIR"; then
    bash "$DIR/setup.sh"
else
    echo "claude-code-bootstrap: could not clone $REPO at $REF; this environment is unprovisioned" >&2
fi
exit 0
