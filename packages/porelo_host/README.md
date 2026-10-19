# porelo_host

Puts a project on a server and takes it off again, as `porelo-host up` and `porelo-host down`.
Pure Dart, so the interface imports it and `dart compile exe` builds the command for Linux and
Windows.

- **`up`** rents the project's host, or finds it again by the tag `porelo-project=<name>`. It
  trusts the host key the provider reports, copies the first play's inventory and the collection
  [porelo-host](https://github.com/porelo-ai/porelo-host) there, and installs `ansible-core`. It
  then runs `ansible-playbook -c local` on the host itself. It stops once for the person, with exit
  code 75; a second `up` given the answers on standard input goes on.
- **`down`** runs the down play and only then gives the host back. A host whose down play did not
  finish is kept, since a failed copy may have left the only copy there; its last line says so, and
  `--give-back-anyway` gives it back knowingly.

Each step is one JSON line on standard output, relayed from the collection's callback; the words
for a person go to standard error. A secret is only ever written to a command's standard input on
the host, never to an argument, a file or a log.

```sh
dart test
dart run bin/porelo_host.dart up --project demo --account porelo --public-key ~/.ssh/id_ed25519.pub \
    --identity ~/.ssh/id_ed25519 --collection porelo-host.tar.gz --given 203.0.113.7 --host-key "ssh-ed25519 AAAA…"
```
