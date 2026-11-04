# F317 — A Homeserver's Token Reaches The Host

**Status:** Idea.

**What must be true.** A person connecting to a host that carries a project with a homeserver elsewhere never meets a task that cannot enroll for want of a token: when `porelo project show` answers `matrix_registration_entry`, that entry goes on `porelo-host-stop --stdin` as a `key <entry>` line with a base64 value, in the run that opens the vault. The token comes from the person's own vault, or is asked once in the terminal, and never enters the interface. With `null` nothing is asked.

## How it stands

Read from the code, not run. `PoreloOrganizationSource.readProject` in
`lib/src/app/porelo_organization_source.dart` does not read `matrix_registration_entry`, so the promised token
delivery is not built. `unlockCommandFor` in `lib/src/app/vault_unlock.dart` returns `null` for a host.
`lib/src/app/tunnel.dart` delegates its vault unlock to `CoreHostUnlocker` in `lib/src/app/fleet_backend.dart`,
which calls `porelo host unlock`; it does not run `porelo-host-stop --stdin` or ask for this token in a terminal.
