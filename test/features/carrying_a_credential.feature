# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Carrying a credential from this computer to a host

    Background:
        Given a backend with work on it
        And the app is running
        And a host {'elsewhere'} that carries credentials
        And I switch to the machine {'elsewhere'}
        And I show what this machine can authenticate against

    # Harm: a carry says it went while the host holds nothing, or the host's page still reads the provider as not
    # authenticated after it, so somebody carries again or starts work that fails for want of it.
    Scenario: an entry of the vault here is carried, and the host reads its provider as authenticated
        Given the vault here holds {'an-agent'} of kind {'oauth'}
        Then it says {'other-provider · not authenticated'}
        When I open the provider {'Another Provider'}
        And I import {'other-provider'} from this computer
        And I pick {'vault an-agent'} to carry
        And I press {'Carry to elsewhere'}
        Then the carry says {'Carried: the host holds it as an-agent'}
        And the host holds {'an-agent'} of kind {'oauth'}
        When I press {'Close'}
        Then it says {'other-provider · authenticated'}

    # Harm: a sign-in porelo lists an agent here holding is not offered, is sealed by a vault name rather than by agent
    # and provider, or carrying it leaves the host's provider unauthenticated.
    Scenario: the sign-in an agent here holds is carried, and the host reads its provider as authenticated
        Given the agent {'an-agent'} here is signed in to {'other-provider'} as {'oauth'}
        Then it says {'other-provider · not authenticated'}
        When I open the provider {'Another Provider'}
        And I import {'other-provider'} from this computer
        And I pick {'agent an-agent'} to carry
        And I press {'Carry to elsewhere'}
        Then the carry says {'Carried: the host holds it as an-agent'}
        And this computer sealed what {'an-agent'} holds for {'other-provider'}
        And the host holds {'an-agent'} of kind {'oauth'}
        When I press {'Close'}
        Then it says {'other-provider · authenticated'}

    # Harm: a carry overwrites what the host already holds without being asked, or the replace asked for reuses the
    # spent one-use key and never lands.
    Scenario: what the host already holds is kept until replacing it is asked for
        Given the host already holds {'an-agent'} of kind {'api-key'}
        And the vault here holds {'an-agent'} of kind {'oauth'}
        When I open the provider {'Another Provider'}
        And I import {'other-provider'} from this computer
        And I pick {'vault an-agent'} to carry
        And I press {'Carry to elsewhere'}
        Then the carry says {'The host already holds an-agent and kept it'}
        And the host holds {'an-agent'} of kind {'api-key'}
        When I press {'Replace it on the host'}
        Then the carry says {'Carried: the host holds it as an-agent'}
        And the host holds {'an-agent'} of kind {'oauth'}
