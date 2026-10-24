# F155 — A Host Taken Down From Machines

**Status:** Review.
**Size:** S - a kept record of `up`, two actions on the host machine, the dialog refilled from it.

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

## Plan

- **Today**, read in the code: after the dialog closes, nothing of `up` is kept but the `host`
  machine (`name`, `host`, `remoteSocket`, `kind`, `identity`; `Machine.stored`) and the project's
  Tresorit folder (`Settings.tresorFolder`). *Remove from this list* (`Shell._forget`) asks nothing
  for a `host`, since no ssh-config entry was written for it, and forgets it at once.
- **A record of `up`:** `Settings` keeps, per project, the arguments the last `up` ran with, none
  of them a secret: the Scaleway project, the tresor, the account, the key paths, the collection,
  the tunnel's public half and address. It is written beside itself and renamed over, every field
  checked on load, and it never goes into `project.yml`. The dialog fills its fields from it when
  it opens.
- ***Take this server down*** is a `Command` with its home on a `host` machine, in its `⋯` menu
  and on its page: a confirmation naming what ends (the project's tasks, its room, its files on the
  host), then `porelo-host down` with the kept record, its steps shown as `up`'s are; the machine
  goes once `down` ends 0 and names the address it gave back, as today. Without a kept record it
  is listed with its reason, *Put this project on a server…* again.
- ***Remove from this list* on a `host`** asks first: it keeps running and billing at the
  provider, and is added back by putting the project on a server again, which finds it by its tag;
  *Take this server down* stands beside the removal.
- **Tests, their harm, red first:** a `host` is never forgotten without that warning (a server that
  bills on with nobody knowing); a failed `down` keeps the machine (the only way back to a running
  server lost); `down` from the machine runs with the kept arguments and nothing typed again.

## Acceptance

- *Take this server down* in the host's `⋯` menu and on its page under *Machines* confirms what
  ends, runs `porelo-host down` from the record kept at `up` without asking for fields again, and
  removes the host when `down` exits 0, ending with the provider's word that nothing is left;
  the setup dialog restores its last values when reopened.
- Seen to fail: *Remove from this list* on a rented host never drops the machine without showing
  the running-and-billing warning, how to add it back, and the take-down action beside it; a failed
  `down` keeps the host in *Machines*.

## To be checked

- That a second `up` of the same project finds a host forgotten from the list by its tag and adds
  it back without renting another, measured with the stand-in's `clean` situation and read in
  `porelo-host up`.
