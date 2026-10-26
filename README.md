# claude-code-bootstrap

One setup for every Claude Code cloud environment. Each environment's "Setup
script" field is a ten-line stub that clones this repository at a pinned ref and
runs one named profile. The toolchain, the hooks and the agent's git identity
live here, once.

Generalized from Varve's `.claude/cloud-setup.sh` and
`.claude/hooks/cloud-git-identity.sh` (Varve ADR 0034, issue #79).

## Layout

```
stub.sh                 the Setup script field, verbatim (set PROFILE and REF)
setup.sh                runs as root before the session; loads a profile, runs its modules
profiles/_defaults.env  values every profile starts from (modules, agent identity)
profiles/<name>.env     one per kind of environment; overrides the defaults
modules/<name>.sh       one provisioning step each; guarded, never fails the run
hooks/git-identity.sh   SessionStart hook: signs commits with the environment's key
```

## Setting up an environment

1. At claude.ai/code, edit the environment and paste `stub.sh` into **Setup
   script**, with `PROFILE` set (`default`, `varve`, …).
2. Generate a signing key for this environment only:

   ```bash
   ssh-keygen -t ed25519 -N '' -C "claude-cloud <environment name>" -f claude-<environment>
   ```

3. Add the private key as the environment variable `CLAUDE_GIT_SIGNING_KEY`
   (the whole file, including the BEGIN/END lines).
4. Add `claude-<environment>.pub` on GitHub under **Settings → SSH and GPG keys →
   New SSH key**, key type **Signing Key**, on the account that owns
   `GIT_AGENT_EMAIL` (`claude+emil@okkels-klein.dk` must be a verified email
   there, or commits show as unverified).
5. Delete the local private key file. The environment is now its only home; a
   lost key is replaced, not recovered.

The first session should print `git-identity: commits are signed as …` with the
key's fingerprint, and `git log --show-signature -1` after a commit should show
a good signature.

## Why one key per environment

Every environment shares this repository's code but not its key. A cloud
sandbox reads untrusted content all day; if one leaks, you revoke that one
public key on GitHub and the others keep signing. Commits still all show as the
same verified identity, because the identity is the email, not the key.

The key is never written during setup. Whatever `setup.sh` leaves on disk is
baked into the environment cache for days; the hook reads the variable fresh at
each session start instead.

## Releasing a change

Environments run a tag, not `main`. To roll out:

```bash
git tag v2 && git push origin v2
```

then bump `REF` in each environment's Setup script. Any edit to that field also
forces the environment cache to rebuild, which is the only way a setup change
reaches sessions. Roll one environment first and watch a session start before
moving the rest.

## Adding a profile or module

- **Profile:** add `profiles/<name>.env`. Set `MODULES` and whatever variables
  its modules read. Unknown profiles fall back to `default`.
- **Module:** add `modules/<name>.sh`. It receives the repository root as `$1`
  and the profile's variables in its environment. Exit non-zero to report
  failure; `setup.sh` logs it and carries on. Mind the five-minute budget for
  the whole run.

Repository-specific setup that must also run locally belongs in that
repository's own SessionStart hook, not here.

## Migrating Varve

1. Point Varve's environment at this stub with `PROFILE=varve`.
2. Remove `.claude/cloud-setup.sh` from Varve.
3. Remove the SessionStart entry from Varve's `.claude/settings.json` and
   `.claude/hooks/cloud-git-identity.sh`. Leaving them in is harmless (both
   hooks are idempotent and agree) but means two copies to keep in step.
4. Keep `profiles/varve.env`'s `DOTNET_SDK_VERSION` in step with Varve's
   `global.json` and devcontainer.

## Things to verify on the first run

- **The private clone at setup time.** The stub clones with plain `git`. If
  the setup phase has no GitHub credentials for this repository, the clone
  fails and the session starts unprovisioned (it says so in the setup log).
  Nothing here is secret, so the simplest fix is to make this repository
  public.
- **User settings persisting.** `claude-user.sh` registers the hook in
  `~/.claude/settings.json` at setup time. If sessions start with a home
  directory that does not carry it, no `git-identity:` line appears at session
  start. The fallback is a one-line SessionStart hook in each repository
  calling `bash /opt/claude-profile/hooks/git-identity.sh`.
