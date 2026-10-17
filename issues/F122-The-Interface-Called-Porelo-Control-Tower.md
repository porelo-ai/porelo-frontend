# F122 — The Interface Called Porelo Control Tower

**Status:** Review.
**Size:** XS - one name in Dart, the two runners' window titles, the desktop entry, the Windows
resources and the MSIX's display names, and a test that holds them to one another.

**What must be true.** Wherever a person reads the interface's name - its window's title, the menu
entry, the about dialog, the Windows file properties and the installed app - it says
*Porelo Control Tower*. The binary, the package and the paths keep the technical name
`porelo-frontend`, which nothing on screen shows.

## Plan

- `lib/src/app/product.dart`: `productName`, read by `MaterialApp.title`, the about dialog and its
  command's label.
- The window's title is set by each platform's runner, not by the app: `linux/runner/my_application.cc`
  (header bar and plain title) and `windows/runner/main.cpp`; `Runner.rc`'s product name and file
  description; `AppxManifest.xml.in`'s two display names; the desktop entry's `Name`.
- **Red first:** `test/packaging_test.dart` holds every one of these to `productName` and refuses the
  binary's name as a window title; red on the template's `porelo_frontend`, green after.

## Acceptance

- The test red before, green after; the whole suite green.
- Seen by eye: the window's title bar says *Porelo Control Tower* on Linux.
