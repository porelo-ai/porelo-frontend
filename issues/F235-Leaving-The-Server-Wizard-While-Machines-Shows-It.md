# F235 — Leaving The Server Wizard While Machines Shows It

**Status:** Accepted.
**Size:** XS - Leave asks nothing once the server is being prepared, as Finish does.

**What must be true.** In *Prepare a server…*, once *Prepare the server* has started, *Leave* closes the wizard at once without a question, as *Finish* does, and the interface shows *Machines*, where the server stands as "in preparation" with its progress.

## Why

Operator's finding in walk 23, step 2-7 (2026-10-30): *Finish* closes the wizard at once, without a question, while the host is still being prepared, and the interface goes to *Machines*, where the server shows as "in preparation". "The confirmation that Leave asks today is not needed, because Machines shows the progress." Today *Leave* asks "Leave this wizard? The action is unfinished and may keep running…" (`lib/src/ui/wizard.dart`, `_confirm`).

## Plan

- The wizard frame takes, per wizard, that a started action is shown elsewhere; *Prepare a server…* says so (Machines). For such a wizard, *Leave* after the action started does what *Finish* does: close and show *Machines*, without the question.
- Before the action started, *Leave* still asks when values were given ("The values you gave will be dropped."). Other wizards keep today's question.
- **Red first:** a widget test that *Leave* on Step 7 of 7 during the rental closes the wizard with no dialog and *Machines* shows the server in preparation.

## Acceptance

- During the rental, *Leave* closes the wizard without a question and *Machines* shows the server in preparation.
- *Finish* behaves as today.

Built together with [F233](README.md#f233) and [F234](README.md#f234), which change the same wizard.
