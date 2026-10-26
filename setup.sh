#!/usr/bin/env bash
# Provisions a Claude Code cloud VM from a named profile.
#
#   bash setup.sh <profile>
#
# Runs as root on a fresh Ubuntu VM, before Claude Code launches, once per
# environment cache (about seven days). Two platform rules shape every line:
# exit non-zero and the session does not start; take longer than about five
# minutes and nothing is cached. So every module is guarded, reports, and never
# fails the run, and the session-time hooks check for what they need.
#
# Secrets never pass through here. Whatever this script writes is baked into the
# environment cache, so keys are read at session start from the environment's
# variables (hooks/git-identity.sh), never at setup time.
set -u
export DEBIAN_FRONTEND=noninteractive

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
profile="${1:-default}"

if [ ! -f "$root/profiles/$profile.env" ]; then
    echo "claude-cloud-profile: no profile '$profile'; using 'default'" >&2
    profile=default
fi

# Defaults first, then the profile overrides them. Exported so modules see them.
set -a
# shellcheck source=profiles/_defaults.env
. "$root/profiles/_defaults.env"
# shellcheck disable=SC1090
. "$root/profiles/$profile.env"
set +a

echo "claude-cloud-profile: profile '$profile' at $(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)"

# What the session-time hooks need to know about this profile. Not secret.
{
    printf 'CLAUDE_PROFILE=%q\n' "$profile"
    printf 'CLAUDE_PROFILE_ROOT=%q\n' "$root"
    printf 'GIT_AGENT_NAME=%q\n' "$GIT_AGENT_NAME"
    printf 'GIT_AGENT_EMAIL=%q\n' "$GIT_AGENT_EMAIL"
} > /etc/claude-profile.env

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

echo "--- done: profile '$profile', modules: $MODULES"
[ -z "$failed" ] || echo "--- failed:$failed" >&2
exit 0
