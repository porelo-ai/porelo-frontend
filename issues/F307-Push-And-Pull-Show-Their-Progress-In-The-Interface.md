# F307 — Push And Pull Show Their Progress In The Interface

```json
{
  "$schema": "issue-1.json",
  "id": "F307",
  "title": "Push And Pull Show Their Progress In The Interface",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 15,
  "blockedBy": [],
  "covers": "Push and pull on a card host show each repository's answer in the interface, the terminal only for the master password."
}
```

**What must be true.** *Push the approved main…* and *Take the central state…* on a card host show each repository's
answer in the interface as it comes, and the end in the interface's own words; the terminal is shown only while the
secrets file asks its master password.

## Why

The project menu's push and pull run in a terminal of their own: the person reads the host's lines there, and the
interface knows only whether the command ended well. The transfer route that reads the host's lines one by one
(`ProjectTransfers` with its terminal) exists, but is not used from the project menu, since its source was never
connected there.

## To be checked

- Connect `ProjectTransfers` in the shell with a source that runs the feed in a presented pty with echo off, so a
  master password is still typed only into that terminal; read what its progress and result views need.
