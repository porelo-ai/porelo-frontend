# F135 — The Interface Brings A Host Up And Down

**Status:** Review; published in `0.5.1~snapshot.176`, for the operator's test on a rented host.
**Size:** M - one page that runs the command, reads its lines and answers its one stop.

**What must be true.** In a project, a person chooses *Put on a server* and sees the steps of
`porelo-host up` as they come. When it stops for them, the interface asks for the Tresorit login
and the vault's passphrase, and goes on. *Take off the server* runs `down` the same way. No step
needs a terminal, and no secret is written anywhere.

## Plan

- A page beside the project's, which starts the shipped `porelo-host` by its path with
  `Process.start`. It reads stdout line by line into a list of steps in the shape of
  `lib/src/ui/prepare_view.dart`'s, and shows stderr's words under a refused step with its `fix`.
- **Exit 75:** a form for the Tresorit e-mail and password and the vault's passphrase. Then a
  second `up` is started and the three are written to its stdin, held in memory only and cleared
  after.
- **The provider's key:** asked once on the page and kept by [F133](README.md#f133)'s store.
- **The red test first:** a widget test with a fake process that emits the lines, the stop and
  then done. It holds that the secrets reach stdin and never the arguments, and it is run red with
  the passphrase put in an argument.

## Built so far

- `HostSession` (`lib/src/app/host_session.dart`) starts the shipped `porelo-host` by its path,
  reads its step lines into a list, takes 75 as the stop with what it needs, and writes the
  answers as one JSON object to its standard input, never to its arguments.
- `HostDialog`, opened by a project's *Put this project on a server…*, unavailable for `default`
  and where no `porelo-host` came with the interface: the Scaleway project, the account, the
  person's ssh keys and the collection's tarball; the steps; at the stop the drive's login and the
  vault's passphrase, twice for a new vault; the fields cleared once sent. The provider's key is
  not asked here: it is the system store's ([F133](README.md#f133)).
- Tests against a stand-in `porelo-host` that keeps its arguments and its standard input, with
  controlled output and exit for the machine-list decisions. The drive and vault guards cover
  secrets on standard input only and matching new-vault passphrases; the corresponding reds put
  a passphrase into the arguments or let differing passphrases through.
- **The project's tresor**, a required field passed as `--tresor` to `up` and its resume: the real
  plays stop for the drive's login only when `up` names one. Seen red with the field left out of the
  arguments and with it no longer required.
- **The host fields are read-only once `up` has started**, and the resume and `down` take exactly
  `up`'s arguments, so `down` cannot look for another host while the rented one bills on. Seen red
  with the fields left editable.
- **The dialog adds and removes the host:** after `up` ends done, *Add this server to your
  machines* adds `<project> server` as a machine of kind `host`, with the command's address,
  account and daemon socket and the identity given to `up`. An existing host of that name is
  replaced. A done `down` names the address it actually gave back; only host machines with that
  address and the command's account are removed, regardless of their label. No address means no
  host was found: the dialog says so and keeps the list. A waiting or refused command keeps it
  too. Removing the sole host leaves the local machine so the frame still has a machine.
- **A stop the dialog cannot answer says so:** an unknown need, including `agent-login:<agent>`,
  is shown verbatim, without sign-in or *Go on*. No second `up` is run for such a stop; agents
  are signed in when a task needs them, on the machine. The drive and vault resume stays.
- **Guards written for the changed design:** controlled process output proves that a done step
  before exit 0 cannot add or remove a machine, and a failed command cannot either. Replacement,
  the completed destination, invalid destination refusal and unknown stops are covered. Seen red:
  the machine offered after a failed `up`, removed after a failed `down`, and removed after a
  `down` that found no host.
- **Measured on a throwaway Ubuntu 26.04 VM** on this machine's libvirt, with porelo-host's
  collection at `b7ca257` (the roles of `d765a0f`): `packages/porelo_host/tool/vm-run.sh` refused
  another host key with 69, stopped with 75 for the drive and a new vault with `--tresor`, made the
  vault from the answer on standard input, and `down` ended 0, in 256 s, nothing of the run left.
  That is the command the page runs; the page itself offers Scaleway only.
- Left: the page against a rented host, the operator's run; and the Windows job.

## Acceptance

- The page runs `up`, the stop and `down` against the test VM through `GivenMachine`, measured.
  On Windows, the same page with a fake process in the Build's Windows job.
- Seen to fail: a wrong passphrase is shown as the vault's words, and the form asks again.

## To be checked

- How a second factor on the Tresorit account is asked, once porelo-host's [HO06](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho06) has measured it.
