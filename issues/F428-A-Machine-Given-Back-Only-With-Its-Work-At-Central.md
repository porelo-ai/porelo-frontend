# F428 — A Machine Given Back Only With Its Work At Central

**Status:** Review.
**Size:** S - the `org status` reader (`lib/src/app/host_progress.dart`), the host's project rows, the give-back
dialog (`HostDialog` with `takeDownOnly` in `lib/src/ui/host_dialog.dart`) and their tests.

**What must be true.** A machine's page says for each repository it has taken how it stands with the central forge:
ahead with how many commits, at central, central moved on, or cannot say and why. Giving the machine back is refused
while any repository is ahead, central moved on, or it cannot say (except a repository with no central forge), and
the refusal names each. *Give it back anyway* is a second, separate decision.

## Why

In the trial move of 2026-11-07 the host's `org status` said `taken` for a repository whose main on the host's forge
held a merge that no central forge had. The give-back would have lost it. The operator decided that the give-back
stops on `ahead`, `moved-on` and `cannot-say`, except a repository without a central forge, in `porelo-host`'s
`down` and in the window alike, with *Give it back anyway*.

## Plan

- The contract (`porelo-host-person org status`, agreed in the room): each repository row whose `state` is `taken`
  carries `central`, one of `{"state":"ahead","commits":<n>}`, `{"state":"up-to-date"}`, `{"state":"moved-on"}`,
  `{"state":"cannot-say","why":"no-read-key|unreachable|no-central-main|local"}`. A row of another state carries
  none. A `taken` row without `central`, from an older host, reads as cannot say, never as at central. `why: local`
  is a repository with no central forge.
- `HostProjectProgress.repositories` keeps each row's central state, read field by field; an unknown `state` or
  `why` is shown as the host's word.
- The host's project rows (`lib/src/ui/organization_host_pages.dart`, where `taken` repositories are named) say
  beside each: "2 commits ahead of central", "at central", "central moved on", "cannot say: <why in words>".
- Before the give-back, the dialog asks the connected host's `org status` afresh. While any repository is ahead,
  moved-on or cannot-say (but `local`), *Return it* / *Take Porelo off* stays grey and the dialog names each
  repository with its state. *Give it back anyway* runs the existing give-back with `giveBackAnyway: true`, and says
  first that the work named is lost. A host not connected, or not answering, is a cannot-say too.
- Red first: a unit test reads a `taken` row with each `central` shape and one without; a widget test opens the
  give-back with one repository 2 commits ahead and expects the give-back grey, the repository named, and *Give it
  back anyway* sending `giveBackAnyway`.

## Acceptance

- A `taken` repository without `central` is shown as cannot say, and blocks the give-back.
- A repository ahead, moved-on or cannot-say (but `local`) blocks the give-back and is named with its state.
- *Give it back anyway* gives back with `--give-back-anyway`, after its own words; nothing else does.
- All repositories at central, or `local`, leave the give-back as it is today.

## Reading

- A project the machine reports `held`, with commits not yet pushed, blocks the give-back whatever its rows say, and a
  project state this window does not know reads as cannot say.
- Ahead by none, an empty reason and an empty state read as cannot say, never as blank words.
- A new read of the status after a failed return keeps the last answer while it waits, so a stalling host leaves the
  way to force it open.
- One forcing button stands at a time: *Give it back anyway* while a repository blocks, *Go on without a backup*
  otherwise.
- A repository carried here alone says its central state on its own row, not on a second one.
- Not changed: *Give it back anyway* stays open while the accounts are read. A stalled read of them must not close the
  way out, as an earlier test holds, and the forcing words say that what the accounts hold goes with the machine.

