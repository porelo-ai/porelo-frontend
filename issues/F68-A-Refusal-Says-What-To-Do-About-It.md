# F68 — A Refusal Says What To Do About It

**Status:** Review; to be walked; an organisation's approval of a fine-grained token not built.

**What must be true.** Where the interface knows why something was refused, it says what to change,
and where, instead of showing only the forge's or ssh's words.

## Why

In place: a token GitHub refuses for deploy keys names *Administration: Read and write*, a refused
push names *Contents: Read and write*, both with the repository and where in GitHub the right is
given; deploy keys an organisation switched off are said as its setting; a host refusing the login
when a machine is added says why from ssh's own words (an agent cut off after its first keys, no key
accepted, an unknown host key, a name not found, no answer on ssh's port); a start refused with
`UNKNOWN_HOST_KEY` shows the host's keys, marks the one the forge publishes, and trusts it with one
press, while a changed key offers nothing. `CanStart` answers an unknown host key with its keys;
so far only a stand-in answering the same way was measured.

## Acceptance

- **A token that lacks a right names the right**: *Contents: Read and write*, *Administration: Read
  and write*, for which repository, and where in the forge it is given. Seen to fail: a walk at
  GitHub with a token lacking each right, and the scenarios for both refusals.
- **Deploy keys disabled for a repository** are said as the organisation's setting, and where it
  is. Seen to fail: a walk at GitHub with an organisation that disabled them.
- **A fine-grained token whose change waits for the organisation's approval** is said as waiting,
  not as refused. Seen to fail: GitHub's answer for such a token, measured, then a scenario with it.
- **A repository's host key the machine does not know** is offered to be trusted when starting work
  in `default`, as following a project offers it. Seen to fail: a start measured on the VM against
  Core's handover with a host the machine never met.
- **A machine that refused every key the ssh agent offered** says so, and which key it expects,
  rather than *not connected*, both when it is added and when it is connected again. Seen to fail: a
  walk connecting to a machine whose `authorized_keys` holds none of the agent's keys, and a test of
  the reconnect path.
