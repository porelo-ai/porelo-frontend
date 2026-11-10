# F354 — The Integration Leg On A Machine Of The Host's Pool

```json
{
  "$schema": "issue-1.json",
  "id": "F354",
  "title": "The Integration Leg On A Machine Of The Host's Pool",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 44,
  "blockedBy": [],
  "covers": "The Build's integration leg on a host's Forgejo against a machine its pool lends by kind."
}
```

**What must be true.** On a host's Forgejo, the Build's integration leg runs against a machine the host's pool lends a job by
kind, with the same lines that rent one on the central forge, so that a task's branch is tried against a real machine
before it leaves the host.
