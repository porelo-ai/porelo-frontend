# F388 — The Stub's Pin Stays Fetchable

```json
{
  "$schema": "issue-1.json",
  "id": "F388",
  "title": "The Stub's Pin Stays Fetchable",
  "state": "Backlog",
  "size": "XS",
  "priority": "Medium",
  "rank": 5,
  "blockedBy": [],
  "covers": "A scenario that needs the stub does not go red because its pinned version left the folder."
}
```

**Why this size.** one pin, or a word to the folder's keeper.

**What must be true.** A scenario that needs the stub agent does not go red on a fresh machine because its pinned version left the folder. `integration_test/step/the_test_machine_has_porelos_stub_agent.dart` reads a named version from a folder that keeps the newest 20 versions, so a pin falls out after 20 Builds on `main`, and the step then says the pin may have to move.

## Plan

- Choose one of two ways, then do it:
  - The folder keeps the version a pin names, beside its newest 20.
  - The pin moves with the other pins, often enough to stay among the 20, with something that says so before it falls out.
- A named version stays: a run can be repeated. Reading the newest from the folder's listing was weighed for the test and not taken.

## Acceptance

- A pin older than 20 Builds still fetches, or the pin is known to be moved before that happens.

## Decided while building

## Open questions

- Which of the two ways. The first needs the folder's retention to change, in the repository that publishes it.

## To be checked
