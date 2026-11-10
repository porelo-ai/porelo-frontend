# F192 — A Machine That Refuses Every Key Said So

```json
{
  "$schema": "issue-1.json",
  "id": "F192",
  "title": "A Machine That Refuses Every Key Said So",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 61,
  "blockedBy": [],
  "covers": "A machine refusing every offered key said so, with the key it expects."
}
```

**Why this size.** sized at the move of the issues' data into their heads, from the change built: one refusal said in words with the key the machine expects.

**What must be true.** When a machine refuses every key the ssh agent offers, the interface says
that the keys were refused and which key the machine expects, instead of showing only "not
connected".

## Acceptance

- A machine reachable over ssh that accepts only a key the agent does not offer shows the refusal
  and the expected key; with that key offered, it connects.
