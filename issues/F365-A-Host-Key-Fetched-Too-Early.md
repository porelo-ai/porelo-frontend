# F365 — A Host Key Fetched Too Early

**Status:** Idea. Nothing is built before the foo test.

**What must be true.** In the dialog for a machine one already has, a person files the key the finished machine holds, knows how to compare it, and gets words that fit when the key is wrong. In the foo test, *Fetch SSH host key* took a key while the provider was still installing the server. Once the server read Ready, the machine itself named another. Only the person's comparison caught it.

## What happens today, by reading

- **The fetch trusts whatever answers.** It is one `ssh-keyscan`, and the address's change or the button runs it, with no sign of whether the system has finished installing. During an install the key is the installer's, and anyone on that path could have answered.
- **A wrong key filed stops `up` at its first ssh line, before anything changes.** `StrictHostKeyChecking=yes` holds against the package's own `known_hosts`. On a given machine it is asked once.
- **That stop is safe but not clear.** The person reads ssh's own "Host key verification failed", with nothing saying that an install changes the key or what to do next.
- **The words on comparing name no source.** "Compare this with what your provider or the forge's own page publishes" is one sentence shared with a forge's key, and it may name nothing the provider offers.
- **The words on root mislead.** "Run this in a separate terminal on the server. It replaces root's authorized keys" does not say how to reach the server. A provider's user may be another, `ubuntu` in the foo test, and root can log in only once the command has run. The command itself uses `sudo`, so it fits such a user.
- **The name is free text.** The field takes any word and refuses afterwards: a form that is no DNS label, or a machine the organization does not list. The dialog can only prepare a listed machine of the person's own, so a provider's name has no use there.

## The shape

- **The way to compare is one command,** run on the server itself: `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`. The dialog shows it with the fingerprint, and says to wait until the provider says the server is ready and its install has finished.
- **The fetch is asked again at *Prepare*.** If the key differs from the one compared, nothing starts, and the words say the key changed, usually since an install was still running, and to compare again. This catches a change, not a false answer, so the comparison stays.
- **A refused key says it in words:** what happened, that nothing was changed on the machine, and how to enter the right one. ssh's own line stays below.
- **The steps stand in their order:** log in with the user the provider gave you, run the command, and from then on Porelo logs in as root.
- **The name is a choice** among the listed machines the person is a Machine Admin of, and it is filled in when reached from a machine's row. With none, the dialog says who adds one.

## Acceptance

- A key that differs at *Prepare* from the one compared starts nothing and says why. Seen to fail first.
- A refused key's run says what happened and what to do, in the window's words.
- The dialog names the command to compare with, and the login step comes before root's command.
- The name cannot be typed into a refusal: only a machine that can be prepared is offered.

## To be checked

- After a refused key: whether the saved preparation can be given another key, since a second try with the same name answers "This machine name already has saved preparation or an active run".
- What the provider really offers to compare with; nothing here claims it. Porelo's rented machines make their key here, so this concerns a machine one already has.
- Which refusal the name met in the foo test.
- The same words where a forge's key is compared, which share the sentence and have a page to name.
