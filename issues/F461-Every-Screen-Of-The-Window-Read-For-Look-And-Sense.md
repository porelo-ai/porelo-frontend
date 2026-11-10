# F461 — Every Screen Of The Window Read For Look And Sense

```json
{
  "$schema": "issue-1.json",
  "id": "F461",
  "title": "Every Screen Of The Window Read For Look And Sense",
  "state": "Review",
  "size": "M",
  "priority": "Medium",
  "rank": 12,
  "blockedBy": [],
  "covers": "Every screen captured headless at three sizes, light and dark, full and empty, read by another model against a visual and a logical checklist; every finding listed with its screen and size, nothing fixed yet."
}
```

**Why this size.** every screen captured headless at three sizes, light and dark, with data and empty; one reading by
another model against the checklist below; every finding listed here. Nothing is fixed and no test is written.

**What must be true.** The operator can read, in this issue, every visual and logical finding on every screen of the
window, each with its screen and window size, gathered by one reading of captured screens against one checklist,
before anything is changed.

## How it stands

- Captured on 2026-11-10 with `tool/capture_screens.sh /var/tmp/f461-captures`: 50 screens in the full and the lost
  situation and 43 in the empty one (143 in all), 858 pictures, each at 390x844, 1024x768 and 1920x1080, light and
  dark. The text is in the desktop's own fonts. Not reached, and said so in each situation's `missing.txt`: the
  organization and its six screens in the empty situation (no organization is read there), a piece of work opened
  in the empty situation (none runs), and *Show what this project would open*, which opens a page, not a dialog
  (captured as it shows).
- Not captured, and still to be: the finder's dialogs not named in `tool/capture_screens.dialogs` (the forge,
  host, project-setup, vault, sign-in, deletion and organization-access dialogs among them), every wizard step
  after the first (no *Next* could be pressed with nothing typed), a log opened, the review of a push, a forge's
  page, Planning with a planner, and a second machine. The empty situation is the mock's `empty`, which keeps its
  projects, vault, agents and connections: only its work is empty.
- The reading was one run of agy with `gemini-4-argon-high` in plan mode, over contact sheets of the three sizes
  side by side and the originals, at the brief's choice of model rather than the plan's `claude-opus-5-5-high`.
  It returned 209 lines; the agent checked a sample against the pictures (the status bar, the Work and Needs you
  places, the machine's facts, the gate, the organization's admins, a piece of work opened, the add-a-user dialog)
  and set aside 19 it found false, the mock's own or not seen, each listed with why.
- The first runs gave the window no state folder of its own, so it wrote four operations of the capture into the
  person's own operations file; they were taken out again and the script now gives the window its own state, data
  and cache folders. The pictures read were taken before that change.
- Nothing is fixed and no product test is written; each fix becomes its own issue once the operator has read the
  list.

## Plan

