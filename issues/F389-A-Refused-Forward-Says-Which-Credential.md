# F389 — A Refused Forward Says Which Credential

**Status:** Backlog.
**Size:** M - a led path in the window on daemon calls not there yet: words, a list of keys, a try, a keep.

**What must be true.** A push refused for its key leads the person through it in the window, with no need to read git's raw line, which does not appear.

1. It says in plain words what happened and which key was used, by fingerprint and what the forge calls it, such as a deploy key; or that no credential is declared for the address.
2. It lists the person's keys, from the ssh-agent, so also from an open KeePassXC, and from files, reading no secret. Beside them: a key not listed? Open KeePassXC, unlock it, refresh.
3. *Try* tests one key alone, by a `git push --dry-run` with only that key, and writes nothing.
4. One click keeps that key for that address and forwards again.
5. For what only a terminal can do, the window opens a terminal with the whole command ready, and the person starts it.

The rule beyond this case: every credential's failure says what happened and what to do now, with a control for it.

## Why

A real test showed `'git --git-dir ... push --end-of-options git@github.com:<organization>/<repository>.git ...' failed with exit code 128: ERROR: Permission to <organization>/<repository>.git denied to deploy key`. No credential was declared for that address, so ssh chose by itself and offered a key the forge knows as a deploy key without that right. A person who reads only that error has nothing to go on; Porelo leads them through it.

## Plan

- Agree the contract in the room with Agent Core: the refusal's words and the key it used, the list of keys, the dry run, and naming one key of the agent for an address. Today a declaration cannot name one key of the agent, so the wrong key would still win.
- Build the window's path on those calls, on a machine that has them, and say plainly on one that has not.
- Split it into smaller issues if the contract shows parts that stand alone.

## Acceptance

- A refused push with no credential for its address says so; one with a credential says which key, by fingerprint and the forge's word for it.
- The person's keys are listed from the agent and from files, and no secret is read or shown; a key added by unlocking KeePassXC appears on refresh.
- *Try* on a key writes nothing upstream, and says what the forge answered.
- Keeping a key forwards again with that key alone.
- What only a terminal can do opens one with the command ready, and does not start it.
- No git command line reaches the window for this refusal.

## Decided while building

## Open questions

- Whether a terminal can be opened the same way on each desktop and on Windows, and what the window says where it cannot.

## To be checked
