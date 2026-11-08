# F442 — Joining A Host's Room Through Element

**Status:** Implementing.

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
