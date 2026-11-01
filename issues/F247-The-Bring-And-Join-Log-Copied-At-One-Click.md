# F247 — The Bring And Join Log Copied At One Click

**Status:** Idea. Held: GUI changes wait until the whole flow has been gone through again.
**Size:** XS - a *Copy* button beside the bring's and the join's last lines, as the terminal panels have.

**What must be true.** The last lines a bring or a join shows in its last step have a *Copy* button that puts all of them on the clipboard, as the terminal panels do. The lines stay selectable.

## Why

In Step 7 of 7 of *Put <project> on a server*, the bring's log (`bring-last-lines`, `lib/src/ui/project_bring_dialog.dart`) has no *Copy* button; selecting the lines by hand is slow and loses some. The join's lines (`lib/src/ui/project_join_dialog.dart`) have none either.

## Plan

- One small widget for "last lines with *Copy*": a `SelectableText` with an icon button (`Icons.copy`, tooltip "Copy the lines"), which shows "Copied" briefly after a click. The bring's `bring-last-lines` and the join's account-run lines use it.
- What is copied is exactly what is shown. The lines hold no secret today, since the playbook's lines pass the host's filter, and nothing new is added to them.
- **Red first:** a widget test that *Copy* in the bring's last step puts the shown lines on the clipboard.

## Test

Only the change: the widget test above and the two dialogs' own tests. No VM run.
