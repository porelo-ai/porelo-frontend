# F192 — A Machine That Refuses Every Key Said So

**Status:** Idea.

**What must be true.** When a machine refuses every key the ssh agent offers, the interface says
that the keys were refused and which key the machine expects, instead of showing only "not
connected".

## Acceptance

- A machine reachable over ssh that accepts only a key the agent does not offer shows the refusal
  and the expected key; with that key offered, it connects.
