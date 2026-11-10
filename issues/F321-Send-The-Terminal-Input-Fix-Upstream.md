# F321 — Send The Terminal Input Fix Upstream

```json
{
  "$schema": "issue-1.json",
  "id": "F321",
  "title": "Send The Terminal Input Fix Upstream",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 4,
  "blockedBy": [],
  "covers": "The terminal input fix offered upstream, and this repository's copy of `xterm` dropped once a release holds it."
}
```

**Why this size.** one pull request elsewhere, then removing the copy here.

**Blocked by** the third trial move (2026-11-08).

**The operator's word (2026-11-08).** After the third move: the patch is run against upstream's current tree with
upstream's own tests; only when they are green is the pull request handed to the coordinator, and the operator sends
it.

**What must be true.** Porelo uses a released `xterm`, with no copy of it in this repository, and typing fast into a
terminal still sends each key once, with dead keys composing.

## Plan

- Offer the change described in `packages/xterm/PATCHED.md` to https://github.com/TerminalStudio/xterm.dart, with the
  test `test/ui/terminal_fast_typing_test.dart` as its reason. Sending it is outward-facing: the operator decides it.
- When a release holds a fix, delete `packages/xterm`, its entries in `pubspec.yaml` and `analysis_options.yaml`, and
  keep the test here. If the test stays green, the copy is no longer needed.
- If upstream takes another approach, such as the delta model of Flutter's text input, measure dead keys and top-speed
  typing on a real X display again before dropping the copy.
