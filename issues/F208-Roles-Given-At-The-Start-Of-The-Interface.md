# F208 — Roles Given At The Start Of The Interface

**Status:** Review; blocked by nothing.
**Size:** M - an argument, a role on every command and the menus and tiles that read it, and their tests; no contract.

**What must be true.** The interface is started with the roles its person holds, `--roles user,host-admin,project-admin`, and shows only the functions of those roles; without the argument it shows normal work alone (`user`). A role shows or hides; what a person may really do stays with the operating system, ssh and the keys.

## Why

The project splits a host's life into three acts by three people: the host admin prepares it, a project admin brings a project onto it, a developer works there. Their functions must not all sit before everybody, as today, where *Put this project on a server…* rents and sets up a host for anyone (decided).

## Plan

- **The argument:** `main(List<String> arguments)` in `lib/main.dart` reads `--roles` (comma list of `user`, `host-admin`, `project-admin`; `access-admin` is accepted and shows nothing of its own, since a host set up apart from its projects leaves it no function). An unknown role is refused at the start, naming the known ones. `user` is always held.
- **The model:** a `Roles` value in `lib/src/app/` beside `desk.dart`, handed down like `Desk`; no setting stores it, so every start says it again.
- **Every command names its role:** `Command` in `lib/src/app/commands.dart` gains `role` (default `user`); `machine.takeDown`, `project.server`, the host's VPN cleanup and the host dialog's commands are `host-admin` or `project-admin` as the split of a host's acts places them. `CommandMenu`, the tiles and the command finder (`lib/src/ui/command_finder.dart`) leave out a command whose role is not held; a test holds every command id to one role.
- **Red first:** a test that the project menu without `--roles` offers no *Put this project on a server…* and with `--roles project-admin` offers it.

## Acceptance

- Started without `--roles`: no command of `host-admin` or `project-admin` is in any menu, tile or the finder.
- Started with `--roles host-admin`: *Prepare a server…* is under *Machines*, and nothing of a project admin's is shown.
- An unknown role refuses the start with the known ones named.
- Seen to fail: the menu test red before `role` exists.
