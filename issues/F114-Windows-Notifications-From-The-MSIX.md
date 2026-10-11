# F114 — Windows Notifications From The MSIX

**Status:** Accepted.

**What must be true.** Installed from the MSIX, the interface raises Windows' own notifications where
it raises a desktop notification on Linux; the ZIP, which has no identity, keeps saying once that
none is raised.

## Why

On Windows `DesktopNotifier.raise` (`lib/src/app/notifications.dart`) only sets `problem` today:
Windows' notifications need the application registered with the shell, and the MSIX gives it that
identity (`packaging/windows/AppxManifest.xml.in`). So a person on Windows misses what a person on
Linux is told when work needs them.

## The shape

- Installed from the MSIX, `DesktopNotifier` raises a Windows notification through the package's
  identity; from the ZIP it says that none is raised, as today.
- Red first: a test of `DesktopNotifier` with `onWindows: true` and an identity given, expecting a
  notification rather than `problem`.

## To be checked

- How a Windows notification is raised from Dart, a package or WinRT through `dart:ffi`, and whether
  the ZIP, with no identity, can raise one at all. (Agent Frontend's)
