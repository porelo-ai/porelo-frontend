# F237 — A Kept CA For Another Network Said Before Renting

**Status:** Idea. Held as an Idea (operator, 2026-10-30, after walk 23): wizard changes wait until he has gone through the whole flow again.
**Size:** S - the kept CA read in the wizard's secrets-file step, with a way on, and the stop's refusal said once in its own words.

**What must be true.** *Prepare a server…* finds a kept CA for the chosen host name (`hosts/<host>/forge-ca-key` and `forge-ca` in the secrets file) that does not cover the chosen network, before *Prepare the server*. It says so and offers a way on: another host name, or replacing the old CA entries after a confirmation that names them. When a stop still meets such a CA, the person sees that one cause, with no second line about a missing `wireguard` and no "a wrong call" (code 64).

## Why

Operator's finding in walk 23, step 2-8 (2026-10-30): *Complete setup on walk9server* ended with "The kept CA does not permit this host network; remove the old entries so a new CA is made. Nothing was sent.", then the host's "porelo-host-stop: no line gives wireguard" and code 64. `~/Porelo/secrets.kdbx` still held walk9server's CA from an earlier walk with another network; this server has network 1. The server was already rented when this came out.

The feed (`packages/porelo_host/lib/src/secrets_file.dart`, the network check after the CA is read) exits 1 and sends nothing. The host's `porelo-host-stop --stdin` then reads an empty pipe and refuses as a usage fault, and that last code is what the dialog reports.

## Plan

- The wizard's *Your secrets file* step already opens the file with the master password, before renting (`host-secrets-terminal`). There it also reads whether `hosts/<host>/forge-ca` is kept and which `10.73.<n>.0/24` it permits. A CA for another network blocks *Next* with: "Your secrets file keeps a CA for <host> that covers 10.73.<m>.0/24, not 10.73.<n>.0/24. Choose another host name, or replace it." *Replace it* asks once, naming both entries, then removes them in that terminal, so the stop makes a new CA.
- The stop's feed refuses before the host's stop is started: a refused feed ends the pipe without running `porelo-host-stop --stdin`, and the dialog shows the feed's own words as the refusal, not the host's code.
- **Red first:** a test that a kept CA for network 0 blocks the wizard for network 1 before renting; a test that a feed refusing on the CA leaves one refusal line and no "no line gives" in the stop dialog.

## Test

Only the change: the two tests above with a stand-in `keepassxc-cli`, and the wizard's and the feed's own tests. No VM run and no rental.

## Reopening the stop today

After *Done*, the host's `up` still waits at its stop. In *Machines* the server's row says *Needs you*, and its button *Complete setup on the host* opens *Complete setup on <host>* again. The same command stands under *Needs you* in the rail, and in the row's menu (⋮) as *Open the host protocol*, whose stop has *Complete setup on the host* too.
