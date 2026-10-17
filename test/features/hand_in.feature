# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Handing a file to running work, taking it back, and its record

    Background:
        Given a backend with work on it
        And this machine takes files handed to work up to {8388608} bytes
        And the app is running
        And I go to the work
        And I select the project {'checkout'}
        And I select the work {'porelo-checkout-shell'}

    Scenario: a file handed in is listed with its size and who handed it in
        Given a file {'notes.txt'} of {300} bytes is picked
        When I choose {'Hand it a file from this computer'} from the menu of the tile {'porelo-checkout-shell'}
        And the file is read and sent
        Then the status line mentions {'notes.txt is in porelo-checkout-shell now'}
        When I open the selection
        Then it says {'notes.txt, 300 bytes, by somebody'}
        And it says {'notes.txt given by somebody'}

    Scenario: a file the machine never places is not shown as handed in
        Given a file {'notes.txt'} of {300} bytes is picked
        And the machine will keep the parts but never place the file
        When I choose {'Hand it a file from this computer'} from the menu of the tile {'porelo-checkout-shell'}
        And the file is read and sent
        Then the status line mentions {'placed nothing'}
        When I open the selection
        Then it does not say {'notes.txt, 300 bytes'}

    Scenario: a file larger than the work takes is refused before anything is sent
        Given a file {'big.bin'} of {9000000} bytes is picked
        When I choose {'Hand it a file from this computer'} from the menu of the tile {'porelo-checkout-shell'}
        And the file is read and sent
        Then the status line mentions {'takes at most 8 MiB. Nothing was sent.'}
        And no part was sent

    Scenario: a transfer cut off goes on where the machine says, not from the start
        Given a file {'cut.bin'} of {2500000} bytes is picked
        And the machine will lose the reply to the next part
        When I choose {'Hand it a file from this computer'} from the menu of the tile {'porelo-checkout-shell'}
        And the file is read and sent
        Then the parts sent started at {'0, 0, 1048576, 2097152'}
        And the file {'cut.bin'} arrived whole

    Scenario Outline: a refusal says what to do about it, in its own words
        Given a file {'notes.txt'} of {300} bytes is picked
        And the machine will refuse the next file with {<refusal>}
        When I choose {'Hand it a file from this computer'} from the menu of the tile {'porelo-checkout-shell'}
        And the file is read and sent
        Then the status line mentions {<words>}

        Examples:
            | refusal            | words                                                     |
            | 'NotRunning'       | 'a file goes only to running work'                        |
            | 'FileNameRefused'  | 'Hand it in under another name'                           |
            | 'HandInInProgress' | 'Wait for it, or hand this one in under another name'     |
            | 'FileDiffers'      | 'nothing was placed. Hand it in again'                    |

    Scenario: a file taken back is gone, and the record keeps both
        Given a file {'brief.txt'} of {40} bytes is picked
        When I choose {'Hand it a file from this computer'} from the menu of the tile {'porelo-checkout-shell'}
        And the file is read and sent
        And I choose {'Take back a file it was handed'} from the menu of the tile {'porelo-checkout-shell'}
        And I choose {'brief.txt, 40 bytes, by somebody'}
        Then the status line mentions {'brief.txt is out of porelo-checkout-shell again'}
        When I open the selection
        Then it says {'nothing, under /porelo/files'}
        And it says {'brief.txt taken back by somebody'}

    Scenario: what Porelo hands in itself reads as Porelo's, never as a person's
        Given the work {'porelo-checkout-shell'} was handed {'verdict.json'} by Porelo
        When I open the selection
        Then it says {'verdict.json, 120 bytes, by Porelo'}

    Scenario: a machine without hand-in offers it as unavailable, with why
        Given this machine cannot hand files to work
        When I open the actions for {'porelo-checkout-shell'}
        Then the action {'Hand it a file from this computer'} is offered as unavailable

    Scenario: a machine without hand-in shows no files, rather than none
        Given this machine cannot hand files to work
        When I open the selection
        Then it does not say {'Handed in'}
