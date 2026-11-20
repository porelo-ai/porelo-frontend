---
name: frontend-walk
description: porelo-frontend: the guided walk. Use when changing the guided walk.
---

# frontend-walk

### Guided Walk

- **This repository's operator tests are Guided Walks, which the operator runs from their checkout on
  the laptop with `flutter run`, so the interface can be corrected during the walk and the change seen live.** Each
  walk says the one command that starts it, what must run before it (the VPN, a rented host, a snapshot), and where
  it hands over to another repository's guide; a fix made during a walk is committed and handed over as any other.
- **A walk is walked by the agent end to end before it reaches the operator, on the test VM under `Xvfb`**: the
  interface on a hidden display, driven step by step through the panel, each step's pointer checked on screen and
  each move of the panel checked. "The VM has no display" is no reason to hand a walk over unwalked. On the local
  test VM the operator installs `Xvfb` and `xdotool`, from one `sudo apt install …` line the agent gives for a
  terminal of their own; the agent never installs them machine-wide. On a central test machine (a leased host, a
  GitHub runner) the run itself installs and starts the display, never a hand.
- **A walk names every value the operator types, points at every control, and lists what it needs in its first
  step** (a second machine and how ssh reaches it, a file, a package); a step already done, or done ahead of the
  panel, says that Next in the panel moves on.
- **Before work that takes more than a few seconds during a guided walk, post a short progress
  answer in the guided-walk panel.** Do the work next and report its result there.
- **Click instructions are live steps in the guided walk’s `walk.json`, with `at` keys and `"from":
  0`.** Use command identifiers for menu keys; `*` matches any part of a key.
