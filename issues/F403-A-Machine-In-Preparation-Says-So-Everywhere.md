# F403 — A Machine In Preparation Says So Everywhere

**Status:** Review.
**Size:** S - the organization's machine row and machine page take the preparation *My machines* already holds, and
a small mark of a preparation's state beside its words, the same in each place.

**What must be true.** While this computer prepares a machine of the organization, its row on the organization's page
and its machine page say so - its state, since when and on which address - offer its protocol as the main button,
and offer no second start; and a row in preparation, there and under *My machines*, shows a small mark of its state.

## Why

The operator's walk on the rehearsal VM (2026-11-06): after *Prepare* was closed while it ran, the organization's row
of the machine still offered *Prepare this machine…* and said it had no address, though the preparation ran on
192.168.122.241 and the dialog had promised that its machine row opens the protocol again. *My machines* showed it
right, but in a row that looked like any other.

## Plan

- `lib/src/ui/machines_page.dart`: `hostPreparationWords` (the state's word, before private) and
  `HostPreparationMark`: a small turning ring while it works, a person where it waits for one, a warning where it was
  interrupted, as the leading mark of the preparation's row.
- `lib/src/ui/organization_page.dart`, `lib/src/ui/organization_host_pages.dart`: `preparing` and `onProtocol`; the
  machine row then shows the mark, "In preparation since 17:36 on 192.168.122.241", and *Open the protocol* in place of
  *Prepare this machine…*; the machine page offers the protocol in place of a second start.
- `lib/src/ui/shell.dart`: both take the preparation from `HostRuns` by the machine's name, and are read again as a
  preparation starts and ends.
- **The test that goes red first:** `test/ui/organization_page_test.dart`, a machine in preparation offers no
  *Prepare this machine…*, names its address, and its button opens the running protocol. It guards a second
  preparation started beside one that already runs on the server.

## Found in the reading

- A stopped run - refused, unreachable, or not run yet - turned and said "In preparation" as if it worked: it says
  "Stopped" with a pause mark, and the organization's row adds what stopped it.
- Without a way to open the protocol, the row and the page fell back to *Prepare this machine…* beside the run: while
  it is prepared, no second start is offered at all.
- The machine page left out since when and where, and said nothing to a reader who is not its Machine Admin: it says
  "This computer prepares it" with both, to whoever reads the page here.
- Declined: a protocol reopened from the row does not redraw the stopped run's line and its buttons until it is
  opened again; that is the dialog's behaviour from before, not this issue's, and is filed apart if it bites.

## Acceptance

- Closing *Prepare* while it runs leaves the organization's row and page saying it runs, with its protocol a press away.
- A preparation's row shows its state at a glance under *My machines* and on the organization's page.
