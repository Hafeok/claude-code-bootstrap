#!/usr/bin/env bash
# Prepares a Claude Code cloud VM with what every session shares.
#
# Runs as root on a fresh Ubuntu VM, before Claude Code launches, once per
# environment cache (about seven days). Two platform rules shape every line:
# exit non-zero and the session does not start; take longer than about five
# minutes and nothing is cached. So every module is guarded, reports, and never
# fails the run.
#
# Nothing repository-specific happens here: the repository a session is started
# in may not be checked out yet. Its own setup runs at session start
# (hooks/session-start.sh). Secrets never pass through here either: whatever
# this script writes is baked into the environment cache, so keys are read at
# session start from the environment's variables.
set -u
export DEBIAN_FRONTEND=noninteractive

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

set -a
# shellcheck source=config.env
. "$root/config.env"
set +a

echo "claude-code-bootstrap: $(git -C "$root" describe --tags --always 2>/dev/null || echo unknown)"

# What the session-time hooks need. Not secret.
{
    printf 'CLAUDE_BOOTSTRAP_ROOT=%q\n' "$root"
    printf 'GIT_AGENT_NAME=%q\n' "$GIT_AGENT_NAME"
    printf 'GIT_AGENT_EMAIL=%q\n' "$GIT_AGENT_EMAIL"
} > /etc/claude-code-bootstrap.env

failed=""
for module in $MODULES; do
    echo "--- $module"
    script="$root/modules/$module.sh"
    if [ ! -f "$script" ]; then
        echo "$module: no such module" >&2
        failed="$failed $module"
    elif ! bash "$script" "$root"; then
        echo "$module: failed; the session starts without it" >&2
        failed="$failed $module"
    fi
done

echo "--- done: $MODULES"
[ -z "$failed" ] || echo "--- failed:$failed" >&2
exit 0
