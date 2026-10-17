# F100 — A File Handed To A Running Task

**Status:** Review; to be walked.

**What must be true.** A person hands a file on this computer to a running task from the interface,
sees what the task has been handed and by whom, takes a file back, and reads the record of every
hand-in after the task is gone - on this machine and on one reached over ssh alike.

## Why

`porelo` lets a file be put in front of a running task once, without a repository. The contract,
as `org.fuin.porelo.Tasks1` says it:

    # Hands a file to a running task. It appears in the container as /porelo/files/<name>, owned by root and
    # readable by the agent, which cannot change or remove it, and it appears whole or not at all: nothing reaches
    # the task until the last part has arrived and the content's sha256 is what the caller said.
    #
    # In parts, because a reply is one message: a whole request, the JSON around 'part' included, may be at most
    # 4 MiB (4 194 304 bytes), so a part's base64 stays below about 4 000 000 characters. Any part from 1 byte up
    # is accepted; parts of at most 2 MiB decoded are recommended, and a client on a slow link sends smaller ones.
    #
    # A part whose offset is not what the daemon holds for that name, bytes and sha256 is refused as
    # PartOutOfOrder, which says where to go on: a client resumes there after a lost connection.

`Task` gains `files`, `handInLimit` ("A client refuses a larger file before reading it") and `run`;
`TakeBack` removes a file; `HandIns` returns the record of every run that carried the name, also
after the task is gone. `by` is the account that handed a file in, or `"porelo"` for Porelo's own.

## Acceptance

- A file is handed in from the work it belongs to, sent in parts, each a call of its own, and
  shows in the task's files with its name, size and who handed it in only once the machine's answer
  says it is complete. Seen to fail: a stand-in that never completes the file, with the file shown.
- A file larger than the task's `handInLimit` is refused with the limit in the sentence, before a
  byte of it is read. Seen to fail: a scenario that hands in such a file and finds a call made.
- A transfer cut off midway resumes where the machine's `PartOutOfOrder` says it stopped, never
  from the start. Seen to fail: a stand-in that drops the connection once, with the second attempt
  starting at offset 0.
- A refusal - not running, too large, a refused name, a transfer already in progress, parts that do
  not add up - is shown in its own words, with what to do about it. Seen to fail: one scenario per
  error, each finding a generic failure.
- A file is taken back with a second decision; the record shows it given, replaced and taken back.
  Seen to fail: a scenario whose file is still listed after the machine answered.
- Porelo's own hand-ins (`by` `"porelo"`) read as Porelo's, never as a person's. Seen to fail: a
  stand-in file by `"porelo"` shown with an account's name.
- On a machine without hand-in, the action is listed as not supported there, and an absent `files`
  reads as absent, never as empty. Seen to fail: a scenario against an older answer that shows
  *no files*.
- Measured end to end on the local VM against a daemon handed over from `porelo`: a small and a large
  file in parts, a resumed transfer, the limit refused before the first byte, a file taken back, and
  the record after the task is removed.

## To be checked

- Where the record of a removed task is opened from, since its work tile is gone.
