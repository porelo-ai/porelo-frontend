# F435 — A Machine Taken Down Leaves The List

**Status:** Review.
**Size:** S - after a confirmed take-down the window asks the organization to remove the machine, as its question
promised, and a refusal stands in the take-down's protocol.

**What must be true.** When *Take Porelo off this machine…* was answered with removing the machine from the
organization's list, and the machine confirmed it is down, the window sends `org host remove` for it. Its row leaves
the organization's list. Where the organization refuses, the take-down's protocol says so with the refusal's words, and
the row keeps *Remove the machine…*.

## Why

[F430](README.md#f430), found after the push of 2026-11-07: after a confirmed down the window only forgot the machine on
this computer, so porelo-move stayed listed and carried what it carried. The operator decided it is built before the
third trial move (2026-11-08).

## Plan

- `openHostTakeDownDialog` (the take-down's dialog) answers whether the machine confirmed down and whether the person
  asked for its removal from the list.
- `lib/src/ui/shell.dart` `_takeDown`: on both, `Organization.write(OrganizationChange.removeHost, {'host': …})`; the
  refusal's words into the run's protocol.
- The question's words go back to promising the removal.
- Red first: a confirmed down with removal asked sends one `removeHost`; without removal asked, or without a confirmed
  down, none; a refusal is in the protocol and the row still offers *Remove the machine…*.

## Acceptance

- A machine taken down with its removal asked leaves the organization's list.
- A refusal is said in the protocol, and the row keeps *Remove the machine…*.
