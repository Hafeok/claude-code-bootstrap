#!/usr/bin/env bash
# Makes the SDK a repository's global.json asks for available.
#
#   bash dotnet-pin.sh <project-dir>
#
# The cached setup installs the latest SDK of each configured channel, which
# satisfies most global.json files. When it does not (a pin to an older feature
# band, or a channel the setup does not install), this installs exactly the
# pinned version next to the others. That install is not cached: it repeats in
# every new session until the channel list in config.env covers it.
#
# Quiet when there is nothing to do, so it costs one `dotnet --version` on every
# session start, resume, clear and compact.
set -u

project="${1:?usage: dotnet-pin.sh <project-dir>}"
[ -f "$project/global.json" ] || exit 0

if ! command -v dotnet >/dev/null 2>&1; then
    echo "dotnet-pin: global.json is present but dotnet is not installed; the dotnet module installs it."
    exit 0
fi

# Exits non-zero when no installed SDK satisfies global.json.
(cd "$project" && dotnet --version > /dev/null 2>&1) && exit 0

# global.json may hold comments, which jq rejects; fall back to the first
# "version" key, which in practice is sdk.version.
want="$(jq -r '.sdk.version // empty' "$project/global.json" 2>/dev/null)"
[ -n "$want" ] || want="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$project/global.json" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"

if [ -z "$want" ]; then
    echo "dotnet-pin: no installed SDK satisfies global.json and no sdk.version could be read from it."
    exit 0
fi

installer=/usr/local/share/dotnet-install.sh
log=/var/tmp/claude-code-bootstrap/dotnet-$want.log
mkdir -p "$(dirname "$log")"
started=$(date +%s)

{ [ -f "$installer" ] || curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer"; } \
    && bash "$installer" --version "$want" --install-dir /usr/share/dotnet > "$log" 2>&1

if (cd "$project" && dotnet --version > /dev/null 2>&1); then
    echo "dotnet-pin: installed SDK $want for global.json in $(( $(date +%s) - started ))s. Add its channel to config.env's DOTNET_CHANNELS to cache it."
else
    echo "dotnet-pin: SDK $want for global.json is still unavailable after an install attempt; see $log."
fi
exit 0
