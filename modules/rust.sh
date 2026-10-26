#!/usr/bin/env bash
# Rust stable, with clippy and rustfmt.
#
# The sandbox image already carries rustup under ~/.cargo; this updates stable
# rather than installing a second copy, and installs rustup only when it is
# absent. A repository's rust-toolchain.toml needs nothing from here: rustup
# installs the toolchain it names on first use.
set -u

export PATH="$HOME/.cargo/bin:$PATH"

if ! command -v rustup >/dev/null 2>&1; then
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain none > /dev/null \
        || exit 1
fi

rustup toolchain install stable --profile minimal --component clippy,rustfmt --no-self-update > /dev/null \
    || exit 1
rustup default stable > /dev/null

rustc --version
cargo --version
