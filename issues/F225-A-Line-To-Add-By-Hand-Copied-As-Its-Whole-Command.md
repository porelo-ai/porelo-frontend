# F225 — A Line To Add By Hand Copied As Its Whole Command

**Status:** Analyzed; placed with the bug fixes after the operator's tests of sprints 6 to 6i.
**Size:** XS - the homeserver dialog's hosts line shown and copied as the one command that adds it, and its widget
test; about 30 minutes.

**What must be true.** Where the interface asks the person to change something on this computer by hand, it shows
and copies **one complete command** for a terminal of their own, never a bare line to be put somewhere. In the dialog
*Your homeserver for this server* (6i-1), the box and its copy button hold

    grep -q 'matrix.porelo.internal' /etc/hosts || echo '127.0.0.1 matrix.porelo.internal # porelo-matrix' | sudo tee -a /etc/hosts

and the text says to paste it into a terminal of your own, once; it changes nothing where the name is already there.

## Why

Seen in the operator's round (6i-1): the dialog showed `127.0.0.1 matrix.porelo.internal # porelo-matrix` and "Add it
once, by hand, with sudo". The person then has to know how to add a line to `/etc/hosts` with sudo. The operator: the
line to copy should be the whole sudo command, so it can be copied and run as it is.

## Every place that shows something to run or add by hand

Read from the code (`Clipboard.setData` and `CommandToCopy` in `lib/src/ui/`):

| Place | What is copied | State |
|---|---|---|
| *Your homeserver for this server* (`host_vpn_dialog.dart` `showHomeserverPublished`) | the hosts line alone | **needs a change: this issue** |
| Put it on a server, step *Your secrets file*, keepassxc-cli missing (`host_dialog.dart`) | `sudo apt install keepassxc-minimal` | whole command |
| A WSL machine's setup, *No, I run them myself* (`wsl_machine.dart`) | the setup's lines, each a command | whole commands |
| A machine's switcher, a command to run there (`machine_switcher.dart`) | the command | whole command |
| A provider's sign-in, *store it yourself* (`authentication_view.dart`) | its `storeCommand` | whole command |
| The gate's fetch (`gate_view.dart`) | the `git fetch` line | whole command |
| A new machine's public key (`new_machine.dart`), the gate's diff, a server's protocol | a value to paste or read, not to run | not a command, as meant |
| The VPN's hosts lines for the forge (`host_vpn.dart`) | nothing: the VPN step writes and removes them itself | no hand step |

## Plan

- `HomeserverPublishing.laptopCommand`: the command above, built from `name` and `laptopLine`; the dialog shows it
  with `CommandToCopy` (as the keepassxc-cli install line) and says "Run this once in a terminal of your own; it asks
  your sudo password and adds the line only where it is missing."
- **Red first:** the dialog's copy button puts exactly that command on the clipboard; run against a temporary file in
  place of `/etc/hosts` (without sudo), it adds the line once and leaves a file that has it unchanged.

## Acceptance

- In 6i-1, the copied text runs as it is in a terminal and adds the line; run twice, the file holds it once.
- No other place copies a line that is not a whole command or a plain value.
