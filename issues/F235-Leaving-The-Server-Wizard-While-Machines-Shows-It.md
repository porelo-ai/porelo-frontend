# F235 — Leaving The Server Wizard While Machines Shows It

**Status:** Idea. Held as an Idea (operator, 2026-10-30, after walk 23): wizard changes wait until he has gone through the whole flow again.
**Size:** XS - Finish usable once the server is being prepared, closing to Machines with no question; Leave the same.

**What must be true.** In *Prepare a server…*, once *Prepare the server* has started, *Finish* on Step 7 of 7 is clickable. It closes the wizard at once without a question, and the interface shows *Machines*, where the server stands as "in preparation". A stop on the way (*Complete setup on <host>*) then opens from the shell, not from the wizard. *Leave* does the same from that moment.

## Why

Operator's finding in walk 23, step 2-7 (2026-10-30): he clicked *Finish* during the rental and it did nothing; it was disabled with "Wait for the action to answer." *Finish* must be clickable once preparing has started, close the wizard at once without a question and go to *Machines*, which shows the progress. Today the shared frame (`lib/src/ui/wizard.dart`, `_reason`) disables *Finish* while the action runs or waits, and *Leave* asks "Leave this wizard? The action is unfinished and may keep running…" (`_confirm`).

## Plan

- The wizard frame takes, per wizard, that a started action is shown elsewhere; *Prepare a server…* says so (*Machines*). For such a wizard, once the action started, *Finish* is enabled while it runs or waits, and *Finish* and *Leave* both close at once, with no question, and show *Machines*.
- The host's run goes on after the wizard closed. A stop it reaches opens from the shell, as on reopening today.
- Before the action started, *Leave* still asks when values were given ("The values you gave will be dropped."). Other wizards keep today's *Finish* and question.
- **Red first:** a widget test that *Finish* on Step 7 of 7 during the rental is enabled, closes the wizard with no dialog, and *Machines* shows the server in preparation; and that a stop reached after closing opens from the shell.

## Acceptance

- During the rental, *Finish* closes the wizard without a question, and *Machines* shows the server in preparation; *Leave* does the same.
- *Complete setup on <host>* opens from the shell when the run reaches it.

Built together with [F233](README.md#f233); one estimate and one VM test for the three, written there.
