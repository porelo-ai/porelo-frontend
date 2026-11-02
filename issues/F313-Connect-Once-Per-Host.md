# F313 — Connect Once Per Host

**Status:** Implementing.
**Size:** M - the list under *Machines* and one connection per host from the organization's card, on today's card connection; about a day, the calls behind it come separately.

**What must be true.** *Machines* lists the hosts carrying a project the person is a member of and the hosts they administer, even when they have no project, and *Connect* sets up that connection once per host. Every project of theirs on a connected host is ready at once with no step of their own, and a project put on that host later appears the same way.

## The contract in words

A person has one account, one daemon and one vault on a host and one connection to it. The host's address, port and host key come from the organization; the address may be a host name, an IPv4 or an IPv6 address.

Other programs read what *Connect* writes, so it stays as it is: `frontend.json`'s `machines` with each machine's `host`, and `porelo/ssh/<host>.conf` and `<host>.known_hosts` beside it, `<host>` being one lower-case DNS label whatever the address.

## Plan

- `lib/src/ui/machines_page.dart`: hosts from the source of the organization's page and fixtures, each with its connection's state and *Connect*.
- The connection is written with `HostCardSsh` as today; its credential rule stays: nothing kept or shown.
- Red first: a widget test with a person on two projects of one host, one row and one connection.

## Acceptance

- Tests: two projects on one host, one connection; a second *Connect* changes nothing; a host admin with no project is listed too; a host carrying none of the person's projects and not administered by them is not offered; the files are written where and as above; a refusal says what to do.
- Seen to fail by writing one connection per project.

## To be checked

- The design canvas's *Machines* page.
- What a machine this computer watches outside an organization shows beside them.
