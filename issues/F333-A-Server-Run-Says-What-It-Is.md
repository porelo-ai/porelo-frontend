# F333 — A Server Run Says What It Is

**Status:** Accepted.

**What must be true.** From the click on *Prepare the host* the dialog names what is running and that it can take minutes,
the row beside it never ends in nothing, and the person can leave the dialog while the run goes on.

**The operator:** accepted, with *Close* usable.

In a walk the run's dialog opened with only the host's name as its title, an empty body and *Close* greyed, and one could not tell what
it was. Behind it the row said `In preparation ·`, with nothing after the dot.

## Why it looks so

Read from the code, not run.

- The dialog's body is the session's `protocolText` and nothing else, and the title is the host's name. Until `porelo-host`
  reports its first step there is nothing to show.
- The row writes its state, a dot, and `stepText`, which is empty for that same time.
- *Close* is greyed by `_busy`, which stays set while `_prepare` awaits the end of the run, so for all of it. An earlier run
  took 4:39. It protects nothing: the run belongs to `HostRuns` and goes on without the dialog, its row opens the same
  protocol again, and the dialog was opened without `barrierDismissible: false`, so a click beside it should already close it.

## The shape

- Above the protocol, at once: what runs (`Preparing the server <name>`), that it can take minutes, and that it goes on if the
  dialog is closed.
- The row drops the dot while there is no step, or says a first step of its own.
- *Close* stays usable once the run has started.

Together with [F331](README.md#f331), which weighs dialogs that wait against closing them, this is a run that would not
need its dialog held open at all.

## To be checked

- How long the empty body lasts at real GitHub.
- That a click beside the dialog closes it during a run, and that the run then goes on with its row: seen in a test before
  *Close* changes.
- The same by the operator, when next setting up a real server rented by hand at the provider and given by `--given`, as `up` rents nothing until
  renting returns with [F166](README.md#f166): closing the dialog by clicking beside it
  mid-run, does the run go on, does its row show the protocol, and does the token's terminal still open at the end, or does
  the page offer *Give it the token…*?
- In the same setup, for [F319](README.md#f319): give the server back with one member still on it, see the holder named, confirm the
  removal, see that account gone, and release the server at the provider as the person's own step. A test of Porelo's own release waits for 0.9.
