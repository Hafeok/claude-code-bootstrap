#!/usr/bin/env bash
# The latest .NET SDK of each channel in DOTNET_CHANNELS (config.env).
#
# The platform documents the .NET SDK as not pre-installed. Installing the
# latest of a channel here, where it is cached, covers most repositories:
# global.json's default rollForward (latestPatch) accepts a newer patch in the
# same feature band. A repository pinned to an SDK this does not satisfy gets
# exactly that SDK at session start (hooks/session-start.sh), uncached.
set -u

channels="${DOTNET_CHANNELS:-10.0}"
dotnet_root=/usr/share/dotnet
installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT

curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer" || exit 1

failed=0
for channel in $channels; do
    echo "dotnet: latest SDK of channel $channel"
    bash "$installer" --channel "$channel" --install-dir "$dotnet_root" > /dev/null \
        || { echo "dotnet: channel $channel failed" >&2; failed=1; }
done

ln -sf "$dotnet_root/dotnet" /usr/bin/dotnet

# Kept for later installs: the session-start hook uses it for global.json pins.
cp "$installer" /usr/local/share/dotnet-install.sh

cat > /etc/profile.d/dotnet.sh <<PROFILE
export DOTNET_ROOT=$dotnet_root
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
PROFILE

dotnet --list-sdks
exit "$failed"
