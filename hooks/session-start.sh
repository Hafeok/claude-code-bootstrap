#!/usr/bin/env bash
# What every cloud session does at start, in whichever repository it was
# started in.
#
# 1. Signs commits with this environment's key (git-identity.sh).
# 2. Runs that repository's own setup, .claude/cloud-setup.sh, if it has one.
#
# The repository's script runs once per VM per repository: resume, clear and
# compact fire this hook again, and a marker file stops a second run. It runs as
# root, like the Setup script, so a script written for the Setup field (Varve's
# is) works here unchanged. It must be idempotent, and it must not fail loudly:
# a failure is reported and the session carries on.
#
# Unlike the Setup script, nothing done here is cached. Heavy installs a
# repository needs repeat in every new session; if that cost hurts, move them
# into a module of this repository, where they are cached for every environment.
#
# Its output goes to a log; only a one-line summary reaches the session, because
# a SessionStart hook's stdout becomes context.
set -u

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$here/git-identity.sh"

project="${CLAUDE_PROJECT_DIR:-$PWD}"
script="$project/.claude/cloud-setup.sh"
[ -f "$script" ] || exit 0

state=/var/tmp/claude-code-bootstrap
mkdir -p "$state"
id="$(printf '%s' "$project" | sha256sum | cut -c1-16)"
marker="$state/$id.done"
log="$state/$id.log"

[ -f "$marker" ] && exit 0

started=$(date +%s)
if (cd "$project" && bash "$script") > "$log" 2>&1; then
    touch "$marker"
    echo "repo-setup: .claude/cloud-setup.sh finished in $(( $(date +%s) - started ))s (log: $log)."
else
    echo "repo-setup: .claude/cloud-setup.sh failed after $(( $(date +%s) - started ))s; the session continues without it. Log: $log"
fi
exit 0
