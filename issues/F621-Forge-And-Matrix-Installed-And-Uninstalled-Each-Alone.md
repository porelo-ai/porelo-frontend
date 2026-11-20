# F621 — Forge And Matrix Installed And Uninstalled Each Alone

```json
{
  "$schema": "issue-1.json",
  "id": "F621",
  "title": "Forge And Matrix Installed And Uninstalled Each Alone",
  "state": "Analyzed",
  "size": "L",
  "priority": "High",
  "rank": 4,
  "blockedBy": [],
  "covers": "From its own page, a forge or Matrix is installed or uninstalled alone, on this computer and on a host alike: one administrator prompt, the lines shown live, uninstall refused while work is not at central"
}
```

**Why this size.** L: it crosses repositories. porelo-host can install the forge and Matrix as parts of `up` today,
but `down` removes everything at once; uninstalling one part alone, and running the same on this computer, are new
there, and the window drives both.

**What must be true.** From the Forge or Matrix page of this computer or of a host, the person installs or uninstalls
that part alone. Installing says what happens, asks once for administrator rights and shows the installation's lines
as they come. Uninstalling is refused while work is not at central, warns while reviews are open, and on a host is
also refused while another person's project uses it and is offered only to a Machine Admin. Each leaves the machine
as it was before. On Windows and macOS this computer offers neither.

## The contract it builds on

- On a host, porelo-host's playbook `porelo.host.part` installs or uninstalls one part (`porelo_host_part`: forge or
  matrix, `porelo_host_action`: install or uninstall). The window reaches it through the shipped `porelo-host`
  binary, as it runs `up` and `down` today, so it needs a subcommand there for it, with the host's arguments `up`
  takes.
- On this computer the window runs `pkexec /usr/libexec/porelo-host/part <forge|matrix> <install|uninstall>`: the
  one administrator prompt.
- Both print the `porelo.host.lines` JSON lines `up` and `down` print, refusals and waiting stops alike. The playbook
  refuses an uninstall while work is not at central and, on a host, while another person's project uses the part.
- The window warns on open reviews before it calls a forge's uninstall; the playbook does not check them.
- On this computer the gate admits the person's own uid: no `porelo-people` membership, so nothing is said about a
  next login. This computer's forge follows the organization as a host's does.
- Removing the forge alone also takes the VM pool whose runner rents from it, as `down` orders them today.

## Plan

- `lib/src/app/host_session.dart`: `installPart(part)` and `uninstallPart(part)` beside `up()` and `down()`, the same
  steps and refusals (`Step`, a stop line's `needs`), read by the same line reader.
- This computer: the `pkexec` command above, its lines read the same way, Linux only; a declined prompt ends in
  words, never as a failure of the part.
- Before a forge's uninstall: the pull requests waiting for review ([F619](README.md#f619)) are named, and the person
  goes on or stops.
- `lib/src/ui/part_install_dialog.dart`: what happens, the prompt, the lines live, the end in words; its uninstall
  side shows the refusal's reason (work to bring to central, reviews open, another person's project, not a Machine
  Admin) and offers the page where it is resolved.
- `lib/src/ui/server_setup_wizard.dart`: its forge switch stays for a new host; a host already set up adds or removes
  the part from its page.
- Tests, unit level first, red first: the session's part calls over a fake `porelo-host` (lines, refusal, a stop that
  needs the vault), and the dialog never offering uninstall to one who is not a Machine Admin (harm: a forge removed
  with work not at central, or another person's project losing its forge).

## Open questions

- Uninstalling Matrix while a project's room lives on it: is the room's history kept for a later install, or is
  the person told it goes?

## To be checked

- The `porelo-host` subcommand that runs `porelo.host.part` on a host, and its arguments; whether `up` without a part
  removes an installed one (today it does not).
- Whether a forge on this computer needs a port the window then reaches directly, or through the same forward as a
  host's.
