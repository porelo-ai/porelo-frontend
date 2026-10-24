# F156 — The Host Dialog's Fields And Words

**Status:** Accepted.

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

## Acceptance

- A file or folder is chosen with a picker wherever one can be; a typed path is the exception.
- A path beginning with `~` expands to the person's home directory (or is refused in plain words
  naming `~`), the repository URL and signing-key fields appear only after a tresor folder is
  chosen, and a stop scrolls its prompt into view.
- The tunnel hint gives `cat <file> | sudo tee /etc/wireguard/porelo.conf` and
  `wg-quick up porelo`, never `wg-quick up` on a file in the person's home.
- Seen to fail first: a path such as `~/.ssh/porelo-host` in today's dialog fails with *Cannot
  prepare the host file*; the test holding the expansion goes red on it.

## To be checked

- Every other button and helper line in the host dialog alongside *Bring the tunnel up with your
  own WireGuard. This needs root.* that still uses technical jargon instead of plain words.
