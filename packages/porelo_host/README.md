# porelo_host

Puts a project on a server and takes it off again, as `porelo-host up` and `porelo-host down`.
Pure Dart, so the interface imports it and `dart compile exe` builds the command for Linux and
Windows.

The build fetches the collection from the pinned
[porelo-host release](https://github.com/porelo-ai/porelo-host/releases), checks both the pinned
SHA-256 and the release's `SHA256SUMS`, and carries the tarball beside `porelo-host` in every
bundle and package (`/usr/lib/porelo-frontend/` on Linux). The version, file name and digest live
in `lib/src/collection.dart`; `porelo-host --collection-info` prints them for the build.
`up` uses that file beside its own resolved executable, without a download at setup time.
A missing or changed tarball is refused with exit 65 before renting. Its digest is checked again
on the host before the collection installer runs.

Only test runs override it: `--collection FILE` requires `--collection-sha256 HEX`, the SHA-256 of
a collection built from a clean clone. The interface offers these inputs only in debug builds.
For a local package build, first run `tool/fetch_collection.sh VERSION SHA256 build/collection`
from the repository root with the values from `porelo-host --collection-info`.
The script also accepts a fourth argument naming another tarball from the same release.
`PORELO_COLLECTION_SOURCE` can name a local release directory containing the tarball and
`SHA256SUMS` to check the fetch step without network access.

- **`up`** rents the project's host, or finds it again by the tag `porelo-project=<name>`. It
  trusts the host key the provider reports, copies the first play's inventory and the collection
  [porelo-host](https://github.com/porelo-ai/porelo-host) there, and installs `ansible-core`. It
  then runs `ansible-playbook -c local` on the host itself. It stops once for the person, with exit
  code 75 and names the host address, account and needs in its `person` line. Complete the
  login and vault prompts in a terminal on that host, then run the same `up` again.
- **`down`** runs the down play and only then gives the host back. A host whose down play did not
  finish is kept, since a failed copy may have left the only copy there; its last line says so, and
  `--give-back-anyway` gives it back knowingly.

Each step is one JSON line on standard output, relayed from the collection's callback; the words
for a person go to standard error. No form of the interface and nothing in `porelo-host` takes
the drive password, one-time code or vault passphrase. They are typed into a terminal on the
host, at the provider's and Porelo's own prompts. Only the non-secret inventory and the expected
collection digest reach remote command input during `up`.

The interface also uses `HostFiles` to prepare a project's local Tresorit folder: the machine
file, optional vault key files and the host's WireGuard private key. Existing differing files
are refused. The person's separate WireGuard private key lives in the system secret store and
reaches a file only through an explicitly requested wg-quick export. `HostFileWriter` stages
complete files privately, protects them with 0600 on Linux or current-user ACLs on Windows, and
publishes with an atomic rename that cannot replace an existing destination. Temporary directories
are removed on success and failure. `HostTunnel` exposes public halves only.

```sh
dart test
dart run bin/porelo_host.dart up --project demo --account porelo --public-key ~/.ssh/id_ed25519.pub \
    --identity ~/.ssh/id_ed25519 --collection porelo-host.tar.gz --collection-sha256 "$(sha256sum porelo-host.tar.gz | cut -d ' ' -f 1)" \
    --given 203.0.113.7 --host-key "ssh-ed25519 AAAA…"
```
