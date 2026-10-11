# F116 — A Refused Ssh Login Explained When Connecting Again

**Status:** Idea.

**What must be true.** A machine that refuses every key the ssh agent offers is said so in words
when it is connected again, as when it is added, together with the key it would take where this
computer knows it, rather than ssh's raw words beside the machine's mark.

## Why

When a machine is added and its socket asked of it, a refused login is explained from ssh's own
words: no key accepted, the agent cut off after its first keys, an unknown host key, a name not
found, no answer on ssh's port. A forward that fails later, on a reconnect or when it is raised
again by itself, keeps ssh's raw words, joined, and shows them only in the tooltip of the machine's
mark. Neither way names the key the machine would take, which is what a person needs to fix it.

## The shape

- A forward that ends with a refused login says it as the added machine does (`whySshRefused` in
  `lib/src/app/tunnel.dart`), where the machine shows that it is not reached, not only in a tooltip.
- The key it would take, where this computer knows one: the `IdentityFile` that `~/.ssh/config`
  names for the host, or the key the new-machine wizard kept for it; otherwise said that it is not
  known here.
- Red first: a test of the reconnect path with ssh refusing every key, which today shows the raw
  words.
