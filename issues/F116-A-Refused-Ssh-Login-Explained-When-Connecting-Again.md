# F116 — A Refused Ssh Login Explained When Connecting Again

**Status:** Implementing.
**Size:** S - the forward's ending explained as the added machine's is, the key ssh would use read
from ssh itself, and where it shows; one module and its tests.

**What must be true.** A machine that refuses every key the ssh agent offers is said so in words
when it is connected again, as when it is added, together with the key it would take where this
computer knows it, rather than ssh's raw words beside the machine's mark.

## Why

When a machine is added and its socket asked of it, a refused login is explained from ssh's own
words: no key accepted, the agent cut off after its first keys, an unknown host key, a name not
found, no answer on ssh's port. A forward that fails later, on a reconnect or when it is raised
again by itself, keeps ssh's raw words, joined, and shows them only in the tooltip of the machine's
mark. Neither way names the key the machine would take, which is what a person needs to fix it.

## Plan

- **`lib/src/app/tunnel.dart`, `Tunnel._itEnded`:** `problem` is `whySshRefused` of what ssh said,
  for the machine's host, where it tells; ssh's raw words only where it does not, as now.
- **The key ssh would use:** `ssh -G <host>` prints the configuration ssh resolves for the host, its
  `identityfile` lines among it, without connecting. Where `~/.ssh/config` names one (or the
  new-machine wizard wrote one, `~/.ssh/porelo-<name>-<user>`), the refusal names it: "It would log
  in with ~/.ssh/<file>; that key's public half must be in the account's authorized_keys." Where only
  ssh's defaults are listed, it says no key is named for the host. The same sentence joins the
  refusal when the machine is added (`loginUidAt`).
- **Where it shows:** beside the machine where it is not reached, on the machines page
  (`lib/src/ui/machines_page.dart`, under `rail-machine <name>`, keyed `machine-refused <name>`),
  not only in the mark's tooltip (`ReachIcon` in `lib/src/ui/machine_switcher.dart`).
- **Red first:** `test/app/tunnel_test.dart` with a stand-in ssh that ends with "Permission denied
  (publickey)": today `problem` is the raw words; then a widget test of the machines page.

## Acceptance

- **A forward refused on reconnect says why in words,** as an added machine does, where the machine
  is listed. Seen to fail: the tunnel test with ssh refusing every key.
- **The key ssh would use is named where the configuration names one,** and said unnamed where not.
  Seen to fail: tests of the sentence with `ssh -G`'s output holding a named key and only defaults.
