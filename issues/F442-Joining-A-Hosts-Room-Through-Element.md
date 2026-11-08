# F442 — Joining A Host's Room Through Element

**Status:** Review.

**What must be true.** On a host whose homeserver manages its people itself, joining the project's room sends the
person to Element signed in to that host, never into a join that can only be refused; elsewhere the join offers only
the logins the room admits.

## Why

The third move (2026-11-08), findings 17 and 18, decided by the operator that evening with the design *Third move
findings, before and after* (pair 17/18).

## Acceptance

- **On a host:** the dialog says the host manages its people at its own homeserver, and shows one of two blocks:
  - Element installed on this computer: *Open Element signed in to this host* (the homeserver set, straight to
    *Continue with SSO*), with a checkbox *In a separate instance (keeps your open Element as it is)*, checked by
    default, which starts Element with its own profile for that host.
  - Element not installed: *Install Element* with its address, and by hand: the homeserver with a copy button,
    *Continue with SSO* as the person's login, and accepting the invitation.
  - No name field and no join.
  - Who is already in the room, by name.
- **Elsewhere:** the join's name field is a choice of the logins the room admits, never a free field prefilled with a
  refused name.

## Size

S: S the host's blocks and the Element start, XS the admitted logins.

## How it stands

- Built on its branch: on a host with its own homeserver the dialog shows the Element block (installed: open it
  signed in, separate instance checked by default; not installed: *Install Element* and the way by hand) and who is
  already in the room, with no name field and no join; elsewhere an organization's project offers a choice of its
  admitted logins, the asking person's own first, says when the organization is not read yet, and offers no join where
  it admits nobody.
- Element is started with `--config` naming a file of the window's own that sets the homeserver and SSO on the welcome
  page, `--profile <host>` for the separate instance, and an `element://` address with `hs_url` for an Element already
  open. Whether `hs_url` and the SSO redirect take effect in Element is not confirmed against its source; to be seen
  on the next move. A Flatpak or Snap Element may not see the config file outside its sandbox.
- The admitted logins apply only where a host of the organization carries its project of that name; a same-named
  project elsewhere keeps the free field. A card run out is not offered; the organization's view names no lock, so a
  locked member can still be offered and is then refused by the machine. A failed read of the organization says so
  with its reason.
- Matrix (room, 19:55Z) confirms the card's `http://<host>.localhost:<port>/` works for the gate's SSO (it checks the
  Host header; host names are lower case by the card's own rule). Element is given one address per profile, never
  also `127.0.0.1`.
