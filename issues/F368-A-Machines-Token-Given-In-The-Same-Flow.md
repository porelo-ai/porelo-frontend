# F368 — A Machine's Token Given In The Same Flow

**Status:** Review.
**Size:** M - the step in the same flow, the kept token on standard input with a test proving where it goes, and words for a refusal.

**What must be true.** A person who puts a project on a machine is led through giving that machine a token, with one line saying what it is for, and never has to find a button on another page. In the foo test the operator did not see why *Give it my GitHub token…* is a separate step that setup did not do.

## What it is for

A machine has no account at the forge. It uses the person's token once, to add read-only deploy keys to the organization's repository and the waiting projects' repositories, and to copy those projects to its own forge. It reads with those keys from then on and does not keep the token. The token must be allowed to administer those repositories.

## The shape

**Decided:** the window takes the token from the system's secret store, after the person's confirming word, and writes it to the ssh process's standard input, on no command line, in no log and in no file, proven by a test. The dialog says plainly what the token is for and that it needs *Administration: write*, and a refusal for want of that right reads as words. The promise "nothing here sees or keeps it" changes to what is then true. The secrets file stays for whoever has chosen one.

*Put it on a machine…* ends in this step in the same dialog's flow:

1. The project goes on the machine.
2. The connection stands, as far as it can without an account.
3. One line says what the token is for, and the person gives it with their confirming word.
4. The dialog follows the machine until the project is carried, or says why not.

The button on the machine's page stays for a later project or a failed try.

## Does anything force the terminal

**The machine does not.** `org refresh` takes the token on standard input, and that is all it asks. The terminal comes from this window's way of getting the token: it opens `organizationRefreshFeedCommand` so that the master password of the person's secrets file is typed there, and nothing in the window sees the token.

**So there is a third place a token is kept, and this step reads none of the others.** Today it comes from the variable `PORELO_CENTRAL_TOKEN` or from a chosen secrets file. With neither it says "Choose your secrets file first", even for a person whose token is already in the vault and in the system's secret store.

**On an install with neither, the button can never work.** Nothing in `lib` offers the choice of a file: `rememberSecretsFile` is called only by tests. So `_giveHostToken` ends in `_fleet.say`, a line in the status bar that the next read overwrites, and the page stays as it was. In the foo test the operator pressed it and saw nothing change, and went on by ssh, with `org refresh` and the token on standard input.

**What the window could offer:**

| Source | Can it feed the machine? |
|---|---|
| The system's secret store, under `ForgeConnection` | Yes, by what is read here. The window reads it already for its own forge calls, and could write it to the ssh process's standard input with no terminal |
| The vault's `git.token.<host>` | Not by what is read here. The window only writes it, by `porelo vault put`, and the documented commands name no read of it. This is Core's to say, and a rule against reading it out would stand |
| The secrets file | Only with its master password, which is why the terminal exists. It stays for who uses that file |

Using the kept token means the window handles it in memory for this step.

**Its failure is words on the page,** beside the button, whatever the source: never a passing line in the status bar. Where no source exists, the step offers the file's choice in a dialog or says what is missing.

## Plan

1. `organizationRefreshArguments` is the ssh of the terminal's way with its pin, with public values only.
2. `ForgeConnection.feedKeptToken` writes the kept token to the command's standard input and takes it out of what comes back. No value reaches a widget.
3. `_giveHostToken` asks the person's word and uses the kept token where there is one, the terminal where a secrets file or the variable is the only source, and answers words for the page otherwise.
4. `PlacingProjectDialog` follows *Put it on a machine…* through connection and token until the machine carries the project or says why not.

## Acceptance

- *Put it on a machine…* reaches the token step in one flow, naming what it is for. Seen to fail first.
- With no token to be had, the button's press leaves words on the page saying so and what to do. Seen to fail first.
- A person whose token is kept by the window gives it with one confirming word and no terminal.
- The token appears on no command line, in no log and in no answer, proven by a test that looks for it.
- A token without the needed rights says so, naming the right.

## To be checked

- A real run: the kept token over ssh to a host's `org refresh`, and the words a forge's real refusal gives, which here are read for `403` and *Administration*.
- The same reading of `centralToken` in the window's other steps, which then fail the same way or are hidden.
- How the two earlier steps go for a machine this computer has no connection to yet.
- Whether the window's kept token has the needed right, since *Administration: write* is more than a person may have given it.
- How this meets the issue on two token stores, as this makes a third.
