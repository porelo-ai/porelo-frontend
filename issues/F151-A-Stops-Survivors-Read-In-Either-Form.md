# F151 — A Stop's Survivors Read In Either Form

**Status:** Implementing.
**Size:** XS - one reader and where its result is shown.

**What must be true.** A stop whose helpers survived never reads as clean, whichever form the daemon sends.

Which form the contract means, the IDL's count or the daemon's list, is `porelo`
[B262](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b262)'s to settle; reading both
here does not wait for it.

## Plan

- In `lib/src/client/models.dart`, make `Stopped.surviving` nullable and preserve string-list
  entries in `survivors`. Numbers supply a count; a complete string list supplies its length and
  names; absent or invalid values supply no count.
- In `lib/src/app/outcome_words.dart`, report an unknown count as "not reported" and show known
  names alongside the warning that survivors must be killed on the machine by hand. Both
  `FleetModel.stopWork` and `clearTheWayToRecreate` use these words.
- First add socket tests in `test/client/porelo_client_test.dart` for the wire forms and tests in
  `test/app/fleet_model_test.dart` for the frame's per-task answer. A nonempty list and invalid or
  absent values fail against the old reader because it answers zero; the frame loses the warning.
- Red checks for already valid forms: make the empty-list branch return null, and make the numeric
  branch return zero. For frame coverage alone, omit the survivor names or the unknown-count warning.

## Acceptance

- `["porelo-x-proxy"]` reads as one survivor, preserves its name, and the frame says the helper
  outlived the stop, names it, and says it must be killed by hand.
- `[]` reads as zero; numeric counts remain unchanged and supply no invented names.
- A string, map, null, mixed list or absent field reads as an unknown count. The frame says
  "not reported" for unreported survivors and never presents that answer as clean.
- Only the changed Dart files are formatted, and `dart analyze` reports "No issues found!".

## Built so far

- `Stopped` reads a number as the count and a list of strings as its length and the survivors'
  names; anything else is an unknown count. `stopWords` names the survivors and says "not
  reported" for an unknown count, for both the work's stop and the clearing before a recreate.
- Seen red with the old `_int` reader: the named survivor, the string and the map each read as a
  clean stop, and the frame lost the survivor's name. The whole suite passes (1535).
