# F234 — No Back Once The Server Is Being Prepared

**Status:** Idea. Held: wizard changes wait until the whole flow has been gone through again.
**Size:** S - the wizard frame's Back, switched off for an action that cannot be taken back.

**What must be true.** In *Prepare a server…*, once *Prepare the server* has started, *Back* is no longer active: the step that rents and prepares the server cannot be left backwards to change what it was started with.

## Why

Today the shared wizard frame (`lib/src/ui/wizard.dart`, `_back`) keeps *Back* active on Step 7 of 7 once *Prepare the server* has started and only asks "Go back while work is unfinished?" while the action runs; going back offers values to change for a server already being rented.

## Plan

- The wizard frame takes, per wizard, whether its action steps can be gone back from once started; *Prepare a server…* says they cannot. Other wizards keep today's Back.
- On such a wizard, *Back* is not shown (or shown disabled with the reason "The server is being prepared; it cannot be taken back here.") from the moment the action started, whatever its state after.
- **Red first:** a widget test that on Step 7 of 7, after *Prepare the server*, *Back* is absent or disabled, while the rental runs and after it ended.

## Acceptance

- After *Prepare the server*, *Back* cannot be clicked on Step 7 of 7.
- In the other wizards *Back* behaves as before.

Built together with [F233](README.md#f233); one estimate and one VM test for the three, written there.
