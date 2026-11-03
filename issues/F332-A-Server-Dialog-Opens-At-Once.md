# F332 — A Server Dialog Opens At Once

**Status:** Accepted.

**What must be true.** *Prepare a server…* opens its dialog at the click, the dialog saying that it is still reading, and a
second click opens no second dialog.

In a walk an owner clicked *Prepare a server…* under *Machines* and waited long with nothing to see, and took it that the
button had not been pressed. How long was not measured.

## What the click waits for

Read from the code, not run. `prepareServerCommand` calls `HostAccess.prepare`, which reads again before opening anything:

1. `porelo identity show`, for the proven key;
2. `porelo org`, which reads the organization from its repository, with the forge saying who holds which key;
3. only then the dialog, unless the read found a reason to refuse, when the button greys with its reason and no dialog comes.

Nothing marks the wait, and the button stays pressable. `HostAccess.prepare` has no guard, so a second click looks like it
runs a second read and opens a second dialog over the first. That is the click the wait invites.

## What the read before the dialog is for

It keeps a stale button from opening the way to a server. The dialog does not rest on it: `HostDialog` runs the same two reads
again as it opens, so a click reads everything twice, and `HostAccess.machineFile` reads anew before anything is rented,
refusing if the key was revoked since. So the dialog can open first and say its read there, with *Prepare the host*
unavailable until the answer. A refusal then stands in the dialog,
which also says it better than a greyed button does. No check is given up, but this should be read by someone against
the rule that no security check rests on an earlier read.

## To be checked

- That two clicks do open two dialogs, in a widget test, seen red before the fix.
- How long the two reads take at real GitHub. [F330](README.md#f330) and [F331](README.md#f331) wait on the same reads.
