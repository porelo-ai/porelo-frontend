# F321 — Send The Terminal Input Fix Upstream

**Status:** Idea.
**Size:** S - one pull request elsewhere, then removing the copy here.

**What must be true.** Porelo uses a released `xterm`, with no copy of it in this repository, and typing fast into a
terminal still sends each key once, with dead keys composing.

## Plan

- Offer the change described in `packages/xterm/PATCHED.md` to https://github.com/TerminalStudio/xterm.dart, with the
  test `test/ui/terminal_fast_typing_test.dart` as its reason. Sending it is outward-facing: the operator decides it.
- When a release holds a fix, delete `packages/xterm`, its entries in `pubspec.yaml` and `analysis_options.yaml`, and
  keep the test here. If the test stays green, the copy is no longer needed.
- If upstream takes another approach, such as the delta model of Flutter's text input, measure dead keys and top-speed
  typing on a real X display again before dropping the copy.