- **Capture.** `tool/capture_screens.sh [FOLDER] [SITUATION...]` runs `integration_test/every_screen_capture.dart`
  once per situation: the real window, headless under `xvfb-run` inside `dbus-run-session`, with config and runtime
  folders of its own, against the mock (`MockMachine`, served in the test's own process at `PORELO_SOCKET`), and a
  stand-in for Porelo's command line that answers `porelo org` with the contract's example organization
  (`tool/capture_screens.organization.json`) and refuses everything else. The SDK's own `flutter` runs it, since the
  snap's wrapper cannot start inside a D-Bus session of its own. The text is drawn in the desktop's own fonts, the
  window's real ones, never the test font's boxes.
- **Situations.** `full`: the mock's machine with six pieces of work, two projects, one connection blocked and the
  organization `acme`; `empty`: the mock's machine nothing ever ran on, and no organization; `lost`: the full one
  whose machine stopped, captured once the window says it cannot reach it.
- **Screens.** Each is reached through `ShellModel` as the side bar and the finder reach it: the eight places, the
  machine's facts and its seven sections, a project's page, the organization's facts and its five sections, what
  opens over the frame (a piece of work, the gate, the egress, the backups, what this session ran), the finder, and
  the dialogs of the finder's commands named in `tool/capture_screens.dialogs`, each pressed where the finder shows
  it and every wizard step as far as *Next* goes with nothing typed. Every screen is taken at 390x844, 1024x768 and
  1920x1080, light and dark, by a `RepaintBoundary` around the window, as PNG files kept out of git.
- **Reading.** One reading by another model (agy, `gemini-4-argon-high`, plan mode) of contact sheets, one per
  screen, situation and theme with the three sizes side by side, and the originals beside them, against the visual
  and the logical checklist below; its report is kept beside the captures as `reading.txt`.
- **Visual checklist:** alignment; spacing; text cut or overflowing; contrast, and the dark theme; one type scale;
  empty and error states; labels and language; the primary action plain; small windows.
- **Logical checklist:** is the structure sensible (navigation, what lives where, what a person looks for first); do
  names and states agree across screens; does each screen say what the person must do next; are there dead ends or
  duplicate ways.
- **Findings.** Each finding is listed below under its screen, with the size and theme it was seen at, what was seen
  and why it matters; checked by the agent against the screen before it is listed. Nothing is fixed here: each fix
  becomes its own issue once the operator has read the list.

## Acceptance

- Every screen and dialog has its captures at the three sizes, both themes, full and empty; a screen missing from
  the captures is named as missing, never left out in silence.
- Every finding names its screen, its size and its theme, and the reading's report is kept beside the captures.

## Findings

Read once by agy (`gemini-4-argon-high`) from the captures of 2026-11-10; its report is `reading.txt` beside them. Each line
gives the reading's number, the size, the theme, the situation and the kind. 190 findings are listed (121 visual, 69 logical), and one the capture itself found;
19 of the reading's lines are not listed, each with why, at the end.

### Seen by the capture

- **C1** · all sizes · light and dark · lost · logical: the window said it could not reach the machine only 56 s after
  the machine stopped, and showed it as connected until then (the first capture of the lost situation, taken 4 s
  after the stop, still read *Connected to laptop*).

### Every screen

- **1** · 390x844 · light and dark · all · visual: The bottom status bar truncates all three segments with ellipses ("Connected to lap…", "Actions aske…", "laptop · 0.1.0+m…"), hiding the machine name, action counts, and version number that the bar exists to show.
- **2** · 1024x768 · light and dark · all · visual: The bottom status bar truncates the connection segment ("Connected to laptop, Porelo 0.1.0+mo…" or "Cannot reach laptop: cannot reach /t…") and the actions segment ("Actions asked here on laptop: 0 r…") with ellipses even though wide empty space remains in the bar.
- **3** · 390x844 · light and dark · empty · visual: The top bar's right-side organization indicator "No organization" is truncated to "No organiza…" and leaves so little room on the left that the screen title truncates to fragments like "Needs y…", "My mac…", "My proj…", "My card…", "Organiz…", "Creden…", "Agents …", "Managi…", and "laptop ›…".
- **4** · 1024x768 · light and dark · all · visual: The left sidebar's vertical scrollbar overlaps the right-aligned item counts and badges, and the sidebar is too short to show all top-level places at once, scrolling either "Work" at the top or "Organizations" at the bottom out of view and slicing items like "Projects" in half at the top edge.
- **5** · all · light and dark · full · logical: The sidebar count next to "My forges" reads "0" on "place-work", "place-attention", "place-planning", and "place-machines", then changes to "1" on "place-forges" and subsequent screens, so the navigation bar disagrees with itself about whether a forge is configured.

### place-attention

- **7** · 390x844 · light and dark · full · visual: In the "Also needs you" card ("Held messages · laptop"), the "Ask again" button at the bottom is sliced horizontally by the bottom edge of the viewport, and the first card's title ("porelo-checkout-shell asks to reach api.ex…") and status pill ("Asks to reach api.example.test:443 · 2 minut…") truncate with ellipses instead of wrapping.
- **8** · 1024x768 · light and dark · full · visual: Card titles and status pills ("porelo-checkout-shell as…", "Asks to reach api.exam…", "porelo-checkout-mi…", "Its work waits for r…", "Held messages · lap…") truncate with ellipses even though more than half of each card's width is empty whitespace.
- **10** · all · light and dark · empty · logical: On an empty machine that nothing ever ran on, "Needs you" shows a red badge "1" and "1 need you" for "Held messages · laptop / Cannot list — This machine cannot say whom work may talk to", turning an unsupported background listing into an urgent user attention item.
- **11** · all · light and dark · lost · logical: When "laptop" stops answering, the two previously known attention items ("porelo-checkout-shell asks to reach api.example.test:443" and "porelo-checkout-migrate: 1 commit waits at the gate") disappear instead of keeping the last list, and the replacement row title reads "laptop · laptop", repeating the machine name twice.

### place-work

- **12** · 390x844 · light and dark · full · visual: Work row subtitles truncate the agent name with ellipses ("checkout · an-age… · on laptop", "moved-away · an-… · on laptop"), and the sixth work row ("porelo-checkout-tests") is cut off at the bottom by the status bar.
- **13** · 390x844 · light and dark · lost · visual: Work row subtitles truncate the agent name with ellipses ("checkout · an-age… · on laptop"), and the sixth work row ("porelo-checkout-tests") is partially clipped above the status bar.
- **14** · all · light and dark · lost · visual: When the machine is not answering, the "What is Work?" explanation text, the "List" and "Running" toggle labels, the "+ New work" button label, and the sidebar counts are dimmed to near-zero contrast against the background in both light and dark themes, making them almost unreadable.
- **15** · all · light and dark · full · logical: Expanded work "porelo-checkout-shell" has status badge "asks to reach a host" and says "Asks to reach api.example.test:443 · out of time", but its row buttons ("Follow its log", "Image settings", "See it in Needs you") give no action to allow or block the host it is waiting on.
- **16** · all · light and dark · empty · logical: The subtitle reads "0 pieces of work on 0 machines · 0 running" even though 1 machine ("laptop") is watched and connected ("My machines 1" in the sidebar, "Connected to laptop" in the status bar, and step 1 "A machine" checked off below).

### place-planning

- **18** · all · light and dark · all · logical: The screen is a dead end that says only "Planning comes from porelo-planner, which this window does not reach yet." with no button, link, or instruction explaining how to start, configure, or connect "porelo-planner".

### place-machines

- **19** · 390x844 · light and dark · all · visual: The info "(i)" icon sits alone on its own line above the "What is in My machines?" box instead of inline with the heading.
- **20** · all · light and dark · all · logical: "My machines" shows only aggregate counts ("Machines: 1", "State: 1 answering · 0 in preparation", "Work: 6", "Needs you: 3") and global action buttons without listing the machines themselves ("laptop") or linking to them, so on 390x844 where the sidebar is hidden there is no way to see which machine is watched or open it.

### place-forges

- **22** · 390x844 · light and dark · full · visual: The body text inside "My key on the forge" ("Whether your key is listed is not known. A service Core needs cou…") and "github.com" ("…in the vault as git.ssh.github.com · y…") is cut off mid-sentence with ellipses instead of wrapping.
- **23** · 390x844 · light and dark · empty · visual: The body text inside "My key on the forge" ("Whether your key is listed is not known. A service Core needs cou…") and "github.com" ("…in the vault as git.ssh.github.com · y…") is cut off mid-sentence with ellipses instead of wrapping.
- **24** · 390x844 · light and dark · lost · visual: The body text inside "My key on the forge" ("Whether your key is listed is not known. A service Core needs cou…") is cut off mid-sentence with an ellipsis instead of wrapping.
- **25** · all · light and dark · all · logical: "My forges" is a read-only screen with no action buttons to add a forge, add or upload an SSH key, or retry checking whether the user's key is listed.
- **27** · all · light and dark · lost · logical: When "laptop" stops answering, "My forges" drops from "1 forge" ("github.com") to "0 forges" and "No forges yet.", losing the last known list and presenting an unreachable machine as an empty state.

### place-projects

- **28** · 1024x768 · light and dark · full · visual: Inside the "checkout" card, the "Project Admin" badge and the "Connect to build" button are stacked with no vertical gap, touching the top border of the card and each other.
- **29** · 1920x1080 · light and dark · full · visual: Inside the "checkout" card, the "Project Admin" badge and the "Connect to build" button are stacked with no vertical gap, touching the top border of the card and each other.
- **30** · 1024x768 · light and dark · lost · visual: Inside the "checkout" card, the "Project Admin" badge and the "Connect to build" button are stacked with no vertical gap, touching the top border of the card and each other.
- **31** · 1920x1080 · light and dark · lost · visual: Inside the "checkout" card, the "Project Admin" badge and the "Connect to build" button are stacked with no vertical gap, touching the top border of the card and each other.
- **32** · all · light and dark · full · logical: Lists only "1 project" ("checkout") while "place-work" shows work running in "billing" and "moved-away" and "machine-projects" lists 5 projects ("billing", "checkout", "Default", "moved-away", "never-run"), so project lists and counts disagree across screens.
- **33** · all · light and dark · lost · logical: Lists "1 project" ("checkout · 1 machine") and leaves the "Connect to build" button enabled without indicating that its machine ("laptop") is not answering.
- **34** · all · light and dark · empty · logical: Shows only the text "This computer belongs to no organization yet." with no button or link to choose or create an organization, making the screen a dead end.

### place-cards

- **35** · all · light and dark · all · logical: The entire screen is blank except for a single centered button "My key and card…" that opens a modal dialog, rather than showing the user's key and card ("alice · trusted", which "place-organizations" already displays) directly on the page.

### place-organizations

- **36** · 390x844 · light and dark · all · visual: The info "(i)" icon sits alone on its own line above the "What is the Porelo organization?" box instead of inline with the heading.
- **37** · all · light and dark · full · visual: Displays the literal words "a warning" on their own red line above two actual warning sentences ("A change was refused…", "mia is the only owner…"), reading like an unformatted placeholder string.
- **38** · all · light and dark · lost · visual: Displays the literal words "a warning" on their own red line above two actual warning sentences ("A change was refused…", "mia is the only owner…"), reading like an unformatted placeholder string.
- **39** · all · light and dark · full · logical: Shows "Working in: acme" as plain unclickable text and makes "Choose another Porelo organization…" the primary button, providing no link or button in the main pane to open "acme" or its sections while "Organizations 1 >" is collapsed in the sidebar.
- **40** · all · light and dark · lost · logical: Shows "Working in: acme" as plain unclickable text and makes "Choose another Porelo organization…" the primary button, providing no link or button in the main pane to open "acme" or its sections while "Organizations 1 >" is collapsed in the sidebar.
- **41** · all · light and dark · empty · logical: Repeats "This computer belongs to no organization yet." twice on consecutive lines, and labels the primary button "Choose another Porelo organization…" when no organization has been chosen yet.

### project

- **42** · all · light and dark · all · visual: The three-dots overflow icon ("⋮") floats in empty space — centered on its own blank line between "on laptop" and "Open the project's room" at 390x844, and floating roughly 150px to the right of the heading "checkout" instead of at the right margin at 1024x768 and 1920x1080.
- **43** · all · light and dark · all · logical: The top bar title says "laptop › checkout" while the breadcrumb below it says "My projects › checkout", and the page lists only "Machines (1 machine): laptop" without listing the project's work ("1 of 3 running"), repositories, or any button/link to review the "2 waiting at the gate" or start work.
- **45** · all · light and dark · lost · logical: When "laptop" stops answering, the summary still claims "1 of 3 running · guarded" as if live, and "Open the project's room" is disabled with no explanation that the machine is not answering.

### machine

- **46** · all · light and dark · all · visual: Displays an unlabelled standalone padlock/warning icon on its own line above "Last read", separate from the "Vault:" line four rows below, and repeats the socket path "/tmp/…/run/laptop" twice (once under the heading "laptop" and again at "Address:").
- **47** · all · light and dark · full · visual: The vault status line reads "Vault: Open · 1 entries" ("1 entries" instead of "1 entry").
- **48** · all · light and dark · empty · visual: The vault status line reads "Vault: Open · 1 entries" ("1 entries" instead of "1 entry").
- **49** · 390x844 · light and dark · all · visual: The action buttons and disabled-action explanations at the bottom of the page are cut off by the bottom status bar.
- **50** · 1024x768 · light and dark · lost · visual: The disabled-action explanations at the bottom of the page are cut off by the bottom status bar.
- **51** · all · light and dark · full · logical: Says "Health: not read — run Check whether this machine can run anything", contradicting "machine-health" ("9 checks · 1 not fine"), "machine-managing" ("Can run work / Not fine: rootless network backend"), and the 1920x1080 background of "dialog-add-another-user-that-runs-work" where health is already read.
- **53** · all · light and dark · lost · logical: Replaces the last known "Vault", "Tasks", and "Projects" counts with "not read" instead of keeping the last known values, and leaves the destructive button "Clear this machine of everything Porelo put there…" enabled while the machine is not answering.

### machine-tasks

- **54** · all · light and dark · all · logical: Names the section and count "Tasks" ("6 tasks · 4 running") while the primary button on the same screen says "+ New work" and the sidebar place showing the exact same 6 items is called "Work" ("6 pieces of work").
- **55** · 390x844 · light and dark · full · visual: Row subtitles truncate the agent name with ellipses ("checkout · an-age… · on laptop", "moved-away · an-… · on laptop"), and the sixth row ("porelo-checkout-tests") is cut off at the bottom by the status bar.
- **56** · all · light and dark · empty · logical: On an empty machine with "0 tasks · 0 running" and an empty filter input, the page says "Nothing matches the filter." with a "Clear the filter" link instead of an empty state saying no work has run on this machine yet.
- **57** · all · light and dark · lost · visual: Renders the breadcrumb "My machines › laptop › Tasks" and the heading "Tasks" twice — once at the top above "laptop does not answer." and a second dimmed copy below the "Try again" button — and states three separate times on the same screen that the machine is not answering.

### machine-projects

- **58** · all · light and dark · all · visual: The top disabled button label is truncated mid-phrase as "Put a project on… — waits for a command" even at 1920x1080 where the button spans the full window width with wide empty space inside it.
- **59** · 390x844 · light and dark · full · visual: Project row subtitles truncate with ellipses ("needed · Environment older t…", "needed · 1 waiting for review…"), and the fifth project ("never-run") is cut off at the bottom by the status bar.
- **60** · 390x844 · light and dark · empty · visual: Project row subtitles truncate with ellipses ("needed · Environment older t…", "needed · 1 waiting for review…"), and the fifth project ("never-run") is cut off at the bottom by the status bar.
- **61** · all · light and dark · full · logical: Under "laptop › Projects", the row for "moved-away" says "on laptop · No SSH tunnel needed · 1 waiting for review · Not on this machine" with badge "Not on this machine", contradicting itself about whether the project is on "laptop".
- **63** · all · light and dark · lost · logical: When "laptop" stops answering, all 5 previously known projects disappear and are replaced by "not read" instead of keeping the last list.

### machine-vault

- **64** · 390x844 · light and dark · all · visual: The three-dots overflow icon ("⋮") sits alone on its own centered row between the "Store an entry…" button and the "Filter the entries" field.
- **65** · 1024x768 · light and dark · all · visual: The three-dots overflow icon ("⋮") wraps onto its own line below the left edge of the "Store an entry…" button instead of aligning with the button row.
- **66** · 390x844 · light and dark · full · visual: The "Devices that open it" section at the bottom is cut off by the bottom status bar.
- **67** · 390x844 · light and dark · empty · visual: The "Devices that open it" section at the bottom is cut off by the bottom status bar.
- **68** · all · light and dark · full · visual: The subtitle reads "Made · open · 1 entries" ("1 entries" instead of "1 entry").
- **69** · all · light and dark · empty · visual: The subtitle reads "Made · open · 1 entries" ("1 entries" instead of "1 entry").
- **71** · all · light and dark · lost · logical: When "laptop" stops answering, the stored entry "a-provider" disappears instead of keeping the last list, and "Devices that open it" (which was "not read" when connected in "full") changes to badge "0" and "None is listed.", showing an unknown state on an unreachable machine as 0 / empty.

### machine-credentials

- **72** · all · light and dark · full · visual: Under "Destinations not read", displays both a "not read" callout box above the description text and a second error line "This machine cannot list its destinations." below it, duplicating the same error state.
- **73** · all · light and dark · empty · visual: Under "Destinations not read", displays both a "not read" callout box above the description text and a second error line "This machine cannot list its destinations." below it, duplicating the same error state.
- **75** · all · light and dark · lost · logical: When "laptop" stops answering, the "ssh://github.com" connection disappears instead of keeping the last list, and both "+ Add a connection" (the primary button) and "+ Add a destination" remain enabled even though the page says "laptop does not answer."

### machine-agents

- **76** · all · light and dark · full · visual: Provider rows repeat their status badge text verbatim in the subtitle right below ("A Provider [authenticated]" above "a-provider · authenticated", and "Another Provider [not authenticated]" above "other-provider · not authenticated").
- **77** · all · light and dark · empty · visual: Provider rows repeat their status badge text verbatim in the subtitle right below ("A Provider [authenticated]" above "a-provider · authenticated", and "Another Provider [not authenticated]" above "other-provider · not authenticated").
- **78** · 1024x768 · light and dark · full · visual: The second provider row ("Another Provider") and the explanatory footer note below "Providers 2" are cut off at the bottom of the viewport.
- **79** · 1024x768 · light and dark · empty · visual: The second provider row ("Another Provider") and the explanatory footer note below "Providers 2" are cut off at the bottom of the viewport.
- **80** · 390x844 · light and dark · full · visual: The entire "Providers 2" section is cut off below the bottom of the viewport.
- **81** · 390x844 · light and dark · empty · visual: The entire "Providers 2" section is cut off below the bottom of the viewport.
- **82** · all · light and dark · full · logical: The subtitle says "2 agents · 2 providers" and the section header badge says "Agents 2", but the "Agents" list renders 4 rows ("An Agent", "Another Agent", "Never-Used Agent", "broken-agent"), so the count disagrees with the list.
- **84** · all · light and dark · all · logical: Places a "Providers on this machine" action button at the top of a page that is already "Agents & providers" on this machine and already lists "Providers" in the lower half of the same screen.
- **85** · all · light and dark · lost · logical: When "laptop" stops answering, both the "Agents" list and the "Providers" list disappear and are replaced by "not read" instead of keeping the last known lists.

### machine-health

- **86** · 1024x768 · light and dark · full · visual: The 8th check row ("rootless network backend · Not fine" — the only warning on the page) is sliced horizontally mid-line at the bottom edge of the viewport, hiding its remediation text ("install pasta (passt) and restart the daemon") and the 9th check ("SELinux policy").
- **87** · 1024x768 · light and dark · empty · visual: The 8th check row ("rootless network backend · Not fine" — the only warning on the page) is sliced horizontally mid-line at the bottom edge of the viewport, hiding its remediation text ("install pasta (passt) and restart the daemon") and the 9th check ("SELinux policy").
- **88** · 390x844 · light and dark · full · visual: Only the first 4 of 9 health checks fit in the viewport, cutting off the only warning check ("rootless network backend · Not fine") below the fold while all visible checks look "Fine".
- **89** · 390x844 · light and dark · empty · visual: Only the first 4 of 9 health checks fit in the viewport, cutting off the only warning check ("rootless network backend · Not fine") below the fold while all visible checks look "Fine".
- **90** · all · light and dark · lost · logical: When "laptop" stops answering, all 9 previously known health checks disappear instead of keeping the last list, and the primary button "Check whether this machine can run anything" stays enabled even though the page says "laptop does not answer." and "machine", "machine-managing", and "finder" disable that action when lost.

### machine-managing

- **91** · 390x844 · light and dark · all · visual: The "Danger zone" section and bottom action buttons are cut off below the bottom status bar.
- **92** · 1024x768 · light and dark · lost · visual: The "Danger zone" section at the bottom of the page is cut off by the bottom status bar.
- **93** · all · light and dark · all · logical: Duplicates the "machine" ("laptop") overview screen in the same sidebar menu — showing the same 4 status facts ("Connection", "Vault", "Work", "Health") and the same machine buttons ("Check whether this machine can run anything", "Refresh from the backend", "Shut the vault", "Stop Porelo on this machine", "Stop everything on this machine", "Clear this machine of everything Porelo put there") — while disagreeing with "machine" on "Health" ("Can run work / Not fine: rootless network backend" here vs "not read" on "machine") and "Last read" ("less than a minute ago" here vs "not read — the connection does not report a read time" on "machine").
- **95** · all · light and dark · lost · logical: Replaces the last known "Vault", "Work", and "Health" summary cards with "not read" instead of keeping the last known values, and leaves the destructive button "Clear this machine of everything Porelo put there" enabled in "Danger zone" when the machine is not answering.

### organization

- **96** · all · light and dark · full · visual: Prints a raw microsecond timestamp ("Last read: 2026-11-10 16:59:50.493712") instead of a human-readable time like "less than a minute ago" used on the organization subpages, and prints the literal words "a warning" on their own red line above the two warning messages.
- **97** · all · light and dark · lost · visual: Prints a raw microsecond timestamp ("Last read: 2026-11-10 17:14:43.829524") instead of a human-readable time like "less than a minute ago" used on the organization subpages, and prints the literal words "a warning" on their own red line above the two warning messages.
- **98** · all · light and dark · full · logical: Says "Proposed cards: not read — the organization source does not list proposed cards", contradicting "organization-people" which reports "4 people · 1 card waits" in its subtitle.
- **99** · all · light and dark · lost · logical: Says "Proposed cards: not read — the organization source does not list proposed cards", contradicting "organization-people" which reports "4 people · 1 card waits" in its subtitle.
- **100** · all · light and dark · full · logical: Shows "People: 4", "Projects: 1", "Machines: 2", and "Organization owners: 1" as plain unclickable text lines and makes "Choose another Porelo organization…" the primary button while viewing "acme", with "acme" collapsed in the sidebar on "place-organizations".
- **101** · all · light and dark · lost · logical: Shows "People: 4", "Projects: 1", "Machines: 2", and "Organization owners: 1" as plain unclickable text lines and makes "Choose another Porelo organization…" the primary button while viewing "acme", with "acme" collapsed in the sidebar on "place-organizations".

### organization-people

- **102** · all · light and dark · full · visual: The three warning lines ("a warning", "A change was refused…", "mia is the only owner…") sit at the very top of the page above the "Organizations › acme › People" breadcrumb in plain muted grey text with no warning color, icon, or container.
- **103** · all · light and dark · lost · visual: The three warning lines ("a warning", "A change was refused…", "mia is the only owner…") sit at the very top of the page above the "Organizations › acme › People" breadcrumb in plain muted grey text with no warning color, icon, or container.
- **104** · all · light and dark · full · logical: The subtitle says "4 people · 1 card waits", contradicting "organization" ("Proposed cards: not read"), and the waiting card itself is not shown anywhere on the page while "Accept a proposed card…" is disabled ("waits for a command").
- **105** · all · light and dark · lost · logical: The subtitle says "4 people · 1 card waits", contradicting "organization" ("Proposed cards: not read"), and the waiting card itself is not shown anywhere on the page while "Accept a proposed card…" is disabled ("waits for a command").

### organization-projects

- **106** · all · light and dark · full · visual: The three warning lines ("a warning", "A change was refused…", "mia is the only owner…") sit above the "Organizations › acme › Projects" breadcrumb in plain muted grey text, and inside the "checkout" card the "Project Admin" pill and "Connect to build" button are crammed together at the top border at 1024x768 and 1920x1080.
- **107** · all · light and dark · lost · visual: The three warning lines ("a warning", "A change was refused…", "mia is the only owner…") sit above the "Organizations › acme › Projects" breadcrumb in plain muted grey text, and inside the "checkout" card the "Project Admin" pill and "Connect to build" button are crammed together at the top border at 1024x768 and 1920x1080.
- **108** · all · light and dark · lost · logical: Shows "checkout · 1 machine" and leaves "Connect to build" enabled without indicating that "laptop" is not answering.

### organization-machines

- **109** · all · light and dark · full · visual: The three warning lines ("a warning", "A change was refused…", "mia is the only owner…") sit above the "Organizations › acme › Machines" breadcrumb in plain muted grey text.
- **110** · all · light and dark · lost · visual: The three warning lines ("a warning", "A change was refused…", "mia is the only owner…") sit above the "Organizations › acme › Machines" breadcrumb in plain muted grey text.
- **111** · 390x844 · light and dark · full · visual: Machine row subtitles and badges truncate with ellipses ("carries checkout · yo…", "Machine Admin ha…", "not set up yet. It …"), hiding the admin's name and status details.
- **112** · 1024x768 · light and dark · full · visual: Machine row subtitles and badges truncate with ellipses ("carries checkout · yo…", "Machine Admin ha…", "not set up yet. It …"), hiding the admin's name and status details despite empty horizontal space inside each card.
- **113** · 390x844 · light and dark · lost · visual: Machine row subtitles and badges truncate with ellipses ("carries checkout · yo…", "Machine Admin ha…", "not set up yet. It …"), hiding the admin's name and status details.
- **114** · 1024x768 · light and dark · lost · visual: Machine row subtitles and badges truncate with ellipses ("carries checkout · yo…", "Machine Admin ha…", "not set up yet. It …"), hiding the admin's name and status details despite empty horizontal space inside each card.
- **115** · all · light and dark · lost · logical: Shows the "laptop" row ("carries checkout · you are Machine Admin · Machine Admin: alice") with no indication that "laptop" is currently not answering.

### organization-owners

- **116** · all · light and dark · full · visual: The three warning lines ("a warning", "A change was refused…", "mia is the only owner…") sit above the "Organizations › acme › Organization owners" breadcrumb in plain muted grey text.
- **117** · all · light and dark · lost · visual: The three warning lines ("a warning", "A change was refused…", "mia is the only owner…") sit above the "Organizations › acme › Organization owners" breadcrumb in plain muted grey text.
- **118** · 390x844 · light and dark · full · visual: The top bar title truncates to "Organization …", hiding whether the screen is "Organization owners" or "Organization Admins", and the filter placeholder truncates to "Filter organization o…".
- **119** · 390x844 · light and dark · lost · visual: The top bar title truncates to "Organization …", hiding whether the screen is "Organization owners" or "Organization Admins", and the filter placeholder truncates to "Filter organization o…".
- **120** · all · light and dark · full · logical: The row for "mia" has a grey badge "not read" with no explanation of what was not read, even though her role "organization owner" is displayed and the warning at the top of the same page already knows "mia is the only owner and has no backup key."
- **121** · all · light and dark · lost · logical: The row for "mia" has a grey badge "not read" with no explanation of what was not read, even though her role "organization owner" is displayed and the warning at the top of the same page already knows "mia is the only owner and has no backup key."

### organization-admins

- **122** · all · light and dark · full · visual: The three warning lines ("a warning", "A change was refused…", "mia is the only owner…") sit above the "Organizations › acme › Organization Admins" breadcrumb in plain muted grey text, and "Organization Admins" capitalizes "Admins" while "Organization owners" directly above it in the sidebar uses lowercase "owners".
- **123** · all · light and dark · lost · visual: The three warning lines ("a warning", "A change was refused…", "mia is the only owner…") sit above the "Organizations › acme › Organization Admins" breadcrumb in plain muted grey text, and "Organization Admins" capitalizes "Admins" while "Organization owners" directly above it in the sidebar uses lowercase "owners".
- **124** · 390x844 · light and dark · full · visual: The top bar title truncates to "Organization …", making it indistinguishable from "Organization owners", and the filter placeholder truncates to "Filter organization a…".
- **125** · 390x844 · light and dark · lost · visual: The top bar title truncates to "Organization …", making it indistinguishable from "Organization owners", and the filter placeholder truncates to "Filter organization a…".
- **126** · all · light and dark · full · logical: The subtitle reads "not read · read less than a minute ago", directly contradicting itself ("not read" vs "read less than a minute ago").
- **127** · all · light and dark · lost · logical: The subtitle reads "not read · read less than a minute ago", directly contradicting itself ("not read" vs "read less than a minute ago").

### opened-work

- **128** · all · light and dark · full · visual: In the "Standing instructions" line under "Environment", the bold label "Standing instructions" runs directly into its value "in the repository — nothing here has a view of them" without a colon or horizontal spacing.
- **129** · all · light and dark · lost · visual: In the "Standing instructions" line under "Environment", the bold label "Standing instructions" runs directly into its value "in the repository — nothing here has a view of them" without a colon or horizontal spacing.
- **130** · all · light and dark · full · logical: The detail pane for "porelo-checkout-shell" is a read-only dead end with zero action buttons — you cannot allow or refuse the "api.example.test:443" connection it is waiting on, open its logs, write to its agent, or stop it from its own detail screen, nor does the pane state which machine the work runs on.
- **131** · all · light and dark · lost · logical: When "laptop" stops answering, the "porelo-checkout-shell" detail pane never says in the pane that the machine is not answering and continues to display live-looking runtime assertions ("Doing: waiting", "Runtime says: Up 6 minutes", "Helpers alive: 2").

### opened-gate

- **132** · all · light and dark · all · visual: The header reads "Waiting at the gate ·" with a trailing middle dot and the project name missing after it. *(Note: seen when opened over Work, as the capture opened it; from the project page the name may show.)*
- **135** · all · light and dark · lost · logical: When "laptop" stops answering, "Waiting at the gate ·" shows "Nothing is waiting. Everything this project pushed has been decided." instead of saying the machine is not answering and keeping the last known waiting commits.

### opened-egress

- **136** · all · light and dark · all · visual: The header reads "What  may reach" with a double space where the project name is missing between "What" and "may". *(Note: seen when opened over Work, as the capture opened it.)*
- **137** · all · light and dark · all · logical: The "Reachable now" section heading has nothing below it — neither a list of reachable destinations nor an empty/unknown state message — and the screen provides no button to add or revoke a grant.
- **138** · all · light and dark · lost · logical: When "laptop" stops answering, "What  may reach" says "None is installed. That is a state, not a failure." under "Ruleset", presenting an unreachable machine as a healthy empty state instead of saying the connection is lost.

### opened-backups

- **139** · all · light and dark · all · visual: The header reads "Backups of " with the project name missing after "of". *(Note: seen when opened over Work, as the capture opened it.)*
- **140** · all · light and dark · lost · logical: When "laptop" stops answering, "Backups of " says "Nothing is recorded for this project." instead of stating that the machine is not answering.

### opened-operations

- **141** · 1024x768 · light and dark · all · visual: The subtitle "Kept for 30 days in <the state folder>/operations.json" is centered horizontally across the pane while the heading "Operations" and the operation rows below it are left-aligned. *(Note: the path shown was the person's own, since this run did not yet give the window a state folder of its own.)*
- **142** · 1920x1080 · light and dark · all · visual: The subtitle "Kept for 30 days in <the state folder>/operations.json" is centered horizontally across the pane while the heading "Operations" and the operation rows below it are left-aligned. *(Note: as 141.)*

### finder

- **145** · 390x844 · light and dark · all · visual: Command titles and unavailability reasons in the finder list truncate with ellipses ("Check whether this machine can run anyt…", "Unavailable: this device is not enrolled on t…").
- **146** · all · light and dark · lost · logical: In the "lost" situation, "Add another user that runs work…" remains enabled in the finder while every other machine command for "laptop" is marked "unavailable: the machine is not answering".

### dialog-about-porelo

- **147** · all · light and dark · lost · logical: When "laptop" is not answering, the "About Porelo" dialog still lists "laptop: Porelo 0.1.0+mock" as if connected without noting that contact with "laptop" is lost.

### dialog-add-another-user-that-runs-work

- **148** · all · light and dark · all · visual: Opening "Add another user that runs work…" leaves the machine page's "⋮" overflow menu open on top of or beside the modal dialog, covering the dialog on 390x844 and 1024x768. *(Note: seen after the capture's tap on the menu entry; to be tried by hand.)*
- **149** · 1920x1080 · light and dark · all · logical: In the open "⋮" overflow menu on 1920x1080, "Start Porelo on this machine" is listed twice at the top — once without a subtitle and once right below it with "Unavailable: its socket is forwarded by somebody else".
- **150** · all · light and dark · lost · logical: Even though "laptop" is not answering and the other machine commands in the same "⋮" menu are disabled with "Unavailable: the machine is not answering", "Add another user that runs work…" stays enabled and opens the "Add a user to a machine" dialog without warning that the machine cannot be reached.

### dialog-change-what-this-work-does-with-a-blocked-connection

- **151** · 390x844 · light and dark · full · visual: Inside the dialog, the fourth option card ("Stop asking entirely") is clipped at the bottom so its description ("Nothing is refused and nothing is asked…") is cut off above "Leave it as it is".
- **152** · all · light · empty · visual: In the finder, the bright cyan selection highlight behind the disabled row "Change what this work does with a blocked connection / Work · unavailable: no work is selected" reduces the pale grey text to near-zero contrast.
- **153** · all · light · lost · visual: In the finder, the bright cyan selection highlight behind the disabled row "Change what this work does with a blocked connection / Work · unavailable: the machine is not answering" reduces the pale grey text to near-zero contrast.

### dialog-choose-another-porelo-organization

- **154** · all · light and dark · full · visual: The dialog body prints raw markdown asterisks around "*Create another Porelo organization…*" instead of rendering italic or quoted text, and names a button that does not match the actual button label on the page behind it ("Create an organization…").
- **155** · all · light and dark · lost · visual: The dialog body prints raw markdown asterisks around "*Create another Porelo organization…*" instead of rendering italic or quoted text, and names a button that does not match the actual button label on the page behind it ("Create an organization…").
- **156** · all · light and dark · empty · visual: The dialog body prints raw markdown asterisks around "*Create the Porelo organization…*", and the dialog title says "Choose the Porelo organization" while the button visible behind it says "Choose another Porelo organization…" and the creation button says "Create an organization…".
- **157** · 390x844 · light and dark · all · visual: The floating label on the text field ("The Porelo organization's repository address") is truncated to "The Porelo organization's repository a…".

### dialog-clear-this-machine-of-everything

- **158** · all · light and dark · full · logical: Although the machine screen already read "Porelo: 0.1.0+mock", "Clear this machine of everything Porelo put there…" is left enabled and opens a dead-end dialog saying only "laptop cannot be cleared in one step: its Porelo is older than that." with a "Cancel" button, instead of disabling the button with that reason or explaining how to clear it. *(Note: the mock has no one-step clearing, as an older Porelo.)*
- **159** · all · light and dark · empty · logical: Although the machine screen already read "Porelo: 0.1.0+mock", "Clear this machine of everything Porelo put there…" is left enabled and opens a dead-end dialog saying only "laptop cannot be cleared in one step: its Porelo is older than that." with a "Cancel" button, instead of disabling the button with that reason or explaining how to clear it. *(Note: as 158.)*
- **160** · all · light and dark · lost · logical: When "laptop" is not answering, "Clear this machine of everything Porelo put there…" is not disabled like the other machine buttons; clicking it opens a dead-end dialog that fails with "Lost contact with laptop: cannot reach /tmp/…/laptop: Connection failed". *(Note: as 158.)*

### dialog-clear-this-project-from-the-machine

- **161** · all · light and dark · full · logical: Although "laptop" is already known to run "Porelo: 0.1.0+mock", "Clear this project from the machine…" opens a dead-end dialog saying only "laptop cannot be cleared in one step: its Porelo is older than that." with a "Cancel" button. *(Note: as 158.)*
- **162** · all · light and dark · empty · logical: Although "laptop" is already known to run "Porelo: 0.1.0+mock", "Clear this project from the machine…" opens a dead-end dialog saying only "laptop cannot be cleared in one step: its Porelo is older than that." with a "Cancel" button. *(Note: as 158.)*
- **163** · all · light · lost · visual: In the finder, the bright cyan highlight behind the disabled row "Clear this project from the machine… / Project · unavailable: the machine is not answering" makes the pale grey text nearly unreadable.

### dialog-create-an-organization

- **164** · all · light and dark · all · logical: The dialog title ("Create another Porelo organization" in full/lost, "Create the Porelo organization" in empty) disagrees with the button label on the page behind it ("Create an organization…") and the finder command ("Create an organization").
- **165** · 390x844 · light and dark · all · visual: The floating label on the text field ("The Porelo organization's repository address") is truncated to "The Porelo organization's repository a…".

### dialog-give-this-work-something-to-read-by

- **166** · all · light and dark · full · logical: Uses four different names for the same concept across the command and dialog ("Give this work something to read by…", "What should this read as?", "Reads as", and "the caption"), and keeps the primary button "Use it" enabled when the input is empty and no caption is set, where clicking it does the same thing as "Leave it".
- **167** · 390x844 · light and dark · full · visual: The placeholder text inside the input box ("schema migration, second attempt") is truncated to "schema migration, second a…".
- **168** · all · light · empty · visual: In the finder, the bright cyan highlight behind the disabled row "Give this work something to read by / Work · unavailable: no work is selected" makes the pale grey text nearly unreadable.
- **169** · all · light · lost · visual: In the finder, the bright cyan highlight behind the disabled row "Give this work something to read by / Work · unavailable: the machine is not answering" makes the pale grey text nearly unreadable.

### dialog-hold-its-project-s-messages-to-a-peer

- **170** · all · light and dark · full · logical: Even though the dialog displays the red error "This machine cannot say whom work may talk to." and lists no peers, it leaves an active toggle switch below "What happened to its messages" labeled "For every task of checkout, not only this one" whose effect is ambiguous and which calls work a "task".
- **171** · all · light · empty · visual: In the finder, the bright cyan highlight behind the disabled row "Hold its project's messages to a peer / Work · unavailable: no work is selected" makes the pale grey text nearly unreadable.
- **172** · all · light · lost · visual: In the finder, the bright cyan highlight behind the disabled row "Hold its project's messages to a peer / Work · unavailable: the machine is not answering" makes the pale grey text nearly unreadable.

### dialog-keep-resolved-rows-for

- **173** · all · light and dark · all · logical: The dialog title "Keep resolved rows for" and helper text "0 removes rows immediately." never state which screen's or feature's resolved rows are affected, and the primary button is labeled "Keep" (sounding like keeping rows rather than saving a setting).

### dialog-let-this-work-reach-something-new

- **174** · 390x844 · light and dark · full · visual: The placeholder text in "Machine names" ("files.example.test, docs.example.test") truncates to "files.example.test, docs.e…", and the footer buttons "Leave it as it is" and "Show what this would grant" stack vertically on two lines.
- **175** · all · light and dark · full · logical: Although "porelo-checkout-shell" (visible directly behind the dialog) is currently blocked asking to reach "api.example.test:443", opening "Let porelo-checkout-shell reach something new" neither pre-fills nor suggests "api.example.test", and labels the field "Machine names" whereas the work row calls it a "host" ("asks to reach a host").
- **176** · all · light · empty · visual: In the finder, the bright cyan highlight behind the disabled row "Let this work reach something new / Work · unavailable: no work is selected" makes the pale grey text nearly unreadable.
- **177** · all · light · lost · visual: In the finder, the bright cyan highlight behind the disabled row "Let this work reach something new / Work · unavailable: the machine is not answering" makes the pale grey text nearly unreadable.

### dialog-my-key-and-card

- **178** · all · light and dark · full · logical: Shows no cached card or key information when "Read my card again" fails, even though "place-organizations" and "organization" already have "Your card: alice · trusted" in the same session.
- **179** · all · light and dark · lost · logical: Shows no cached card or key information when "Read my card again" fails, even though "place-organizations" and "organization" already have "Your card: alice · trusted" in the same session.

### dialog-new-machines-run-work-as

- **180** · 390x844 · light and dark · all · visual: The helper text below the input ("Created on a new machine by Porelo's setup script. Machines already set up keep theirs.") is truncated with an ellipsis ("…Machines already set up …") instead of wrapping onto a third line.

### dialog-read-one-of-its-logs

- **181** · all · light and dark · full · visual: In "Read a log of porelo-checkout-shell", the four log entries ("agent.log", "gate.log", "events.jsonl", "reader.err") have no button, border, icon, or hover/row styling to look clickable, "agent.log" and "gate.log" have no description while the other two do, and timestamps are shown as raw ISO-8601 strings ("2026-09-07T14:12:00Z").
- **182** · all · light · empty · visual: In the finder, the bright cyan highlight behind the disabled row "Read one of its logs / Work · unavailable: no work is selected" makes the pale grey text nearly unreadable.
- **183** · all · light · lost · visual: In the finder, the bright cyan highlight behind the disabled row "Read one of its logs / Work · unavailable: the machine is not answering" makes the pale grey text nearly unreadable.

### dialog-remove-it

- **184** · all · light and dark · full · visual: The primary button "Remove it", which permanently destroys the container and its workspace, is styled in the standard teal primary color instead of the destructive red used for "Stop everything everywhere".
- **185** · all · light · empty · visual: In the finder, the bright cyan highlight behind the disabled row "Remove it / Work · unavailable: no work is selected" makes the pale grey text nearly unreadable.
- **186** · all · light · lost · visual: In the finder, the bright cyan highlight behind the disabled row "Remove it / Work · unavailable: the machine is not answering" makes the pale grey text nearly unreadable.

### dialog-show-what-this-project-would-open

- **189** · all · light · lost · visual: In the finder, the bright cyan highlight behind the disabled row "Show what this project would open, creating nothing / Project · unavailable: the machine is not answering" makes the pale grey text nearly unreadable.

### dialog-start-work-in-this-project

- **190** · 390x844 · light and dark · full · visual: In "Start work in checkout", the helper text below "A name for this run" is truncated with an ellipsis ("…It names this piece of …"), and the "More options" section at the bottom is scrolled out of view.
- **191** · 390x844 · light and dark · empty · visual: In "Start work in checkout", the helper text below "A name for this run" is truncated with an ellipsis ("…It names this piece of …"), and the "More options" section at the bottom is scrolled out of view.
- **192** · 1024x768 · light and dark · full · visual: At the bottom of the dialog scroll area, the subtitle under "More options" ("More credentials, keeping it to start again") is sliced horizontally so only the top pixels of two letters show.
- **193** · 1024x768 · light and dark · empty · visual: At the bottom of the dialog scroll area, the subtitle under "More options" ("More credentials, keeping it to start again") is sliced horizontally so only the top pixels of two letters show.
- **194** · all · light and dark · full · visual: The "How you are involved" section has a second redundant floating label "How you take part" on the dropdown border right below the bold heading "How you are involved", whereas "Which agent" above it has no floating label on its dropdown.
- **195** · all · light and dark · empty · visual: The "How you are involved" section has a second redundant floating label "How you take part" on the dropdown border right below the bold heading "How you are involved", whereas "Which agent" above it has no floating label on its dropdown.
- **196** · all · light and dark · full · logical: Pre-fills "A name for this run" with "checkout" (the bare project name) instead of a distinct work name, and does not indicate which machine the new work will start on.
- **198** · all · light · lost · visual: In the finder, the bright cyan highlight behind the disabled row "Start work in this project / Work · unavailable: the machine is not answering" makes the pale grey text nearly unreadable.

### dialog-stop-everything-on-every-machine

- **199** · 390x844 · light and dark · full · visual: The footer buttons "Leave it" and "Stop everything everywhere" stack vertically on two rows instead of sitting side by side.
- **200** · 390x844 · light and dark · empty · visual: The footer buttons "Leave it" and "Stop everything everywhere" stack vertically on two rows instead of sitting side by side.
- **201** · all · light and dark · empty · logical: Even though the dialog explicitly states "laptop: nothing is running", the destructive red action button "Stop everything everywhere" remains enabled.
- **202** · all · light · lost · visual: In the finder, the bright cyan highlight behind the disabled row "Stop everything on every machine / Machines · unavailable: no machine is answering" makes the pale grey text nearly unreadable.

### dialog-take-something-back-from-this-work

- **203** · 390x844 · light and dark · full · visual: The footer buttons "Leave it as it is" and "Show what this would take back" stack vertically on two rows instead of sitting side by side.
- **204** · all · light and dark · full · logical: Requires the user to type hostnames ("Machine names to take back") from memory ("A name that is not granted to this run is ignored, not an error.") instead of listing the hosts currently granted to "porelo-checkout-shell" so the user can see and select what to revoke.
- **205** · all · light · empty · visual: In the finder, the bright cyan highlight behind the disabled row "Take something back from this work / Work · unavailable: no work is selected" makes the pale grey text nearly unreadable.
- **206** · all · light · lost · visual: In the finder, the bright cyan highlight behind the disabled row "Take something back from this work / Work · unavailable: the machine is not answering" makes the pale grey text nearly unreadable.

### dialog-watch-another-machine

- **207** · all · light and dark · all · visual: Repeats the question "Are you an administrator there?" twice on consecutive lines — once as a bold heading and immediately below it as the floating border label on the "Choose one" dropdown.

### dialog-write-to-its-agent

- **208** · all · light · empty · visual: In the finder, the bright cyan highlight behind the disabled row "Write to its agent / Work · unavailable: no work is selected" makes the pale grey text nearly unreadable.
- **209** · all · light · lost · visual: In the finder, the bright cyan highlight behind the disabled row "Write to its agent / Work · unavailable: the machine is not answering" makes the pale grey text nearly unreadable.

### Read but not listed

- 6 (all, empty): the same as the count of My forges in full, which is listed
- 9 (place-attention, full): false: the card in Needs you holds *Keep it blocked* and *Let it through*
- 17 (place-work, empty): Default is the project every machine has, so the step is met
- 21 (place-machines, empty): the count of the one row of finding 10
- 26 (place-forges, empty): the mock's empty machine keeps its forge, connections, vault, agents and projects; only its work is empty
- 44 (project, empty): as above, the mock's empty machine keeps its projects
- 52 (machine, empty): the health half is the full situation's finding; the rest is the mock's empty machine
- 62 (machine-projects, empty): the mock's empty machine, and the moved-away half is listed under full
- 70 (machine-vault, empty): the mock's empty machine keeps its vault
- 74 (machine-credentials, empty): the mock's empty machine keeps its connections
- 83 (machine-agents, empty): the count half is listed under full; the rest is the mock's empty machine
- 94 (machine-managing, empty): the mock's empty machine keeps its vault
- 133 (opened-gate, full): not confirmed: the capture opened the gate of the first listed project, which the header does not name, so it may not be checkout
- 134 (opened-gate, empty): the mock's empty machine keeps its projects
- 143 (opened-operations, all): the capture never chose an operation, so what choosing one shows was not seen
- 144 (opened-operations, empty): those operations were the capture's own, read from the person's operations file (see How it stands)
- 187 (dialog-show-what-this-project-would-open-not-a-dialog, full): the output is what the mock prints for a preview, not what a daemon would
- 188 (dialog-show-what-this-project-would-open-not-a-dialog, empty): as 187
- 197 (dialog-start-work-in-this-project, empty): the mock's empty machine keeps its agents
