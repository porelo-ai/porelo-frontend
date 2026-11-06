# F395 — Leftovers Of Sprint 6q

**Status:** Idea.

**What must be true.** What sprint 6q's issues named as not built is kept in one place until the operator places each part:
in an issue of its own, in a sprint, or dropped.

Each point is to be checked against the code before it is fixed.

## How it stands

- **From the reading of the organization walk's rework:** two refusals on one project hide each other on the
  organization's project list; `Organization.write` has no `finally`; *Open the project* hands the organization forge's
  token, not the project's central repository's.
- **The machines' list:** *Connect* under *Machines* stays in the ⋮ (`MachinesPage._row`), while every other row shows it
  beside the menu.
- **One row per machine:** no lost-access words and no stop to retries on a person's own machine row; the card is not removed
  at the take-down's last step, and `cardLeftBehind` (`lib/src/app/host_access.dart`) still says an organization owner
  removes the machine; *Prepare a machine…* does not enter the card itself; `_organizationHost` remains; a rental cannot be
  returned from another computer.
- **A machine's page:** no *Connecting* words on the row or the page; no *Start work* on a machine page's project rows; the
  top *Start work* starts in *Default* rather than the named project.
- **Commits not yet at the forge:** the project's page shows no central state and no line per repository; a locked member's
  push is hidden, not greyed with its reason.
- **A machine's list of projects:** a project's row does not show the machine keeping it after taking it off.
- **Lists:** only the organization page's lists sort by state; the tablet header may wrap; `ExpandableListRow` keeps its
  state beside the title on a phone.
- **A card renewed:** no warning or renewal on the work page; an ssh refusal for an ended card is not said as that.

## Open questions

- **The server's host key at *Prepare a machine…*:** it is fetched and its fingerprint shown to confirm, which is trust on
  first use unless the person compares it with the provider's console. Whether that weakens the setup is for Agent
  Machines to say; `doc/design.md` names no exposure for it until then.
