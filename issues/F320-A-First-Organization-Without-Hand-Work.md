# F320 — A First Organization Without Hand Work

**Status:** Review.
**Size:** M - a question for Core and Machines first, then one dialog.

**What must be true.** A person with a forge that is not GitHub can set up their first organization from the interface
alone. Today it takes seeding the forge's ssh host key by hand; the forge itself lies outside the host by design.

## What the walk found

1. **A forge's ssh host key has no way in through the interface.** Reaching the organization over ssh needs the forge in
   Porelo's own `known_hosts`, and nothing in the interface adds it, so a first read fails with words about the host key.
2. **The first organization cannot live on the host's own forge.** *Prepare a server…* needs an organization, and `up` is
   what makes the host's Forgejo. That Forgejo then answers only on its sockets and on the machine's loopback, without
   TLS, while Porelo takes `https` or `ssh` and asks the forge on 443.

## Plan

- Ask Core whether `porelo setup --organization` can show a forge's host key for confirmation, as `porelo-host` shows a
  server's. If so, *Choose another organization…* shows the fingerprint and takes the person's yes. First use is never
  trusted silently.
- The second is meant: an organization always lives on a forge outside the host, and the dialog that asks for its address
  says so.

The fingerprint dialog is built only after Core's answer.
