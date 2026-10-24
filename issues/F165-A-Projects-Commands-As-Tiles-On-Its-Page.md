# F165 — A Project's Commands As Tiles On Its Page

**Status:** Implementing.
**Size:** S - one tile widget over the project's existing commands, grouped, on its page.

**What must be true.** A project's page shows its commands as tiles with a line each on what they
do, beside *Start work*, rather than only in its `⋮` menu, so a person sees what can be done with a
project without opening a menu.

## Why

In walk 1 the operator asked why the project's commands are not tiles under the project; today
its page shows its state, *Its work, under Work* and *Start work*, and ten commands (prepare,
check, messages, forge, default, backups, clear, put on a server, delete, follow) sit in its `⋮`.
Related: [F159](README.md#f159), work started from the project page.

## Plan

- **Today**, read in the code: the project's ten commands are `Command`s with their home on the
  project (`commands.dart`: `project.prepare`, `.sync`, `.messages`, `.forge`, `.default`,
  `.backups`, `.clear`, `.server`, `.delete`, `.follow`), shown only in the page's `⋮`
  (`machine_view.dart`, `project-menu`); each says why it cannot run now.
- **Tiles from the same commands:** one `CommandTile` (icon, label, one line of what it does, and
  when it cannot run its reason, disabled), built from the very `Command`s the `⋮` lists, so a tile
  and its menu item can never differ. They sit under the page's state, beside *Start work*.
- **Grouped**, as the operator chose, so ten tiles read as a page and not as a wall: *Work* (start, its work, messages),
  *Keep in step* (check it now, prepare, backups), *Where it lives* (forge, default, put on a
  server), and *Remove* (clear, delete) last and apart.
- **Test, its harm, red first:** a tile runs exactly its command, and a command that cannot run now
  shows its reason and does not run (an action run when it must not). The look gets no test.
- **The `⋮` keeps every command** beside the tiles, both from the one `Command` list, for the
  command finder (`Ctrl+K`), the keyboard and a narrow window.
- Built with [F159](README.md#f159), which adds the start buttons on the same page.
