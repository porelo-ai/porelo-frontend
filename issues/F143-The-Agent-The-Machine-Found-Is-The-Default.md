# F143 — The Agent The Machine Found Is The Default

**Status:** Idea; blocked by `porelo` [B225](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b225).

**What must be true.** A person who starts work without picking an agent gets the one the machine
chooses, as `porelo-project` [PJ53](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj53)
and the command line choose it, and sees which it is and why; the picker shows which agents are
signed in on the machine, and an agent found there but not in the vault is offered for import.

## The shape

- **No agent is filled in here.** The start form sends none until the person picks one; the
  `standardAgent` default in `lib/src/app/start_work.dart` goes, and `ready` no longer needs an agent
  where the machine can choose.
- **The machine's choice is shown from `StartCheck`**: `Readiness.agent` with `agentSource` and
  `agentFoundIn`, worded here; an unknown source is said as it comes.
- **Several agents**: under `SEVERAL_AGENTS` the picker lists `signedIn` first and asks, as today.
- **The picker marks each agent** by `Agents`' `found` (`SIGNED_IN`, `NOT_SIGNED_IN`, `CANNOT_SAY`),
  its provider and paths; `CANNOT_SAY` never reads as signed out.
- **The import** is offered by the daemon's `importCommand`, run in the sign-in terminal; nothing
  here composes it.
- **An older machine answers none of these fields**; there the form needs an agent picked, as
  today, rather than guessing one.
