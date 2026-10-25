# F189 — The Server Page's Actions As A Grid Of Tiles

**Status:** Analyzed.
**Size:** S - `Shell._machineBody` in `lib/src/ui/shell.dart` and `ProjectCommandTiles` in `lib/src/ui/machine_view.dart`.

**What must be true.** A server's page lays out its action tiles in the same multi-column tile grid
as a project's page ([F173](README.md#f173)'s `CommandTile`), with a distinct icon for each action
and no crossed-out cloud icon. *Take this server down* leaves the action grid and stands alone at the
end of the page as a red button like *Stop everything*.

## Plan

- **Where it is today.**
  - On a project's page, `ProjectCommandTiles` (`lib/src/ui/machine_view.dart`, lines 261–382) lays
    out `CommandTile` widgets (`lib/src/ui/machine_view.dart`, lines 388–457, introduced in
    [F173](README.md#f173)) inside a `Wrap(spacing: Space.normal, runSpacing: Space.normal)` with a
    distinct icon per command.
  - On a server's page (`narrowed == null`), `Shell._machineBody` (`lib/src/ui/shell.dart`, lines
    2978–2993 and 3074–3075) places `for (final command in _hostCommands(machine)) CommandTile(...)`
    directly into the outer `Column` without a `Wrap` or vertical spacing, so the tiles stack in a
    single vertical column with touching borders and overlapping shadows; `itsWork` (`CommandTile`
    with `Key('its-work')`) sits further down outside the group.
  - In `Shell._machineBody` (`lib/src/ui/shell.dart`, lines 2982–2986), the `switch (command.id)`
    maps `'machine.vpnUp'` to `Icons.vpn_key_outlined`, `'machine.vpnDown'` to
    `Icons.link_off_outlined`, and `_` (every other host command: `'host.protocol'`,
    `'machine.takeDown'`, and `'machine.saveTunnel'`) to `Icons.cloud_off_outlined` (the crossed-out
    cloud).
- **Steps.**
  1. In `Shell._machineBody` (`lib/src/ui/shell.dart`), group the server's non-destructive
     `CommandTile`s (`host.protocol`, the single VPN command from [F183](README.md#f183),
     `machine.saveTunnel`, and `itsWork`) inside a `Wrap(spacing: Space.normal, runSpacing:
     Space.normal)` matching `ProjectCommandTiles` in `lib/src/ui/machine_view.dart`.
  2. Assign each server tile its own distinct outlined icon in `Shell._machineBody`:
     - `'host.protocol'` (*Protocol*): `Icons.receipt_long_outlined`
     - `'machine.vpnUp'` / `'machine.vpnDown'` (the single VPN tile from [F183](README.md#f183)):
       `Icons.vpn_key_outlined` / `Icons.link_off_outlined`
     - `'machine.saveTunnel'` (*Save VPN file…*): `Icons.download_outlined`
     - `'project.itsWork'` (*Its work*): `Icons.play_circle_outline`
     Remove `Icons.cloud_off_outlined` from the tile switch.
  3. Filter `'machine.takeDown'` (*Take this server down*) out of the `CommandTile` grid in
     `Shell._machineBody` and render it at the end of the server page (below the bottom `Divider`,
     alongside or in the place of the destructive footer action) as a red button styled with
     `colorScheme.error` like `EmergencyStopButton` (`lib/src/ui/emergency_stop_view.dart`).
- **Tests, their harm, red first.**
  - None: tile grid arrangement, icon choice, and button styling are layout, icons, and color only;
    words, colors, and layout get no test.

## Acceptance

- The server page renders its actions (*Protocol*, the VPN action, *Save VPN file…*, and *Its work*)
  in a multi-column `Wrap` grid of `CommandTile`s with `Space.normal` spacing, matching the project
  page.
- Every tile on the server page has its own icon matching its meaning, and none uses the crossed-out
  cloud (`Icons.cloud_off_outlined`).
- *Take this server down* is not in the tile grid; it stands at the end of the server page as a red
  button like *Stop everything*.
