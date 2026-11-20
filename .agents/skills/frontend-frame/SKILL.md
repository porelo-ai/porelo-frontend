---
name: frontend-frame
description: porelo-frontend: the frame (layout, windows). Use when changing the frame.
---

# frontend-frame

### The frame

- **Every action is a `Command` in `commands.dart`, lives where it acts (`Command.home`), is
  reachable with a pointer alone, and is listed with its reason when it cannot run now.**
  A grey button says that reason in text, never behind a hover alone; in a row it takes the line under the title, so the
  row's height holds.
- **A refusal is an answer with its own place and sentence, never weakened to make a flow smoother**;
  a forcing button exists only where the contract has one, worded as the second decision it is.
- **Absence is rendered as absence**: an empty field from an older daemon, `UNKNOWN`, an unreadable
  vault or a lost connection never reads as a good state, and losing contact keeps the last list.
- **Nothing is applied optimistically**: a decision shows once the daemon's own answer or echo
  confirms it.
- **No layout assumes the window is never a phone's.**
- **A page's head says a departure from the normal state, never the normal state itself**, and a warning there never
  folds away; what a page is for stands behind the `i` beside its title, open on its first visit only.
- **A spacing, width, radius or colour is spelled only in `tokens.dart`, a width compared only in
  `window_size.dart`**, which reads the window, never the pane: Porelo's look lives in one place, and the
  planning screen, porelo-planner's package that imports nothing of the window, keeps its few in its own; icons are
  outlined, filled only when selected.
- **`PORELO_SOCKET` is read only in `Machine.local()`.**
- **Whoever walks `Machines.all` asks `Machines.watching`**, which is null for a machine listed and not watched yet
  (while the stored list is taken in, a host's card is replaced or a machine reconnects), and draws or answers it as
  not answering in its own words; `Machines.of` is for a caller holding a machine it opened, and throws otherwise. A
  reader that keeps a fleet across a reconnect follows it with `Machines.follow`.
- **A node is an OS user with a `porelod`, so nothing is keyed by hostname alone; a host is an egress
  destination, never a machine.**
- **No credential value is shown, stored, logged or sent over the socket**; credentials are listed by
  name, kind and length, a value reaches a machine by its own command, and nothing promises to wipe
  one from memory.
- **The interface takes no secret into a form of its own.** A password, passphrase, token or sign-in
  code is typed into a terminal on the machine it is for, the provider's own login where it has
  one, and a one-time code is asked only after the password.
- **A saved job holds name, project, agent, mode and prompt only**, read field by field, never
  clearance or the gate.
- **The interface writes no `project.yml`**; a project's settings are changed only in its repository.
- **A flow with several inputs that need explanation uses a wizard with one step per screen.** Show
  the current step, back and next controls, and a summary before the action.
- **Every field uses the person’s words and explains where its value is found.** Distinguish a name
  from a folder and name the provider where it matters.
- **The Porelo organization is named so wherever a forge's organization could also be meant**, and a forge's own
  word is used for GitHub alone ("the GitHub organization"); another forge, or none known yet, reads "your forge's
  organization". The roles keep their names, and Core's words are shown as they come.
- **A terminal session gets the frame's focus node**, so `Escape` reaches the far end, and a modified
  Enter is sent as itself only after the far end asked for modified keys.
