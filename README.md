# claude-code-bootstrap

One Setup script for every Claude Code cloud environment. Every environment's
"Setup script" field is the same one line:

```bash
curl -fsSL https://raw.githubusercontent.com/Hafeok/claude-code-bootstrap/v3/bootstrap.sh | bash -s v3
```

It fetches `bootstrap.sh`, which clones this repository at the same ref and
prepares what every session shares: the .NET SDK, Rust, the Azure CLI and Bicep,
and commit signing. A repository needs nothing of its own unless it wants more
than that; then it adds `.claude/cloud-setup.sh`, which runs at session start.

Generalized from Varve's `.claude/cloud-setup.sh` and
`.claude/hooks/cloud-git-identity.sh` (Varve ADR 0034, issue #79).

## How a session comes up

```
Setup script (bootstrap.sh)     root, before Claude Code, cached ~7 days
  └─ clone this repo at REF → /opt/claude-code-bootstrap
     └─ setup.sh
        ├─ base          ssh-keygen, jq
        ├─ dotnet        latest SDK of each channel in DOTNET_CHANNELS
        ├─ rust          rustup stable, clippy, rustfmt
        ├─ azure         az, bicep
        └─ claude-user   registers hooks/session-start.sh in ~/.claude/settings.json

Session start (hooks/session-start.sh)   every session, in its own repo
  ├─ git-identity.sh     sign commits with CLAUDE_GIT_SIGNING_KEY
  ├─ dotnet-pin.sh       install global.json's SDK if the cached ones don't satisfy it
  └─ <repo>/.claude/cloud-setup.sh       if the repo has one; once per VM
```

The repository's setup runs at session start, not in the Setup script, because
the Setup script may run before the repository is checked out. The cost of that:
session-start work is not cached, so it repeats in every new session.

## Layout

```
bootstrap.sh            piped from the Setup script; clones this repo at a ref, runs setup.sh
setup.sh                runs config.env's modules; guarded, never fails the run
config.env              modules, .NET channels, the agent's git identity
modules/<name>.sh       one shared provisioning step each
hooks/session-start.sh  SessionStart: signing, SDK pin, then the repo's own setup
hooks/git-identity.sh   writes the key and configures git to sign with it
hooks/dotnet-pin.sh     installs a repo's global.json SDK when nothing cached satisfies it
```

## Toolchains

Installed in the cached setup, so they cost nothing per session. The whole
setup measured 35s plus Rust's update, against the platform's five-minute limit.

- **.NET**: the latest SDK of each channel in `DOTNET_CHANNELS` (`10.0` now).
  A repository's `global.json` is honoured at session start: if no cached SDK
  satisfies it, `dotnet-pin.sh` installs exactly the pinned version (about 13s,
  repeated every session). A pin with the default `latestPatch` or
  `latestFeature` roll-forward is usually satisfied by the cached latest; Varve's
  10.0.401 resolves to 10.0.403. When a new major ships, add its channel
  (`DOTNET_CHANNELS="10.0 11.0"`) and release.
- **Rust**: stable with clippy and rustfmt, updating the rustup the sandbox
  already has. A `rust-toolchain.toml` needs nothing extra: rustup installs the
  toolchain it names on first use.
- **Azure**: `az` from Microsoft's apt repository and the standalone `bicep`
  binary on PATH, which `az bicep` is configured to use.

## A repository's own setup

Add `.claude/cloud-setup.sh` to the repository. It:

- runs as root, from the repository root, once per VM (resume, clear and
  compact do not run it again);
- must be idempotent and must not rely on failing: a non-zero exit is reported
  in one line and the session carries on;
- writes its output to `/var/tmp/claude-code-bootstrap/<id>.log`, and the
  session sees only `repo-setup: … finished in Ns` or `… failed`;
- has 15 minutes (the hook's timeout), but every second is paid at the start of
  every session. A heavy install many repositories need belongs in a module
  here instead, where it is cached.

Most repositories need none: the toolchains above cover them.

## Setting up an environment

1. At claude.ai/code, edit the environment and set **Setup script** to the
   one-liner at the top of this file.
2. Generate a signing key for this environment only:

   ```bash
   ssh-keygen -t ed25519 -N '' -C "claude-cloud <environment name>" -f claude-<environment>
   ```

3. Add the private key as the environment variable `CLAUDE_GIT_SIGNING_KEY`
   (the whole file, including the BEGIN/END lines).
4. Add `claude-<environment>.pub` on GitHub under **Settings → SSH and GPG keys →
   New SSH key**, key type **Signing Key**, on the account that owns
   `GIT_AGENT_EMAIL` (it must be a verified email there, or commits show as
   unverified).
5. Delete the local private key file. A lost key is replaced, not recovered.

A session should start with `git-identity: commits are signed as …` and, in a
repository with a setup script, `repo-setup: … finished`.

## Why one key per environment

Every environment shares this repository's code but not its key. A cloud
sandbox reads untrusted content all day; if one leaks, you revoke that one
public key on GitHub and the others keep signing. All commits still show as the
same verified identity, because the identity is the email, not the key.

The key is never written during setup: whatever `setup.sh` leaves on disk is
baked into the environment cache for days. The hook reads the variable fresh at
each session start.

## Releasing a change

Environments run a tag, not `main`:

```bash
git tag v4 && git push origin main v4
```

then change both refs in each environment's Setup script to `v4` (the URL
fetches `bootstrap.sh` at that ref; the argument clones the rest at it). Using
`main` in both places tracks main instead, as Varve's old one-liner did. Any edit to that field
forces the environment cache to rebuild, which is the only way a change here
reaches sessions. Roll one environment first and watch a session start before
moving the rest. A change to a repository's `.claude/cloud-setup.sh` needs none
of this: the next session runs it.

## Migrating Varve (and Writ, which carries a copy)

1. Replace the environment's Varve one-liner with this repository's. Varve's
   setup then runs only in Varve sessions, not in every session of the
   environment.
2. Delete `.claude/cloud-setup.sh`. Everything it does is covered: `base`
   installs ssh-keygen, and the cached .NET 10 SDK satisfies Varve's
   `global.json`. Kept, it would reinstall 10.0.401 in every session for
   nothing (about 18s).
3. Remove the SessionStart entry from Varve's `.claude/settings.json` and
   `.claude/hooks/cloud-git-identity.sh`. Leaving them is harmless (both hooks
   are idempotent and agree) but means two copies to keep in step.

## Things to verify on the first run

- **The repository is public.** `raw.githubusercontent.com` serves only public
  repositories without a token. If the setup log says `could not clone` or
  curl reports a 404, check the visibility and that the tag is pushed.
- **User settings persisting.** `claude-user` registers the hook in
  `~/.claude/settings.json` at setup time. If no `git-identity:` line appears at
  session start, sessions do not see that file; the fallback is a SessionStart
  hook in each repository calling
  `bash /opt/claude-code-bootstrap/hooks/session-start.sh`.
