# F158 — A Needs-You Row Names Its Machine And Its Way Out

**Status:** Backlog.
**Size:** M - one machine line and one way out on every row kind, and a list of what was resolved, kept for a set time.

**What must be true.** Every *Needs you* row names its machine in plain words and offers the action
that resolves it right on the row. A resolved row, and a message once read, does not vanish at
once: it stays a while, newest first, greyed but readable, its actions no longer clickable, a
longer text still opening on a click. How long it stays is a setting, an hour by default.

## Why

A *Needs you* row such as *Vault is locked* does not make clear whether it is for this computer or
for a server, shows only the state without the action that resolves it, and disappears at once when
cleared.

## Plan

- **Today**, read in the code: *Needs you* (`lib/src/ui/attention_view.dart`, fed by
  `lib/src/app/attention.dart`) draws nine kinds of rows. What each names and offers:

  | Row | Its machine | Its way out today |
  |---|---|---|
  | a machine not answering (`_MachineNotice`) | named | *Seen* only |
  | a project no longer followed (`_NotFollowing`) | named | *Take the rewritten history* |
  | a homeserver not reachable from here | named in the sentence | *Try again* |
  | messages waiting (`messages-wait`), e.g. the vault locked | in the title | **none** |
  | a machine that cannot list what is held (`messages-unlisted`) | as a prefix | **none** |
  | a message held for a person (`HeldMessageRow`) | named | read, then decide |
  | an authorization to grant (`AuthorizationRow`) | named | grant in a browser |
  | a failed operation (`_FailedOperation`) | named | *Open what it printed*, *Seen* |
  | a tile (a question, work at the gate, an outcome) | `tile-machine` | its own buttons; *Got it* |

- **One machine line on every row**, in the same place and words (*on <machine>*), so a row never
  has to be read whole to know where it is; the sentences that name the machine today lose it.
- **A way out on every row**, run against the row's own machine only:
  - *messages waiting* on a locked vault: *Unlock the vault on <machine>*, the same unlock that
    `work.unlock` runs (`lib/src/app/commands.dart`). Another reason gets no button the interface
    invents; which reason it is comes from the daemon, not from its words (open question 1);
  - *cannot list what is held*: *Ask again*;
  - *a machine not answering*: *Try again now* beside *Seen*.
- **What was resolved stays a while**, by the operator's rule of 2026-10-23: a row that goes away
  because it was resolved, a message once read, and a tile put away move into *Recently resolved*
  under the open rows, newest first. There each keeps its machine line and words, greyed by the
  theme's colour for disabled text, its buttons disabled, a longer text still opening on a click.
  It goes after the set time.
  - `Attention` keeps them in memory with the time each was resolved, on a clock the tests give.
    A row that comes back open leaves the list.
  - **The time is a setting**, *Keep resolved rows for*, in minutes, on the *Options* page. Its
    default is 60; 0 removes a row at once, as today.
- **Tests, their harm, red first:**
  - two machines each with a *messages waiting* row: each names its machine, and its unlock
    runs only on its own machine (the wrong machine unlocked, or a person sent to one with
    nothing locked);
  - a resolved row stays with its buttons disabled until the set time, then goes, on the test's
    clock (a resolved question that vanishes leaves no trace of what was decided);
  - 0 as the setting removes at once.
  - The greying and the order's look get no test.

## Open questions

1. **To Agent Core:** `Messages.waits` is the daemon's sentence. Does it come, or can it come,
   with a reason the interface can act on (`waitsOn: VAULT`, …), so the unlock is offered without
   reading the sentence? Without one, no button is offered on that row.

## Assumed, to be confirmed

- **Resolved rows do not survive a restart** of the interface: they are kept in memory only, since
  the machine still holds what was decided. The alternative: kept in the settings file until their
  time runs out. Asked of the operator as a deferred question on 2026-10-24.

## Acceptance

- Each *Needs you* row names its machine and offers a button or link that starts the resolving
  action on that machine.
- A resolved row and a read message stay greyed, newest first, their actions disabled, a longer
  text still opening on a click, and go after the set time; the setting's default is one hour.
- Seen to fail: when two machines each have a *Needs you* row, both name their own machine and each
  action runs only against its own machine.
