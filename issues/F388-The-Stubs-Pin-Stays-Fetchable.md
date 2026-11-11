# F388 — The Stub's Pin Stays Fetchable

```json
{
  "$schema": "issue-1.json",
  "id": "F388",
  "title": "The Stub's Pin Stays Fetchable",
  "state": "Review",
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

- The second way (the coordinator, 2026-11-11): the pin stays a named version, and `tool/stub_pin.sh` says ahead when
  it is to move. The folder's retention, Core's publishing, is not changed.

## How it stands

- `tool/stub_pin.sh` reads the folder's listing anonymously (Artifactory's storage API) and the pin from the step,
  and says on stderr when the folder no longer holds the pin, or holds 15 or more newer versions, naming the file to
  move it in; versions are compared as versions, so snapshot.1000 comes after snapshot.999. A listing that cannot be
  read is said. It never stops a run; the step's own refusal stays the last word.
- `tool/e2e.sh` runs it before every run.
- Read live on 2026-11-11 it named 0.5.1~snapshot.466 with 17 newer versions, three Builds from falling out: the pin
  moved to 0.5.1~snapshot.497, the newest, its digest the one Artifactory gives for it and the one the file fetched
  had.
- Test: test/tool/stub_pin_test.dart (few newer said nothing; 15 newer named to move; gone said; version order),
  seen red first.

## Open questions

## To be checked
