# claude-code-bootstrap

One Setup script for every Claude Code cloud environment. Every environment's
"Setup script" field is the same ten-line stub: it clones this repository at a
pinned tag and prepares what every session shares. The repository a session is
started in brings its own setup in `.claude/cloud-setup.sh`, which runs at
session start.

Generalized from Varve's `.claude/cloud-setup.sh` and
`.claude/hooks/cloud-git-identity.sh` (Varve ADR 0034, issue #79).

## How a session comes up

```
Setup script (stub.sh)          root, before Claude Code, cached ~7 days
  └─ clone this repo at REF → /opt/claude-code-bootstrap
     └─ setup.sh
        ├─ base          ssh-keygen, jq
        └─ claude-user   registers hooks/session-start.sh in ~/.claude/settings.json

Session start (hooks/session-start.sh)   every session, in its own repo
  ├─ git-identity.sh     sign commits with CLAUDE_GIT_SIGNING_KEY
  └─ <repo>/.claude/cloud-setup.sh       if the repo has one; once per VM
```

The repository's setup runs at session start, not in the Setup script, because
the Setup script may run before the repository is checked out. The cost of that:
session-start work is not cached, so it repeats in every new session.

## Layout

```
stub.sh                 the Setup script field, verbatim, for every environment
setup.sh                runs config.env's modules; guarded, never fails the run
config.env              modules to run and the agent's git identity
modules/<name>.sh       one shared provisioning step each
hooks/session-start.sh  SessionStart: signing, then the repo's own setup
hooks/git-identity.sh   writes the key and configures git to sign with it
```

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

Varve's existing `.claude/cloud-setup.sh` already fits this contract unchanged.

## Setting up an environment

1. At claude.ai/code, edit the environment and paste `stub.sh` into **Setup
   script**.
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
git tag v2 && git push origin v2
```

then bump `REF` in each environment's Setup script. Any edit to that field
forces the environment cache to rebuild, which is the only way a change here
reaches sessions. Roll one environment first and watch a session start before
moving the rest. A change to a repository's `.claude/cloud-setup.sh` needs none
of this: the next session runs it.

## Migrating Varve

1. Point Varve's environment at this stub.
2. Keep `.claude/cloud-setup.sh`: it now runs at session start instead.
   Optionally update its header comment, which describes the old curl one-liner.
3. Remove the SessionStart entry from Varve's `.claude/settings.json` and
   `.claude/hooks/cloud-git-identity.sh`. Leaving them is harmless (both hooks
   are idempotent and agree) but means two copies to keep in step.

## Things to verify on the first run

- **The private clone at setup time.** The stub clones with plain `git`. If
  the setup phase has no GitHub credentials for this repository, the setup log
  says `could not clone` and the session starts unprovisioned. Nothing here is
  secret, so the simplest fix is to make this repository public.
- **User settings persisting.** `claude-user` registers the hook in
  `~/.claude/settings.json` at setup time. If no `git-identity:` line appears at
  session start, sessions do not see that file; the fallback is a SessionStart
  hook in each repository calling
  `bash /opt/claude-code-bootstrap/hooks/session-start.sh`.
