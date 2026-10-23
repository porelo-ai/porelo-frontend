# F155 — A Host Taken Down From Machines

**Status:** Accepted.

**Order.** In the host flow, after [F154](README.md#f154).

**What must be true.** A host under *Machines* offers *Take this server down* in its `⋯` menu and
on its page, with a confirmation naming what ends (tasks, room, files) and no field typed again,
read from what the interface kept from `up`. Choosing *Remove from this list* on a rented host
warns that it keeps running and billing, says how to add it back, and offers *Take this server
down* beside it; the setup dialog keeps its last values when reopened.

## Why

Today *Take it off the server* sits inside the project's *Put this project on a server…* dialog
(`host_dialog.dart:483`), which keeps none of its fields when closed and disables the button until
the `up` fields are filled again. Meanwhile *Machines* → `⋮` → *Remove from this list* calls
`_forget` (`shell.dart:1196`) without a warning because the wizard wrote no ssh-config entry, so
the rented server keeps running and billing with no hint of how to reach or take it down.

## Acceptance

- *Take this server down* in the host's `⋯` menu and on its page under *Machines* confirms what
  ends, runs `porelo-host down` from the record kept at `up` without asking for fields again, and
  removes the host when `down` exits 0, ending with the provider's word that nothing is left;
  the setup dialog restores its last values when reopened.
- Seen to fail: *Remove from this list* on a rented host never drops the machine without showing
  the running-and-billing warning, how to add it back, and the take-down action beside it; a failed
  `down` keeps the host in *Machines*.

## To be checked

- Which values from `up` (`host_dialog.dart:483`) must be stored on the host entry for `down`, and
  whether a forgotten host (`shell.dart:1196`) can already be added back by hand with its address,
  account, key and pinned host key.
