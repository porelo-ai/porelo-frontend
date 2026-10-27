# F200 — KeePassXC Shipped On Windows And macOS

**Status:** Idea.

**What must be true.** On Windows and macOS the interface comes with KeePassXC's official signed build, with its
license and the offer of its source, so the person's `secrets.kdbx` ([F198](README.md#f198)) is opened there by the
`keepassxc-cli` the interface ships, as Linux's package depends on the distribution's.

## Why

KeePassXC is required for the person's secrets file (decided), and only Linux has a package manager that installs it
with the interface. KeePassXC is GPL-2.0 or GPL-3.0, so it can be shipped beside the interface's GPL-3.0.
