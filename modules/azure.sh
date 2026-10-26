#!/usr/bin/env bash
# Azure CLI and the Bicep CLI.
#
# az from Microsoft's apt repository (the documented install for Ubuntu). Bicep
# as the standalone binary in /usr/local/bin rather than `az bicep install`,
# which puts it under ~/.azure and only behind az. az finds a bicep on PATH when
# it is configured to (use_binary_from_path), so both `bicep build` and
# `az bicep build` use the same binary.
set -u

if ! command -v az >/dev/null 2>&1; then
    curl -fsSL https://aka.ms/InstallAzureCLIDeb | bash > /dev/null || exit 1
fi

curl -fsSL -o /usr/local/bin/bicep \
    https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 \
    && chmod +x /usr/local/bin/bicep \
    || exit 1

az config set bicep.use_binary_from_path=true --only-show-errors > /dev/null 2>&1 || true
az config set core.collect_telemetry=false --only-show-errors > /dev/null 2>&1 || true

az version --query '"azure-cli"' -o tsv | sed 's/^/az /'
bicep --version
