# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Granting an authorization once, in a browser, for later tasks

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    Scenario: an entry that names a service offers to grant it, and one that does not, does not
        Given the store holds {'jira'} of kind {'oauth-device'} beside {'a-provider'}
        When I show the vault
        Then granting {'jira'} is offered
        And granting {'a-provider'} is not offered

    # One string from the machine, shown and opened as it came, and kept on screen after opening.
    Scenario: a device code's page is shown whole with its code, and opened as it came
        Given the store holds {'jira'} of kind {'oauth-device'} beside {'a-provider'}
        When I grant {'jira'} from the store
        Then the machine was asked to grant {'jira'}
        When the machine asks for a decision on {'https://auth.example.com/device?user_code=WDJB-MJHT&x=1'} with the code {'WDJB-MJHT'}
        Then it says {'https://auth.example.com/device?user_code=WDJB-MJHT&x=1'}
        And it says {'WDJB-MJHT'}
        And it says {'It is made there, not here'}
        When I open the page in the browser here
        Then the browser was given {'https://auth.example.com/device?user_code=WDJB-MJHT&x=1'}
        And it says {'https://auth.example.com/device?user_code=WDJB-MJHT&x=1'}

    Scenario: a grant settled in the browser is said, and the store is asked again
        Given the store holds {'jira'} of kind {'oauth-device'} beside {'a-provider'}
        When I grant {'jira'} from the store
        And the machine asks for a decision on {'https://auth.example.com/device'} with the code {'WDJB-MJHT'}
        And the machine says the grant is {'granted'}
        Then it says {'Granted. It is kept in the vault'}
        And opening the page is not offered
        When I am done granting
        Then the machine is asked again whether the store is open

    Scenario Outline: how a grant ends is said in words
        Given the store holds {'jira'} of kind {'oauth-device'} beside {'a-provider'}
        When I grant {'jira'} from the store
        And the machine asks for a decision on {'https://auth.example.com/device'} with the code {'WDJB-MJHT'}
        And the machine says the grant is {<state>}
        Then it says {<words>}
        Examples:
            | state     | words                                                 |
            | 'refused' | 'Refused in the browser. Nothing was granted.'        |
            | 'expired' | 'The question expired before anybody decided.'        |
            | 'failed'  | 'It failed: the service answered invalid_client'      |

    # The machine's own words, where it adds them: a grant that never expires, and one the
    # machine would not keep, which no person in a browser refused.
    Scenario: a grant the machine adds words to says them, and one the machine refused is not said as the person's
        Given the store holds {'jira'} of kind {'oauth-device'} beside {'a-provider'}
        When I grant {'jira'} from the store
        And the machine asks for a decision on {'https://auth.example.com/device'} with the code {'WDJB-MJHT'}
        And the machine says the grant is {'granted'}, adding {'the service gave a token that does not expire, which removing it here cannot revoke'}
        Then it says {'and the next task uses it. the service gave a token that does not expire'}

    Scenario: a grant the machine would not keep is said as the machine's refusal
        Given the store holds {'jira'} of kind {'oauth-device'} beside {'a-provider'}
        When I grant {'jira'} from the store
        And the machine asks for a decision on {'https://auth.example.com/device'} with the code {'WDJB-MJHT'}
        And the machine says the grant is {'refused'}, adding {'the service granted no refresh token'}
        Then it says {'did not keep what the service granted: the service granted no refresh token'}
        And it does not say {'Refused in the browser'}

    # The answer comes back to a port on the machine; the browser here reaches it only through a forward.
    Scenario: a redirect's page is offered only once its answer can reach the machine, and the forward goes after
        Given the machine is reached over ssh as {'alice@vm'}
        And the store holds {'forge'} of kind {'oauth-code'} beside {'a-provider'}
        When I grant {'forge'} from the store
        And the machine asks for a decision on {'https://forge.example/authorize?state=s1'} answered on port {'8765'}
        Then a forward of port {'8765'} is held
        And opening the page is offered
        When the machine says the grant is {'granted'}
        Then the forward of port {'8765'} is taken down

    # Only a web address is ever opened; anything else is shown, to be copied, and nothing more.
    Scenario Outline: a link that is not a web address is shown and never offered to open
        Given the store holds {'jira'} of kind {'oauth-device'} beside {'a-provider'}
        When I grant {'jira'} from the store
        And the machine asks for a decision on {<link>} with the code {'WDJB-MJHT'}
        Then it says {<link>}
        And opening the page is not offered
        And nothing was opened in the browser
        Examples:
            | link                            |
            | 'file:///etc/passwd'            |
            | 'ftp://auth.example.com/device' |
            | 'https:///device'               |

    # Sent to a port nothing answers on, the browser would show an error and the grant would never land.
    Scenario: a redirect whose answer cannot be forwarded is not offered to open, and says why
        Given the machine is reached over ssh as {'alice@vm'}
        And forwarding a port fails with {'Port 8765 is already in use on this computer'}
        And the store holds {'forge'} of kind {'oauth-code'} beside {'a-provider'}
        When I grant {'forge'} from the store
        And the machine asks for a decision on {'https://forge.example/authorize?state=s1'} answered on port {'8765'}
        Then opening the page waits for its answer's way back
        And it says {'Port 8765 is already in use on this computer'}

    # Measured on Porelo 213: a wrong kind and a service out of reach both come back this way.
    Scenario: a grant that cannot be asked for says why in the machine's words
        Given the store holds {'jira'} of kind {'oauth-device'} beside {'a-provider'}
        When I grant {'jira'} from the store
        And the machine refuses the grant saying {'the service at auth.example.com could not be reached'}
        Then it says {'It could not be asked for: the service at auth.example.com could not be reached'}

    # Who a task using it acts as, from the machine's record: never the grant itself.
    Scenario: an entry says who granted it and when, or that nobody has yet
        Given the store holds {'jira'} of kind {'oauth-device'} granted by {'alice'} at {'2026-09-30T05:40:00Z'}
        And the store also holds {'forge'} of kind {'oauth-code'}, not granted
        When I show the vault
        Then it says {'oauth-device · granted by alice, 2026-09-30T05:40:00Z'}
        And it says {'oauth-code · not granted yet'}
        And granting {'jira'} is offered again

    # Raised by the machine, for whoever can answer it: not only the person who was starting the work.
    Scenario: an authorization work waits for is in what needs a person, and told
        Given the machine says {'jira'} needs a grant for {'porelo-checkout-shell'} in {'checkout'}
        When I go to what needs a person
        Then it says {'jira needs a grant for porelo-checkout-shell'}
        And it says {'Nobody has granted it yet'}
        And the count of what needs a person is {'1 need you'}
        And somebody was told {'jira needs a grant for porelo-checkout-shell'}

    Scenario: a grant the service ended says it needs granting again
        Given the machine says {'jira'} needs granting again for {'porelo-checkout-shell'} in {'checkout'}
        When I go to what needs a person
        Then it says {'the service has ended the grant'}

    Scenario: an authorization granted anywhere leaves what needs a person
        Given the machine says {'jira'} needs a grant for {'porelo-checkout-shell'} in {'checkout'}
        When I go to what needs a person
        And the machine says {'jira'} is granted
        Then the authorization {'jira'} is resolved with its action disabled
        And nothing needs me

    Scenario: an authorization is granted from what needs a person
        Given the machine says {'jira'} needs a grant for {'porelo-checkout-shell'} in {'checkout'}
        When I go to what needs a person
        And I grant {'jira'} from what needs a person
        Then the machine was asked to grant {'jira'}
