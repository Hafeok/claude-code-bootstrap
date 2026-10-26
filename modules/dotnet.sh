#!/usr/bin/env bash
# The .NET SDK at exactly DOTNET_SDK_VERSION.
#
# The platform documents the .NET SDK as not pre-installed. The version comes
# from the profile, not from the repository's global.json, because the
# repository may not be cloned yet when this runs.
set -u

if [ -z "${DOTNET_SDK_VERSION:-}" ]; then
    echo "dotnet: the profile sets no DOTNET_SDK_VERSION" >&2
    exit 1
fi

dotnet_root=/usr/share/dotnet

if ! "$dotnet_root/dotnet" --list-sdks 2>/dev/null | grep -q "^$DOTNET_SDK_VERSION "; then
    installer="$(mktemp)"
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer" \
        && bash "$installer" --version "$DOTNET_SDK_VERSION" --install-dir "$dotnet_root" \
        && ln -sf "$dotnet_root/dotnet" /usr/bin/dotnet
    status=$?
    rm -f "$installer"
    [ "$status" -eq 0 ] || exit 1
fi

cat > /etc/profile.d/dotnet.sh <<PROFILE
export DOTNET_ROOT=$dotnet_root
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
PROFILE

dotnet --list-sdks
