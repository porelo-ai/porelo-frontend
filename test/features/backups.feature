# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Backups of a mirror: listing, removing, restoring, and upstream

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}

    # A bundle is written wherever an operator names it and the command forgets it, so "what has
    # been taken" was never a missing listing — it was a question with no data behind it. What is
    # listed is a record written when each one was taken.
    Scenario: what has been taken is listed with enough to tell two apart
        When I show what has been backed up here
        Then it says {'/srv/checkout/backups/before-sync.bundle'}
        And it says {'2 pushes when it was taken'}
        And it says {'4.0 MB now'}

    # A record is not the bundle. The file can be moved afterwards and nothing here would know, so
    # what was true then and what is true now are told apart rather than merged.
    Scenario: a bundle somebody moved is shown as missing, never dropped
        When I show what has been backed up here
        Then it says {'/srv/checkout/backups/moved-away.bundle'}
        And it says {'the file is not there any more'}

    # An empty list means nothing recorded, never nothing exists.
    Scenario: a project with no record says so, without claiming no bundle exists
        Given nothing has been backed up here
        When I show what has been backed up here
        Then it says {'Nothing is recorded for this project'}
        And it says {'not the same as no bundle existing'}

    Scenario: removing one says what it held before anything goes
        When I show what has been backed up here
        And I consider removing the first backup
        Then it says {'It held 2 pushes nobody had reviewed'}
        And no backup was removed

    Scenario: keeping it removes nothing
        When I show what has been backed up here
        And I consider removing the first backup
        And I keep the backup
        Then no backup was removed

    Scenario: agreeing removes it, and says what it held
        When I show what has been backed up here
        And I consider removing the first backup
        And I remove the backup
        Then it says {'Gone: the bundle and the record of it'}

    # A tidy-up rather than a loss, and saying both the same way would tell somebody they had
    # destroyed something they had not.
    Scenario: clearing the record of a bundle already gone is not called a loss
        Given the bundle is already gone
        When I show what has been backed up here
        And I consider removing the first backup
        And I remove the backup
        Then it says {'The record is cleared. The file was already gone'}

    # `SyncUpstream` is its own method and not a flag on a read: a listing that reached the network
    # would make the queue cost what a listing must not. It writes the same record the timer writes,
    # so a triggered fetch and a timed one cannot disagree.
    Scenario: asking the upstream is one action and says what it found
        When I ask the upstream how far behind this project is
        Then the upstream was asked about {'checkout'}
        And the status line mentions {'3 commits behind the upstream, as of now'}

    # `behind` means nothing unless it was measured, and zero is the answer both for up to date and
    # for nothing having been measurable.
    Scenario: a project with no upstream is not reported as up to date
        Given the upstream cannot be measured because {'NO_UPSTREAM'}
        When I ask the upstream how far behind this project is
        Then the status line mentions {'no upstream, so there is nothing to be behind'}

    Scenario: restoring says what it would overwrite before it does anything
        When I show what has been backed up here
        And I consider restoring the first backup
        Then it says {'This writes over the mirror'}
        And nothing was restored

    # Unreviewed pushes exist only in the mirror — not upstream, not in a workspace, not in the
    # bundle — so overwriting one destroys the only copy there has ever been.
    Scenario: work nobody has reviewed refuses the restore, and says what would go
        Given restoring would destroy {'migrate'}
        When I show what has been backed up here
        And I consider restoring the first backup
        And I restore from it
        Then it says {'Refused: 1 push nobody has reviewed would be destroyed'}
        And it says {'Nothing was written'}

    # Somebody who forced needs it in the record afterwards, not only in the warning they clicked
    # past.
    Scenario: forcing past the refusal says afterwards what it destroyed
        Given restoring would destroy {'migrate'}
        When I show what has been backed up here
        And I consider restoring the first backup
        And I restore from it
        And I restore from it
        Then it says {'1 unreviewed push is gone: migrate'}

    # A bundle somebody moved is listed, because it was taken — but there is nothing to restore
    # from, and offering it would say the record is the thing when it is not.
    Scenario: a bundle that is not there any more cannot be restored from
        When I show what has been backed up here
        Then restoring from the missing backup is not offered

    # Every repository has its own upstream, gate and backups. One number for all of them
    # was the project's own, shown against every other.
    Scenario: every repository says how far it has got, on a line of its own
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        And the repository {'payments-api'} is {'4'} behind with {'2'} waiting
        Then the repository {'payments-api'} says {'2 waiting at the gate · 4 behind'}
        And the project's own repository {'checkout'} is not listed

    Scenario: a repository's upstream is asked about on its own
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        When I sync the repository {'payments-api'}
        Then the upstream was asked about the repository {'payments-api'}

    # A bundle is kept under the repository it was taken of. Restored into another, it would put one
    # history over the other's and destroy pushes that exist nowhere else.
    Scenario: a repository's backups are its own, and are restored into it
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        When I show the backups of the repository {'payments-api'}
        Then it says {'Backups of checkout · payments-api'}
        When I consider restoring the first backup
        And I restore from it
        Then the backups and the restore were about the repository {'payments-api'}

    Scenario: a machine that names no repositories is asked about none
        When I show what has been backed up here
        And I consider restoring the first backup
        And I ask the upstream how far behind this project is
        Then no repository was named for the backups or the upstream

    # A repository's limits replace the project's key by key. Which keys it replaced is the part worth
    # saying; the rest may be the project's or Porelo's own default, and nothing can tell which.
    Scenario: a repository's limits are shown, the keys it replaced marked as its own
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        And the repository {'payments-api'} limits its memory to {'4g'}
        Then the menu of the repository {'payments-api'} says {'memory 4g (its own)'}
        And the menu of the repository {'payments-api'} says {'processes 512'}
        And the menu of the repository {'payments-api'} does not say {'processes 512 (its own)'}

