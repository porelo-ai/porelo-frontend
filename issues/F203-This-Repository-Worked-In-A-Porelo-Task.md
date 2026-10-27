# F203 — This Repository Worked In A Porelo Task

**Status:** Idea.

**What must be true.** porelo-frontend's agent works in an attended Porelo task of the project `porelo` on the host,
named after the repository or its nickname, with this repository only: its image holds the Flutter toolchain the
build needs (the pinned Flutter, `clang`, `cmake`, `ninja`, `pkg-config`, `libgtk-3-dev`, `libsecret-1-dev`, `xvfb`,
`dbus`) and the pinned JDK for the document checks; its pushes go through the gate to the host's Forgejo, whose build
of them is green; it is reached in the project's room; and a way back to this machine stays open, as
`porelo-project` [PJ59](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj59) describes. This
issue is worked to Review from inside that task, to show the move done.

## To be checked

- What the integration leg needs inside a task: a display under `xvfb-run`, and a VM to test against, which the
  task reaches only as the move's procedure and the VM pool allow.
- Whether `flutter-guided-walk`, also kept by this repository's agent, moves with it or on its own.
