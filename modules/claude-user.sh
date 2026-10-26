#!/usr/bin/env bash
# Registers this repository's hooks in the user-level Claude Code settings, so
# they run in every repository, not only ones that carry their own copy.
#
# Merges rather than overwrites: ~/.claude/settings.json may already hold
# settings the platform or the user put there. Re-running adds nothing twice.
#
# The SessionStart entry has no matcher, so it runs on startup, resume, clear
# and compact alike. Varve's repo-level hook matched "startup" only and a
# resumed session lost its signing config (Varve #88); the hook is idempotent,
# so running it every time costs nothing.
set -u

root="${1:?usage: claude-user.sh <profile-root>}"
settings="$HOME/.claude/settings.json"
command="bash $root/hooks/git-identity.sh"

if ! command -v jq >/dev/null 2>&1; then
    echo "claude-user: jq is missing; the base module installs it" >&2
    exit 1
fi

mkdir -p "$(dirname "$settings")"
[ -s "$settings" ] || echo '{}' > "$settings"

merged="$(mktemp)"
if jq --arg cmd "$command" '
    .hooks.SessionStart = (
        (.hooks.SessionStart // [])
        | map(select(any(.hooks[]?; .command == $cmd) | not))
        + [{ hooks: [{ type: "command", command: $cmd }] }]
    )' "$settings" > "$merged"; then
    mv "$merged" "$settings"
else
    rm -f "$merged"
    echo "claude-user: $settings is not valid JSON; left it alone" >&2
    exit 1
fi

echo "claude-user: SessionStart -> $command in $settings"
