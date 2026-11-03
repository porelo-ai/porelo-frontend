# F325 — Going Back To The Machine's Agent

**Status:** Idea.

**What must be true.** A person who picked an agent in the start form can hand the choice back to the machine, and
the form never reads as if an agent was picked when none was.

The list holds the machine's agents and no entry for its own choice, so once one is picked the only way back is to
close the form. In a walk the field read `Claude Code 2.1.311` rather than *The machine chooses*, after a click that came
late or after Esc; the person could not say which.

## To be checked

- Esc on a plain `DropdownButtonFormField` closes the list and picks nothing, measured in a widget test. Whether a
  late click on the open list explains the walk is not measured, and neither is Esc in the start form itself.
