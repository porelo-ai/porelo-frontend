# F114 — Windows Notifications From The MSIX

**Status:** Analyzed.
**Size:** M - a second `Notifier` for Windows through WinRT, the package's identity found at run
time, a manifest change for the notification's action, and tests that run on the Windows runner
only.

**What must be true.** Installed from the MSIX, the interface raises Windows' own notifications where
it raises a desktop notification on Linux; the ZIP, which has no identity, keeps saying once that
none is raised.

## Why

On Windows `DesktopNotifier.raise` (`lib/src/app/notifications.dart`) only sets `problem` today:
Windows' notifications need the application registered with the shell, and the MSIX gives it that
identity (`packaging/windows/AppxManifest.xml.in`). So a person on Windows misses what a person on
Linux is told when work needs them.

## Plan

- **`lib/src/app/notifications.dart`:** `DesktopNotifier` stays the Linux one; a `WindowsNotifier`
  beside it implements `Notifier`, and `main.dart` picks by `desk.isWindows`.
  - **Identity:** `GetCurrentPackageFullName` from `kernel32` through `dart:ffi` answers whether it
    runs from the package. Without one, `problem` says as today that this build raises none, now
    adding that the MSIX does.
  - **Raising:** a toast through WinRT's `ToastNotificationManager` for the package's application,
    the urgency mapped as on Linux (`Urgency.waiting` as a reminder that stays, the others as
    ordinary ones), title and body as `notify-send` gets them.
  - **Acting on it opens the work:** the toast's `launch` argument carries `Announcement.id`; the
    interface, started or activated with it, calls `onOpened` as the Linux action does.
- **`packaging/windows/AppxManifest.xml.in`:** the toast activation (`desktop:Extension
  Category="windows.toastNotificationActivation"`) so a click reaches the running interface.
- **Through a package or by hand:** a maintained package that raises WinRT toasts for a packaged
  desktop application, if one fits, else the WinRT calls through `dart:ffi` in one file; whichever,
  `Notifier` stays the seam and Linux is untouched.
- **Red first:** a new `test/app/notifications_test.dart` with `WindowsNotifier` given a stand-in for the
  identity and the toast: with an identity, a toast is raised and `problem` stays null; without one,
  `problem` says so. Tagged to run on the Windows runner where it touches WinRT.

## Acceptance

- **From the MSIX, work that needs a person raises a Windows notification,** and acting on it opens
  that work. Seen to fail: the test with an identity given, expecting a toast rather than `problem`.
- **From the ZIP, it is said once that none is raised,** and that the MSIX raises them. Seen to
  fail: the test without an identity.
- **Linux is unchanged:** `notify-send` as before. Seen to fail: the notification scenarios in
  `test/features/`, run as today.
- **On a Windows machine:** in the test that `doc/design.md` describes, a notification seen and
  clicked; until then, "untested on a Windows machine".

## To be checked

- **How a toast is raised from Dart:** a maintained package for packaged desktop applications, or
  WinRT through `dart:ffi`; and whether the ZIP, with no identity, can raise one at all, which would
  widen this to the ZIP. (Agent Frontend's)
- **Whether toast activation reaches an already running interface** or starts a second one, which the
  one-window loopback port (`frontend.port`) then hands over. (Agent Frontend's)
