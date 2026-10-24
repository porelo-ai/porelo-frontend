# F156 — The Host Dialog's Fields And Words

**Status:** Backlog.
**Size:** S - the host dialog, one shared helper for `~`, its test.

**Order.** In the host flow, after [F155](README.md#f155).

**What must be true.** In the host dialog, `~` in a path field is expanded to the home directory or
refused in plain words, the repository URL and signing-key fields stay hidden until the tresor
folder is chosen, and a stop scrolls the wanted input into view. The VPN export button and tunnel
hint use plain words (such as *Save the VPN connection to this server*) with an `(i)` explaining
WireGuard, that the file holds a private key, where to keep it, and how to bring it up through
`/etc/wireguard/porelo.conf` and `wg-quick up porelo`.

## Why

In the host dialog, `~` in a path field is taken literally and
fails with *Cannot prepare the host file*, the repository URL and signing-key fields are shown
before a tresor folder is chosen, and the dialog does not scroll when input appears at the end.
*Save the wg-quick file* and *Bring the tunnel up with your own WireGuard. This needs root.* are
not plain words, and `sudo wg-quick up <file>` on a saved file in a home folder fails where
AppArmor allows `/etc/wireguard` only.

## Plan

- **Today**, read in the code (`host_dialog.dart`): the four path fields (*Your public ssh key*,
  *Your private ssh key*, the collection, the commit-signing key) are typed only, and passed on as
  typed; `~` is expanded in two other places, each inline (`host_keys.dart`, `project_workspace.dart`).
  The repository URL and signing-key fields are already shown only once `_folder` is set, but
  `_folder` comes back from `Settings.tresorFolder` on every later opening, so a folder chosen once
  shows them from the start. `DialogScroll` has no controller, and nothing scrolls when the steps
  or the stop appear.
- **One helper for `~`:** `Desk.expandHome` in `desk.dart` turns a leading `~` or `~/` into the
  person's home and leaves every other path as it is; the dialog's path fields, `host_keys.dart` and
  `project_workspace.dart` take it, so the two inline copies go. A `~user` form is refused in words
  naming it.
- **The remembered folder in sight:** a folder chosen in an earlier opening still counts, so the
  repository and signing-key fields open with it, and the dialog names that folder at the top with
  *Choose another*, so it is clear why they are open.
- **Pickers:** each path field gets a *Choose…* beside it (`file_selector`'s `openFile`, as the
  key files have today); the field stays typable.
- **The stop in view:** the dialog's scroll gets a controller, and the stop's first input is
  brought into view with `Scrollable.ensureVisible` when it appears.
- **Words:** *Save the wg-quick file* becomes *Save the VPN connection to this server*, with an
  `(i)` saying what WireGuard is, that the file holds a private key and where to keep it, and the
  two commands that bring it up: `cat <file> | sudo tee /etc/wireguard/porelo.conf` and
  `sudo wg-quick up porelo`. *Bring the tunnel up with your own WireGuard. This needs root.* goes
  into that `(i)`. The other helper lines and buttons are read once for jargon in the same change;
  the stop's own fields are [F152](README.md#f152)'s.
- **Test, its harm, red first:** a path typed with `~` reaches `porelo-host` expanded (today the
  host files cannot be prepared and `up` gets a path that does not exist); `~user` is refused. The
  words, the pickers and the scroll get no test: they only read wrong.

## Acceptance

- A file or folder is chosen with a picker wherever one can be; a typed path is the exception.
- A path beginning with `~` expands to the person's home directory (or is refused in plain words
  naming `~`), the repository URL and signing-key fields appear only after a tresor folder is
  chosen, and a stop scrolls its prompt into view.
- The tunnel hint gives `cat <file> | sudo tee /etc/wireguard/porelo.conf` and
  `wg-quick up porelo`, never `wg-quick up` on a file in the person's home.
- Seen to fail first: a path such as `~/.ssh/porelo-host` in today's dialog fails with *Cannot
  prepare the host file*; the test holding the expansion goes red on it.
