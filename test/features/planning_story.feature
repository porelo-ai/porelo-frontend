Feature: Open stories and issues from planning

    Background:
        Given a backend with planning details
        And the app is running
        When I open the planning board

    # Harm: a card opens stale summaries instead of the machine supplied story and source text, or shows a Markdown
    # description as its raw signs.
    Scenario: A card opens its story
        When I open planning story {'ST291'}
        Then planning details contain {'Story source'}
        And planning details do not contain {'# Story source'}
        And planning details contain {'0 of 16 in Review or Finished'}
        And the planning issue table is shown
        And the planning breadcrumb is {'Planning,ST291'}
        And Planning is selected in the rail

    # Harm: an issue loses its criteria or hides blocking findings behind notes.
    Scenario: An issue shows its last reading and sub-agents
        When I open planning story {'ST291'}
        And I open planning issue {'B541'}
        Then the planning breadcrumb is {'Planning,ST291,B541'}
        And Planning is selected in the rail
        And planning details contain {'Only confirmed work is published'}
        And planning details contain {'Read the final changes'}
        And the last planning findings put blocking first

    # Harm: an unfolded card sends an issue request for the wrong story or project.
    Scenario: An unfolded card opens an issue directly
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then the planning breadcrumb is {'Planning,ST291,B541'}
        And planning details contain {'The host tool reads the organization'}

    # Harm: navigating back resets the board filters folds or scroll position.
    Scenario: Breadcrumbs retain the board position
        When I search planning for {'ST'}
        And I filter planning to high and above
        And I fold the planning phase {'Analysis'}
        And I scroll the planning board
        And I remember the planning board position
        And I open planning story {'ST291'}
        And I open planning issue {'B541'}
        And I press planning breadcrumb {1}
        Then the planning breadcrumb is {'Planning,ST291'}
        When I press planning breadcrumb {0}
        Then the planning board position is retained

    # Harm: the back key leaves details stuck or skips the parent story.
    Scenario: Escape follows the planning breadcrumb
        When I open planning story {'ST291'}
        And I open planning issue {'B541'}
        And I press planning back
        Then the planning breadcrumb is {'Planning,ST291'}
        When I press planning back
        Then the planning board is visible

    # Harm: a browser opens a derived address instead of the machine supplied link.
    Scenario: Browser links use the exact addresses
        When I open planning story {'ST291'}
        And I open the planning web link {'Open story'}
        Then the planning browser opened {'https://example.org/stories/ST291'}
        When I open planning issue {'B541'}
        And I open the planning web link {'Open issue'}
        Then the planning browser opened {'https://example.org/issues/B541'}

    # Harm: a missing link is fabricated and offered as an executable action.
    Scenario: An absent issue link is not offered
        Given the machine gives the planning issue link {''}
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then the planning web link {'Open issue'} is absent

    # Harm: a nonweb or malformed link reaches the desktop opener.
    Scenario Outline: Only valid HTTPS links are offered
        Given the machine gives the planning issue link {'<link>'}
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then the planning web link {'Open issue'} is absent
        Examples:
            | link                       |
            | http://example.org/issue   |
            | https:issue                |
            | file:///tmp/issue          |

    # Harm: an external change leaves a stale story or issue presented as current.
    Scenario: The watch refreshes the opened issue and its story
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        And the machine updates the planning details
        Then planning details contain {'Updated issue title'}
        When I press planning breadcrumb {1}
        Then planning details contain {'Updated story title'}
        And planning details contain {'1 of 16 in Review or Finished'}

    # Harm: a detail refusal becomes a successful empty screen and loses its explanation.
    Scenario: A detail refusal keeps the daemon words
        Given planning detail reads are refused
        When I open planning story {'ST291'}
        Then the planning detail error is {'Story: The story store is locked for repair'}
        And the planning message {'Story: The story store is locked for repair'} appears once

    # Harm: a failed issue read is swallowed while a parent story still succeeds.
    Scenario: An issue refusal keeps the daemon words
        Given planning detail reads are refused
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then the planning detail error is {'Issue: The story store is locked for repair'}
        And the planning message {'Issue: The story store is locked for repair'} appears once

    # Harm: an omitted issue list looks like confirmation that there is no work.
    Scenario: An unreported issue list stays unknown
        Given the planning story issue list is unreported
        When I open planning story {'ST291'}
        Then planning details contain {'Issues not reported'}
        And planning details do not contain {'No issues yet.'}

    # Harm: a confirmed empty list is confused with an unread list.
    Scenario: An empty story shows its empty list
        When I open planning story {'ST294'}
        Then planning details contain {'No issues yet.'}
        And planning details do not contain {'0 of 0 in Review or Finished'}

    # Harm: a lost watch leaves the last detail answer looking live.
    Scenario: A watch failure marks the detail stale
        When I open planning story {'ST291'}
        And the planning watch fails
        Then planning details contain {'The last answer may be out of date'}
        And planning details contain {'store cannot be read'}

    # Harm: a delayed answer notifies a disposed detail or reopens a page after leaving.
    Scenario: A late story reply cannot reopen details
        Given the planning story read is delayed
        When I open planning story {'ST291'}
        Then the planning message {'Waiting for the planner’s answer.'} appears once
        When I press planning breadcrumb {0}
        And the delayed planning story arrives
        Then the planning board is visible
        And planning has no asynchronous error

    # Harm: a narrow window hides navigation or crashes on long detail values.
    Scenario: Details remain reachable in a narrow window
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        And I use a narrow planning pane
        Then the planning breadcrumb is {'Planning,ST291,B541'}
        And planning has no asynchronous error
        When I press planning breadcrumb {1}
        Then the planning breadcrumb is {'Planning,ST291'}

    # Harm: missing or repeated numbers produce duplicate keys and crash the issue page.
    Scenario: Incomplete finding numbers remain readable
        Given the machine reports incomplete planning finding numbers
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then planning details contain {'First unnumbered finding'}
        And planning details contain {'Second unnumbered finding'}
        And planning details contain {'Repeated number first'}
        And planning details contain {'Repeated number second'}
        And planning has no asynchronous error

    # Harm: malformed report entries appear as confirmation of a clean reading.
    Scenario: A malformed findings report stays unknown
        Given the machine reports malformed planning findings
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then planning details contain {'Findings not reported completely'}
        And planning details do not contain {'No findings in the last reading.'}

    # Harm: provider fallback discards the board position or changes the detail source.
    Scenario: Provider fallback retains the board and detail owner
        Given another machine offers the same project planning
        When I search planning for {'ST'}
        And I filter planning to high and above
        And I fold the planning phase {'Analysis'}
        And I scroll the planning board
        And I remember the planning board position
        And I open planning story {'ST291'}
        And the planning watch fails
        Then planning details contain {'Story source'}
        And planning details do not contain {'Story supplied by another machine'}
        When I press planning breadcrumb {0}
        Then the planning board position is retained
        And the planning board contains {'Story supplied by another machine'}

    # Harm: malformed blockers are filtered into a confirmed unblocked issue.
    Scenario: Malformed blockers remain unknown
        Given the machine reports malformed planning blockers
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then the planning section {'Blocked by'} contains {'Not reported'}

    # Harm: an issue moved to another story keeps its old local owner link.
    Scenario: The reported issue owner opens its own story
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        And the machine lists planning issue {'B541'} under story {'ST294'}
        Then the planning section {'Story'} contains {'ST294'}
        When I open the planning owner story
        Then the planning breadcrumb is {'Planning,ST294'}

    # Harm: a parent failure hides an issue that was read and its valid browser link.
    Scenario: A failed parent leaves the issue and its link readable
        Given the planning part {'Story'} is refused
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then the planning detail error is {'Story: This part is locked for repair'}
        And planning details contain {'Only confirmed work is published'}
        When I open the planning web link {'Open issue'}
        Then the planning browser opened {'https://example.org/issues/B541'}

    # Harm: an issue-list failure is mistaken for an omitted list and hides the story link.
    Scenario: A failed issue list leaves the story and its link readable
        Given the planning part {'Issue list'} is refused
        When I open planning story {'ST291'}
        Then the planning detail error is {'Issue list: This part is locked for repair'}
        And planning details contain {'Story source'}
        And planning details do not contain {'Issues not reported'}
        When I open the planning web link {'Open story'}
        Then the planning browser opened {'https://example.org/stories/ST291'}

    # Harm: story work opens on the current machine instead of its own known task.
    Scenario: A story work link opens its task
        Given the planning story has known work
        When I open planning story {'ST291'}
        Then the planning task {'porelo-checkout-shell'} is available
        When I open the planning task {'porelo-checkout-shell'}
        Then the planning work opened is {'porelo-checkout-shell'}

    # Harm: the issue builder link cannot reach the task reported for its story.
    Scenario: An issue builder link opens its task
        Given the planning story has known work
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then the planning task {'porelo-checkout-shell'} is available
        When I open the planning task {'porelo-checkout-shell'}
        Then the planning work opened is {'porelo-checkout-shell'}

    # Harm: an unknown task is offered as an enabled action that silently does nothing.
    Scenario: Unknown story work explains why it cannot open
        Given the planning story has unknown work
        When I open planning story {'ST291'}
        Then the planning task {'missing-task'} is disabled with {'does not know task missing-task'}

    # Harm: an unknown issue builder is offered as an enabled action that silently does nothing.
    Scenario: Unknown issue work explains why it cannot open
        Given the planning story has unknown work
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then the planning task {'missing-task'} is disabled with {'does not know task missing-task'}

    # Harm: removing a provider disposes a board while its detail still listens.
    Scenario: Removing a provider closes its detail safely
        Given another machine offers the same project planning
        When I open planning story {'ST291'}
        And I remove the planning provider
        Then the unavailable planning source is shown
        And planning has no asynchronous error

    # Harm: partial sections claim that no report exists while showing entries from it.
    Scenario: Partial acceptance and sub-agent reports are labeled incomplete
        Given the planning issue has partial sections
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then planning details contain {'Acceptance criteria not reported completely'}
        And planning details contain {'Sub-agents not reported completely'}
        And planning details contain {'Visible reader'}

    # Harm: a failed story read hides its successfully read issue list.
    Scenario: A failed story leaves its issue table readable
        Given the planning part {'Story'} is refused
        When I open planning story {'ST291'}
        Then the planning detail error is {'Story: This part is locked for repair'}
        And the planning issue table is shown

    # Harm: a failed refresh blanks the last story and its issue table.
    Scenario: A failed story reload retains the last details
        When I open planning story {'ST291'}
        And the planning replacement part {'Story'} is refused
        Then planning details contain {'Story source'}
        And the planning issue table is shown
        And the planning detail error is {'Story: This part is locked for repair'}
        And the planning message {'Story: This part is locked for repair'} appears once

    # Harm: a failed issue-list refresh erases previously read rows.
    Scenario: A failed issue list reload retains the last table
        When I open planning story {'ST291'}
        And the planning replacement part {'Issue list'} is refused
        Then the planning issue table is shown
        And planning details contain {'Story source'}
        And the planning detail error is {'Issue list: This part is locked for repair'}

    # Harm: a failed issue refresh erases the issue and its valid browser link.
    Scenario: A failed issue reload retains the last issue
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        And the planning replacement part {'Issue'} is refused
        Then planning details contain {'Only confirmed work is published'}
        And the planning detail error is {'Issue: This part is locked for repair'}
        When I open the planning web link {'Open issue'}
        Then the planning browser opened {'https://example.org/issues/B541'}

    # Harm: a detail watch failure leaves no way to resume live updates on that screen.
    Scenario: The detail watch can be retried
        When I open planning story {'ST291'}
        And the planning watch fails
        And I reload planning
        Then planning details do not contain {'The last answer may be out of date'}
        And planning details contain {'Story source'}

    # Harm: an empty finding file produces a malformed or empty location.
    Scenario: A finding with an empty file shows only its line
        Given the machine reports an empty planning finding file
        When I unfold planning story {'ST291'}
        And I open planning issue {'B541'}
        Then planning details contain {'line 42'}
        And planning details do not contain {' · line 42'}

    # Harm: empty blockers read as an incomplete sentence on an unfolded card.
    Scenario: The board marks malformed blockers unknown
        Given the machine reports malformed planning blockers
        When I unfold planning story {'ST291'}
        Then the planning issue row {'B541'} says {'Blockers not reported'}
        And the planning issue row {'B541'} does not say {'Blocked by '}

    # Harm: wire mode names and empty coordinators make work information misleading.
    Scenario Outline: Work modes use their display names
        Given the planning story reports mode {'<mode>'}
        When I open planning story {'ST291'}
        Then planning details contain {'Mode: <label>'}
        And planning details do not contain {'Coordinator:'}
        Examples:
            | mode        | label          |
            | UNATTENDED  | unattended     |
            | AGENT       | shell with you |
            | FUTURE      | FUTURE         |

    # Harm: a row move changes sibling issues or appears saved before the daemon confirms it.
    Scenario: An issue moved alone and saved
        Given the planning move reply is held
        When I open planning story {'ST291'}
        And I move planning issue {'B541'} to {'Review'}
        Then the planning issue {'B541'} still reports {'Implementing'}
        And the planning issue {'B541'} is being saved in {'Review'}
        And the planning issue {'B540'} still reports {'Implementing'}
        When the planning move reply arrives
        Then the planning issue {'B541'} reports {'Review'}
        And the planning issue {'B540'} reports {'Implementing'}
        And planning issue changes are saved

    # Harm: a stale revision writes over newer work or leaves the issue unmovable on the board read again.
    Scenario: A stale revision moves nothing and the issue moves on the board read again
        When I open planning story {'ST291'}
        And the planning move revision becomes stale
        And I move planning issue {'B541'} to {'Review'}
        Then planning details contain {'Planning changed while B541 was moved; nothing was moved. Move it again.'}
        And the planning issue {'B540'} reports {'Review'}
        And the planning issue {'B541'} reports {'Implementing'}
        When I move planning issue {'B541'} to {'Review'}
        Then the planning issue {'B541'} reports {'Review'}
        And planning issue changes are saved

    # Harm: a refused move changes another issue or hides the daemon refusal.
    Scenario Outline: A daemon refusal of an issue move keeps its words
        Given the planning move is refused with {'<error>'}
        When I open planning story {'ST291'}
        And I move planning issue {'B541'} to {'Review'}
        Then planning details contain {'<words>'}
        And the planning issue {'B540'} reports {'Implementing'}
        And the planning issue {'B541'} reports {'Implementing'}
        Examples:
            | error              | words                    |
            | MoveNotAllowed     | Policy refused this move |
            | StateNotAllowed    | Policy refused this move |
            | EnteredOnlyByWork  | entered only by work     |
