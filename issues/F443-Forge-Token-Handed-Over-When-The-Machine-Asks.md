# F443 — Forge Token Handed Over When The Machine Asks

**Status:** Accepted; blocked by the daemon's ask for it on the wire.
**Priority:** High, first among Accepted (the operator, 2026-11-09).
**Size:** S - one more way a start's answer and a build's detail are read, the host's command run in a terminal on
it as the store and import commands are, the machine asked again, and their tests; once the daemon says it.

**What must be true.** When a host needs the person's own forge token for its forge, to tell a task its builds or to
read them for the person, the window says so where the person is, offers the command the host names for making one,
and runs it in a terminal on that host; the work then goes on without a host shell. The token is made on the host by
the host's forge and stays in the person's vault there: it never passes through this program, its socket, a form, a
log or the person's clipboard.

## How it stands

- On a host, the person's forge token for the host's own forge is made by the host: `porelo-host-forge-token`, run in
  a shell on the host, has the forge make a token for the person's login and puts it into the person's vault there.
  Nobody types or sees it.
- Where it is missing, a task's start says so only in words, in the start's own output ("… which your vault does not
  hold; run porelo-host-forge-token on this host, then start the task again to be told its builds"); the task starts
  but is never told its builds. No answer on the wire says it as a reason or names the command.
- So today the person runs that command in an ssh shell on the host before the first start, as the fourth move's
  guide does.
- Not this issue: the token for the central forge that `porelo-host-push --central` asks for on its terminal; the
  person types that one there.

## Plan

1. The daemon names the ask, field by field, agreed in the channel first. One way that fits the wire as it stands:
   `CanStart`'s `CREDENTIAL_MISSING` (or a reason of its own) for the person's forge entry, with `credential` the vault
   key looked for and `storeCommand` the host's command, with nothing on its standard input; a build read for the
   person that lacks it says the same in its detail, with the command.
2. The window shows it in *New work*, the batch and a task's builds as it shows a missing credential today: the
   machine's sentence, and a button that runs the named command on that host in a terminal (over ssh in the login
   shell), then asks again. Where the daemon holds the start back, the start waits until the host says the entry is
   there; where it only warns, the start goes on and the warning stays beside it.
3. An older daemon: as today; the start goes on, and the window adds nothing.

## Acceptance

- A start on a host whose person's vault lacks the forge entry says which host and which forge, and offers the host's
  command; after it ran, the machine is asked again and says the entry is there.
- No token is shown, kept, logged, typed or sent over the socket by this program; the terminal shows only what the
  host's command prints.
- The command runs on the host the start is for, never on this computer and never on another machine.

## Open questions

- None; the operator accepted it on 2026-11-09.

## To be checked

- The daemon's ask, field by field, once agreed in the channel.
- What the host's command says when the person's vault is shut (today exit 65, "the vault refused the person's forge
  token; unlock it and retry") and when the person is not admitted yet (exit 69), and whether the window offers the
  vault's opening there as it does for a start.
