# F323 — Refuse An Organization A Host Cannot Follow

**Status:** Idea.
**Size:** S - one refusal in *Prepare a server…*, once Core says what to read for it.

**What must be true.** A person whose organization stands at an https address is told so before `up`, with the reason, in
*Prepare a server…*. Today `up` exits 0 after minutes, and the first token then ends in
`--settings names an address --ssh-key cannot reach` (exit 69 at `org refresh`): the host can never follow.

**Plan.** Core says what the answer of `porelo org` holds to tell this by, so the interface does not read a URL's form on
its own. `HostAccess` gives the refusal beside its other reasons, and the dialog shows it before anything starts. A test
sees that nothing is prepared, seen red first.
