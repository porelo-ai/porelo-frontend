import 'dart:convert';

import '../wire/varlink_exception.dart';

/// A fresh board for the interactive mock and scenarios to change independently.
Map<String, dynamic> mockPlanningBoard() => jsonDecode(r'''
{
  "states": [
    {
      "name": "Idea",
      "kind": "WAITING"
    },
    {
      "name": "Accepted",
      "kind": "WAITING"
    },
    {
      "name": "In analysis",
      "kind": "WORKING"
    },
    {
      "name": "Analyzed",
      "kind": "WAITING"
    },
    {
      "name": "Under estimation",
      "kind": "WORKING"
    },
    {
      "name": "Estimated",
      "kind": "WAITING"
    },
    {
      "name": "Backlog",
      "kind": "WAITING"
    },
    {
      "name": "Implementing",
      "kind": "WORKING"
    },
    {
      "name": "Reading",
      "kind": "WORKING"
    },
    {
      "name": "Review",
      "kind": "WAITING"
    },
    {
      "name": "Rework",
      "kind": "WAITING"
    },
    {
      "name": "Reworking",
      "kind": "WORKING"
    },
    {
      "name": "Finishing",
      "kind": "WORKING"
    },
    {
      "name": "Finished",
      "kind": "CLOSED"
    },
    {
      "name": "Rejected",
      "kind": "CLOSED"
    }
  ],
  "phases": [
    {
      "name": "Ideas",
      "states": [
        "Idea",
        "Accepted"
      ]
    },
    {
      "name": "Analysis",
      "states": [
        "In analysis",
        "Analyzed"
      ]
    },
    {
      "name": "Estimation",
      "states": [
        "Under estimation",
        "Estimated"
      ]
    },
    {
      "name": "Backlog",
      "states": [
        "Backlog"
      ]
    },
    {
      "name": "Build",
      "states": [
        "Implementing",
        "Reworking",
        "Reading",
        "Review",
        "Rework"
      ]
    },
    {
      "name": "Done",
      "states": [
        "Finishing",
        "Finished",
        "Rejected"
      ]
    }
  ],
  "stories": [
    {
      "id": "ST294",
      "title": "Plan the stories on a board in the window",
      "state": "In analysis",
      "priority": "High",
      "link": "https://example.org/stories/ST294",
      "issues": [],
      "work": {
        "tasks": [],
        "atWork": true,
        "since": "11:02",
        "coordinator": null,
        "repositories": [],
        "comment": "",
        "readingRounds": 2,
        "issueReadingRounds": [],
        "issues": []
      },
      "description": "The operator sees every story by state, the most important first, opens a story or an issue, and changes a story’s state by drag and drop, read from and written through a story API whose states are configured, not built in; a state change calls an action API.\n\nOpen Planning, find each story in its state’s column sorted by priority, open a story and one of its issues, drag a story to another state and save; the change is in porelo-project’s checkout. Rename a state in the configuration and the board shows it."
    },
    {
      "id": "ST72",
      "title": "A forge’s calls in a client that knows nothing of Porelo",
      "state": "Under estimation",
      "priority": "Medium",
      "link": "https://example.org/stories/ST72",
      "issues": [
        {
          "id": "PJ74",
          "repository": "porelo-project",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/PJ74",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "FC03",
          "repository": "porelo-forge-clients",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/FC03",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "FC09",
          "repository": "porelo-forge-clients",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/FC09",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "FC10",
          "repository": "porelo-forge-clients",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/FC10",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "FC11",
          "repository": "porelo-forge-clients",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/FC11",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "FC13",
          "repository": "porelo-forge-clients",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/FC13",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "work": {
        "tasks": [],
        "atWork": true,
        "coordinator": null,
        "repositories": [],
        "comment": "",
        "readingRounds": 2,
        "issueReadingRounds": [],
        "issues": []
      },
      "description": ""
    },
    {
      "id": "ST21",
      "title": "No channel file and no hand-over directory any more",
      "state": "Idea",
      "priority": "Highest",
      "link": "https://example.org/stories/ST21",
      "issues": [],
      "description": "",
      "work": null
    },
    {
      "id": "ST11",
      "title": "porelo-adapters and porelo-ai.github.io each in its own task",
      "state": "Idea",
      "priority": "Highest",
      "link": "https://example.org/stories/ST11",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST13",
      "title": "porelo and porelo-host each in its task, with a way back",
      "state": "Idea",
      "priority": "Highest",
      "link": "https://example.org/stories/ST13",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST28",
      "title": "The setup, move and recovery proven together",
      "state": "Idea",
      "priority": "Highest",
      "link": "https://example.org/stories/ST28",
      "issues": [],
      "description": "",
      "work": null
    },
    {
      "id": "ST87",
      "title": "Invalid machine inputs refused before renting",
      "state": "Idea",
      "priority": "Medium",
      "link": "https://example.org/stories/ST87",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST182",
      "title": "Review a Bitbucket pull request",
      "state": "Idea",
      "priority": "Low",
      "link": "https://example.org/stories/ST182",
      "issues": [],
      "description": "",
      "work": null
    },
    {
      "id": "ST114",
      "title": "A vulnerability has a way in and is answered",
      "state": "Accepted",
      "priority": "Medium",
      "link": "https://example.org/stories/ST114",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST111",
      "title": "Install from the intended package source",
      "state": "Accepted",
      "priority": "Medium",
      "link": "https://example.org/stories/ST111",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST144",
      "title": "Understand where a binding setting came from",
      "state": "Accepted",
      "priority": "Low",
      "link": "https://example.org/stories/ST144",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST14",
      "title": "The coordinator reads everything and changes only porelo-project",
      "state": "Analyzed",
      "priority": "Highest",
      "link": "https://example.org/stories/ST14",
      "issues": [
        {
          "id": "PJ58",
          "repository": "porelo-project",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/PJ58",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "description": "",
      "work": null
    },
    {
      "id": "ST39",
      "title": "A failed delivery named and kept visible",
      "state": "Analyzed",
      "priority": "High",
      "link": "https://example.org/stories/ST39",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST35",
      "title": "Refuse an incompatible protocol and a meaningless option",
      "state": "Analyzed",
      "priority": "High",
      "link": "https://example.org/stories/ST35",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST15",
      "title": "The website builds in its task",
      "state": "Estimated",
      "priority": "Highest",
      "link": "https://example.org/stories/ST15",
      "issues": [
        {
          "id": "SI05",
          "repository": "porelo-ai.github.io",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/SI05",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "description": "",
      "work": null
    },
    {
      "id": "ST106",
      "title": "Make security failures hold the release",
      "state": "Estimated",
      "priority": "Medium",
      "link": "https://example.org/stories/ST106",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST198",
      "title": "Reach a remote machine from Windows",
      "state": "Estimated",
      "priority": "Low",
      "link": "https://example.org/stories/ST198",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST291",
      "title": "The host run by a program of its own, built like porelo",
      "state": "Backlog",
      "priority": "Highest",
      "link": "https://example.org/stories/ST291",
      "issues": [
        {
          "id": "B540",
          "repository": "porelo",
          "state": "Implementing",
          "title": "The host tool as a module of porelo",
          "size": "M",
          "blockedBy": [],
          "link": "https://example.org/issues/B540",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B541",
          "whatMustBeTrue": "The work meets the story description.",
          "findings": [
            {
              "number": 1,
              "severity": "BLOCKING",
              "text": "Check the signature before using the record.",
              "file": "src/records.dart",
              "line": 42
            },
            {
              "number": 2,
              "severity": "NOTE",
              "text": "Keep the explanation beside the result."
            }
          ],
          "subAgents": [],
          "repository": "porelo",
          "state": "Implementing",
          "title": "The host tool reads the organization and a task by its signature",
          "size": "L",
          "blockedBy": [
            "B540"
          ],
          "link": "https://example.org/issues/B541",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false
        },
        {
          "id": "B542",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B542",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B543",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B543",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B544",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B544",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B545",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B545",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B546",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B546",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B547",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B547",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B548",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B548",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B549",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B549",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B550",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B550",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B551",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B551",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B552",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B552",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "HO156",
          "repository": "porelo-host",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/HO156",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "HO157",
          "repository": "porelo-host",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/HO157",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "description": "# The host tool\n\nThe host runs through a packaged native program.\n\nThe host is run by porelo-host, a native program packaged like porelo, instead of scripts copied onto it.\n\nRent a host, bring it up with porelo-host and run a move on it; every verb answers as the old scripts did.",
      "work": null
    },
    {
      "id": "ST292",
      "title": "A whole move rehearsed by the agents on a rented server",
      "state": "Backlog",
      "priority": "Highest",
      "link": "https://example.org/stories/ST292",
      "issues": [
        {
          "id": "B553",
          "repository": "porelo",
          "state": "Implementing",
          "title": "A move runs without a terminal for a rehearsal",
          "size": "M",
          "blockedBy": [],
          "link": "https://example.org/issues/B553",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B554",
          "repository": "porelo",
          "state": "Implementing",
          "title": "A forge token’s reach checked against what a move needs",
          "size": "S",
          "blockedBy": [],
          "link": "https://example.org/issues/B554",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "F444",
          "repository": "porelo-frontend",
          "state": "Implementing",
          "title": "A move driven through the window against a rented host",
          "size": "M",
          "blockedBy": [],
          "link": "https://example.org/issues/F444",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "F445",
          "repository": "porelo-frontend",
          "state": "Implementing",
          "title": "What a rehearsal cannot drive in the window, stood in for",
          "size": "S",
          "blockedBy": [
            "F444"
          ],
          "link": "https://example.org/issues/F445",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "HO158",
          "repository": "porelo-host",
          "state": "Implementing",
          "title": "A move rehearsed on a rented server",
          "size": "L",
          "blockedBy": [],
          "link": "https://example.org/issues/HO158",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "MX89",
          "repository": "porelo-message-matrix",
          "state": "Implementing",
          "title": "A test person signs in through the gate unattended",
          "size": "S",
          "blockedBy": [],
          "link": "https://example.org/issues/MX89",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "MX90",
          "repository": "porelo-message-matrix",
          "state": "Implementing",
          "title": "The room’s scenarios are rehearsed on a host",
          "size": "S",
          "blockedBy": [
            "MX89"
          ],
          "link": "https://example.org/issues/MX90",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "MX91",
          "repository": "porelo-message-matrix",
          "state": "Implementing",
          "title": "The rehearsal says a wake was answered",
          "size": "XS",
          "blockedBy": [
            "MX89"
          ],
          "link": "https://example.org/issues/MX91",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "description": "The agents rehearse a whole move on a rented server before the operator’s own test, so most problems are found earlier.\n\nRent a server and let the agents run the rehearsal; the report names every scenario OK, and the window and the room agree with the host.",
      "work": null
    },
    {
      "id": "ST293",
      "title": "Every agent works in a Porelo task, moved one at a time",
      "state": "Backlog",
      "priority": "Highest",
      "link": "https://example.org/stories/ST293",
      "issues": [],
      "description": "",
      "work": null
    },
    {
      "id": "ST23",
      "title": "The room and the usage records outlive the host",
      "state": "Backlog",
      "priority": "Highest",
      "link": "https://example.org/stories/ST23",
      "issues": [
        {
          "id": "MX24",
          "repository": "porelo-message-matrix",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/MX24",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "MX36",
          "repository": "porelo-message-matrix",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/MX36",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "MX39",
          "repository": "porelo-message-matrix",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/MX39",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "HO07",
          "repository": "porelo-host",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/HO07",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "B231",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B231",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "description": "",
      "work": null
    },
    {
      "id": "ST6",
      "title": "porelo-agy and porelo-codex each in its own task",
      "state": "Backlog",
      "priority": "Highest",
      "link": "https://example.org/stories/ST6",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST27",
      "title": "Every workflow runs on the local forge as on the central one",
      "state": "Implementing",
      "priority": "Highest",
      "link": "https://example.org/stories/ST27",
      "issues": [
        {
          "id": "IJ14",
          "repository": "porelo-intellij",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/IJ14",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "work": {
        "tasks": [
          {
            "task": "build-one",
            "containerId": "mock-build-one",
            "repository": "",
            "issues": [],
            "state": "Implementing",
            "done": "Review",
            "mode": "UNATTENDED",
            "agent": "",
            "model": "",
            "role": "MAIN",
            "since": "09:10",
            "atWork": true,
            "ended": null
          },
          {
            "task": "build-two",
            "containerId": "mock-build-two",
            "repository": "",
            "issues": [],
            "state": "Implementing",
            "done": "Review",
            "mode": "UNATTENDED",
            "agent": "",
            "model": "",
            "role": "MAIN",
            "since": "09:10",
            "atWork": true,
            "ended": null
          }
        ],
        "atWork": true,
        "coordinator": null,
        "since": "09:10",
        "repositories": [],
        "comment": "",
        "readingRounds": 2,
        "issueReadingRounds": [],
        "issues": []
      },
      "description": ""
    },
    {
      "id": "ST12",
      "title": "The release and pipeline tools the move rests on",
      "state": "Implementing",
      "priority": "Highest",
      "link": "https://example.org/stories/ST12",
      "issues": [
        {
          "id": "BT35",
          "repository": "porelo-buildtools",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/BT35",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "BT36",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT36",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "BT38",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT38",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "BT43",
          "repository": "porelo-buildtools",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/BT43",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "BT44",
          "repository": "porelo-buildtools",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/BT44",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "BT45",
          "repository": "porelo-buildtools",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/BT45",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "BT46",
          "repository": "porelo-buildtools",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/BT46",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "work": {
        "tasks": [
          {
            "task": "build-one",
            "containerId": "mock-build-one",
            "repository": "",
            "issues": [],
            "state": "Implementing",
            "done": "Review",
            "mode": "UNATTENDED",
            "agent": "",
            "model": "",
            "role": "MAIN",
            "since": "09:10",
            "atWork": true,
            "ended": null
          },
          {
            "task": "build-two",
            "containerId": "mock-build-two",
            "repository": "",
            "issues": [],
            "state": "Implementing",
            "done": "Review",
            "mode": "UNATTENDED",
            "agent": "",
            "model": "",
            "role": "MAIN",
            "since": "09:10",
            "atWork": true,
            "ended": null
          }
        ],
        "atWork": true,
        "coordinator": null,
        "since": "09:10",
        "repositories": [],
        "comment": "",
        "readingRounds": 2,
        "issueReadingRounds": [],
        "issues": []
      },
      "description": ""
    },
    {
      "id": "ST5",
      "title": "porelo-pi, porelo-omp and porelo-claude-code each in its own task",
      "state": "Implementing",
      "priority": "Highest",
      "link": "https://example.org/stories/ST5",
      "issues": [
        {
          "id": "PI43",
          "repository": "porelo-pi",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/PI43",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "OM44",
          "repository": "porelo-omp",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/OM44",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "CC45",
          "repository": "porelo-claude-code",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/CC45",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "PI39",
          "repository": "porelo-pi",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/PI39",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "OM36",
          "repository": "porelo-omp",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/OM36",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "CC39",
          "repository": "porelo-claude-code",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/CC39",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "work": {
        "tasks": [
          {
            "task": "build-one",
            "containerId": "mock-build-one",
            "repository": "",
            "issues": [],
            "state": "Implementing",
            "done": "Review",
            "mode": "UNATTENDED",
            "agent": "",
            "model": "",
            "role": "MAIN",
            "since": "09:10",
            "atWork": true,
            "ended": null
          },
          {
            "task": "build-two",
            "containerId": "mock-build-two",
            "repository": "",
            "issues": [],
            "state": "Implementing",
            "done": "Review",
            "mode": "UNATTENDED",
            "agent": "",
            "model": "",
            "role": "MAIN",
            "since": "09:10",
            "atWork": true,
            "ended": null
          }
        ],
        "atWork": true,
        "coordinator": null,
        "since": "09:10",
        "repositories": [],
        "comment": "",
        "readingRounds": 2,
        "issueReadingRounds": [],
        "issues": []
      },
      "description": ""
    },
    {
      "id": "ST193",
      "title": "Choose drive areas for each host",
      "state": "Implementing",
      "priority": "Low",
      "link": "https://example.org/stories/ST193",
      "issues": [
        {
          "id": "PJ106",
          "repository": "porelo-project",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/PJ106",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "work": {
        "tasks": [
          {
            "task": "build-one",
            "containerId": "mock-build-one",
            "repository": "",
            "issues": [],
            "state": "Implementing",
            "done": "Review",
            "mode": "UNATTENDED",
            "agent": "",
            "model": "",
            "role": "MAIN",
            "since": "09:10",
            "atWork": true,
            "ended": null
          },
          {
            "task": "build-two",
            "containerId": "mock-build-two",
            "repository": "",
            "issues": [],
            "state": "Implementing",
            "done": "Review",
            "mode": "UNATTENDED",
            "agent": "",
            "model": "",
            "role": "MAIN",
            "since": "09:10",
            "atWork": true,
            "ended": null
          }
        ],
        "atWork": true,
        "coordinator": null,
        "since": "09:10",
        "repositories": [],
        "comment": "",
        "readingRounds": 2,
        "issueReadingRounds": [],
        "issues": []
      },
      "description": ""
    },
    {
      "id": "ST127",
      "title": "Keep container limits on large hosts",
      "state": "Implementing",
      "priority": "Low",
      "link": "https://example.org/stories/ST127",
      "issues": [],
      "work": {
        "tasks": [
          {
            "task": "build-one",
            "containerId": "mock-build-one",
            "repository": "",
            "issues": [],
            "state": "Implementing",
            "done": "Review",
            "mode": "UNATTENDED",
            "agent": "",
            "model": "",
            "role": "MAIN",
            "since": "09:10",
            "atWork": true,
            "ended": null
          },
          {
            "task": "build-two",
            "containerId": "mock-build-two",
            "repository": "",
            "issues": [],
            "state": "Implementing",
            "done": "Review",
            "mode": "UNATTENDED",
            "agent": "",
            "model": "",
            "role": "MAIN",
            "since": "09:10",
            "atWork": true,
            "ended": null
          }
        ],
        "atWork": true,
        "coordinator": null,
        "since": "09:10",
        "repositories": [],
        "comment": "",
        "readingRounds": 2,
        "issueReadingRounds": [],
        "issues": []
      },
      "description": ""
    },
    {
      "id": "ST1",
      "title": "Builds on the host’s forge resolve snapshots with a read-only token",
      "state": "Review",
      "priority": "Highest",
      "link": "https://example.org/stories/ST1",
      "issues": [
        {
          "id": "BT42",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT42",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "BT39",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT39",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "HO52",
          "repository": "porelo-host",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/HO52",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "SL36",
          "repository": "porelo-message-sluice",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/SL36",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "BT40",
          "repository": "porelo-buildtools",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/BT40",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "BT41",
          "repository": "porelo-buildtools",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/BT41",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "HO53",
          "repository": "porelo-host",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/HO53",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "description": "",
      "work": null
    },
    {
      "id": "ST2",
      "title": "porelo-message-sluice works wholly in its task",
      "state": "Review",
      "priority": "Highest",
      "link": "https://example.org/stories/ST2",
      "issues": [
        {
          "id": "SL35",
          "repository": "porelo-message-sluice",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/SL35",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "description": "",
      "work": null
    },
    {
      "id": "ST3",
      "title": "porelo’s Build on the host’s Forgejo",
      "state": "Review",
      "priority": "Highest",
      "link": "https://example.org/stories/ST3",
      "issues": [
        {
          "id": "B306",
          "repository": "porelo",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/B306",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "description": "",
      "work": null
    },
    {
      "id": "ST10",
      "title": "Test machines by kind from the VM pool",
      "state": "Review",
      "priority": "Highest",
      "link": "https://example.org/stories/ST10",
      "issues": [
        {
          "id": "HO12",
          "repository": "porelo-host",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/HO12",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "BT24",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT24",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "BT25",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT25",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "description": "",
      "work": null
    },
    {
      "id": "ST264",
      "title": "A host prepared with no project or person",
      "state": "Finished",
      "priority": "Highest",
      "link": "https://example.org/stories/ST264",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST268",
      "title": "Each person’s one key and card, kept in the registry",
      "state": "Finished",
      "priority": "Highest",
      "link": "https://example.org/stories/ST268",
      "description": "",
      "issues": [],
      "work": null
    },
    {
      "id": "ST243",
      "title": "Both adapters pass one contract suite",
      "state": "Finished",
      "priority": "Highest",
      "link": "https://example.org/stories/ST243",
      "issues": [
        {
          "id": "PJ62",
          "repository": "porelo-project",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/PJ62",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        },
        {
          "id": "GH18",
          "repository": "porelo-adapters",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/GH18",
          "title": "Planning work",
          "size": "M",
          "rounds": 0,
          "roundsMost": 2,
          "atWork": false,
          "needsYou": false,
          "readingStopped": false,
          "findings": [],
          "whatMustBeTrue": "The work meets the story description.",
          "subAgents": []
        }
      ],
      "description": "",
      "work": null
    }
  ],
  "revision": "design-1",
  "work": [
    {
      "state": "In analysis",
      "from": [
        "Idea",
        "Accepted",
        "Analyzed",
        "Estimated",
        "Backlog",
        "Review",
        "Rework"
      ],
      "done": "Review",
      "then": null,
      "blocked": "Reworking",
      "per": "REPOSITORY",
      "modes": [
        "UNATTENDED",
        "AGENT"
      ],
      "order": "Read the story and complete its work."
    },
    {
      "state": "Under estimation",
      "from": [
        "Idea",
        "Accepted",
        "Analyzed",
        "Estimated",
        "Backlog",
        "Review",
        "Rework"
      ],
      "done": "Review",
      "then": null,
      "blocked": "Reworking",
      "per": "REPOSITORY",
      "modes": [
        "UNATTENDED",
        "AGENT"
      ],
      "order": "Read the story and complete its work."
    },
    {
      "state": "Implementing",
      "from": [
        "Idea",
        "Accepted",
        "Analyzed",
        "Estimated",
        "Backlog",
        "Review",
        "Rework"
      ],
      "done": "Review",
      "then": null,
      "blocked": "Reworking",
      "per": "REPOSITORY",
      "modes": [
        "UNATTENDED",
        "AGENT"
      ],
      "order": "Read the story and complete its work."
    },
    {
      "state": "Reading",
      "from": [
        "Idea",
        "Accepted",
        "Analyzed",
        "Estimated",
        "Backlog",
        "Review",
        "Rework"
      ],
      "done": "Review",
      "then": null,
      "blocked": "Reworking",
      "per": "REPOSITORY",
      "modes": [
        "UNATTENDED",
        "AGENT"
      ],
      "order": "Read the story and complete its work."
    },
    {
      "state": "Reworking",
      "from": [
        "Idea",
        "Accepted",
        "Analyzed",
        "Estimated",
        "Backlog",
        "Review",
        "Rework"
      ],
      "done": "Review",
      "then": null,
      "blocked": "Reworking",
      "per": "REPOSITORY",
      "modes": [
        "UNATTENDED",
        "AGENT"
      ],
      "order": "Read the story and complete its work."
    },
    {
      "state": "Finishing",
      "from": [
        "Idea",
        "Accepted",
        "Analyzed",
        "Estimated",
        "Backlog",
        "Review",
        "Rework"
      ],
      "done": "Review",
      "then": null,
      "blocked": "Reworking",
      "per": "REPOSITORY",
      "modes": [
        "UNATTENDED",
        "AGENT"
      ],
      "order": "Read the story and complete its work."
    }
  ],
  "faults": []
}
''') as Map<String, dynamic>;

/// Finds exactly one reported story for stand-in detail reads.
Map<String, dynamic>? mockPlanningStory(Map<String, dynamic> board, Object? id) {
  final stories = board['stories'];
  if (id is! String || id.isEmpty || stories is! List) return null;
  return stories.whereType<Map<String, dynamic>>().where((story) => story['id'] == id).firstOrNull;
}

/// Finds an issue and supplies its owning story from the stand-in store.
Map<String, dynamic>? mockPlanningIssue(Map<String, dynamic> board, Object? id) {
  final stories = board['stories'];
  if (id is! String || id.isEmpty || stories is! List) return null;
  for (final story in stories.whereType<Map<String, dynamic>>()) {
    final issues = story['issues'];
    if (issues is! List) continue;
    final issue = issues.whereType<Map<String, dynamic>>().where((issue) => issue['id'] == id).firstOrNull;
    if (issue != null) return Map<String, dynamic>.of(issue);
  }
  return null;
}

/// A refusal produced by the stateful planning stand-in.
class MockPlanningRefusal implements Exception {
  /// Keeps the refusal detail returned by the stand-in.
  const MockPlanningRefusal(this.detail);

  /// The verbatim reason this call was refused.
  final String detail;
}

/// The same daemon decisions behind the socket mock and widget FakeBackend.
class MockStoryWork {
  /// Uses the same store and publication path as the planning board.
  MockStoryWork(this.boardFor, this.changed);

  /// Reads the current board for a project.
  final Map<String, dynamic> Function(String) boardFor;

  /// Publishes the resulting board after a successful action.
  final void Function(String, Map<String, dynamic>) changed;

  /// Received methods and their exact parameters.
  final List<(String, Map<String, dynamic>)> calls = [];

  /// Scenario proposals indexed by story.
  final Map<String, Map<String, dynamic>> proposals = {};

  /// Scenario findings indexed by issue.
  final Map<String, List<Map<String, dynamic>>> findings = {};

  /// Scenario work records indexed by story.
  final Map<String, Map<String, dynamic>> statuses = {};

  /// An explicit scenario refusal.
  String? refusal;

  /// Whether a scenario holds back the watch publication.
  bool deferEcho = false;
  int _revision = 0;

  /// Applies one action to a copy and publishes only after validation.
  Map<String, dynamic> call(String method, Map<String, dynamic> parameters) {
    calls.add((method, jsonDecode(jsonEncode(parameters)) as Map<String, dynamic>));
    Never refuse(String name, Map<String, dynamic> fields) =>
        throw VarlinkException('org.fuin.porelo.Tasks1.$name', fields);
    if (refusal case final detail?) {
      refuse('WorkNotAllowed', {'from': '', 'to': parameters['to'] ?? '', 'reason': detail});
    }
    final project = parameters['project'];
    if (project is! String || project.isEmpty || project.contains('/') || project.contains('\\')) {
      refuse('InvalidSettings', {'detail': 'A project name is required.'});
    }
    final board = jsonDecode(jsonEncode(boardFor(project))) as Map<String, dynamic>;
    final stories = (board['stories'] as List).cast<Map<String, dynamic>>();
    final story = stories.where((story) => story['id'] == parameters['story']).firstOrNull;
    final issue = stories
        .expand((story) => (story['issues'] as List? ?? <dynamic>[]).cast<Map<String, dynamic>>())
        .where((issue) => issue['id'] == parameters['issue'])
        .firstOrNull;
    if (method == 'GetIssue') {
      if (issue == null) refuse('NoSuchIssue', {'issue': parameters['issue']});
      return {
        'issue': {...issue, 'findings': findings[issue['id']] ?? issue['findings'] ?? <dynamic>[]},
        'revision': board['revision'],
      };
    }
    if (story == null) refuse('NoSuchStory', {'story': parameters['story']});
    void checkRevision() {
      if (parameters['revision'] != board['revision']) refuse('StaleRevision', {'revision': board['revision']});
    }

    void publish() {
      board['revision'] = '${board['revision']}:work-${++_revision}';
      if (!deferEcho) changed(project, board);
    }

    Map<String, dynamic> emptyWork() => {
      'tasks': <Map<String, dynamic>>[],
      'coordinator': null,
      'since': '',
      'atWork': false,
      'repositories': <Map<String, dynamic>>[],
      'comment': '',
      'readingRounds': 2,
      'issueReadingRounds': <Map<String, dynamic>>[],
      'issues': <Map<String, dynamic>>[],
    };
    if (method == 'ResolveIssueReading') {
      checkRevision();
      if (issue == null ||
          !(story['issues'] as List).any((item) => (item as Map)['id'] == issue['id']) ||
          issue['readingStopped'] != true) {
        refuse('ReadingNotStopped', {'issue': parameters['issue']});
      }
      if (issue['rounds'] != parameters['round']) {
        refuse('ReadingRoundChanged', {'issue': issue['id'], 'rounds': issue['rounds']});
      }
      final choice = parameters['choice'];
      if (!['REVIEW_ANYWAY', 'ONE_MORE_ROUND', 'REWORK'].contains(choice) ||
          choice == 'REWORK' && (parameters['comment'] as String? ?? '').trim().isEmpty) {
        refuse('WorkNotAllowed', {
          'from': issue['state'],
          'to': '',
          'reason': 'Choose a reading decision; Rework needs a comment.',
        });
      }
      issue['readingStopped'] = false;
      issue['needsYou'] = false;
      if (choice == 'REVIEW_ANYWAY') {
        issue['state'] = 'Review';
      } else {
        final rounds = issue['rounds'] as int;
        final most = issue['roundsMost'] as int;
        issue['roundsMost'] = most > rounds ? most : rounds + 1;
        issue['atWork'] = true;
        issue['state'] = choice == 'REWORK' ? 'Reworking' : 'Reading';
        if (choice == 'ONE_MORE_ROUND') issue['rounds'] = rounds + 1;
      }
      final work = story['work'] is Map ? story['work'] as Map<String, dynamic> : emptyWork();
      work['issues'] = [
        for (final item in (story['issues'] as List).cast<Map<String, dynamic>>())
          {
            'issue': item['id'],
            'rounds': item['rounds'],
            'roundsMost': item['roundsMost'],
            'atWork': item['atWork'],
            'needsYou': item['needsYou'],
            'readingStopped': item['readingStopped'],
            'findings': item['findings'],
            'reason': item['readingStopped'] == true ? 'ROUND_LIMIT' : 'NONE',
          },
      ];
      story['work'] = work;
      publish();
      return {'issue': issue, 'work': work, 'revision': board['revision']};
    }
    if (method == 'GetStoryWork') return statuses[story['id']] ?? {'work': story['work']};
    if (method == 'ProposeStoryWork') {
      if (proposals[story['id']] case final supplied?) return supplied;
      final target = (board['states'] as List)
          .cast<Map<String, dynamic>>()
          .where((state) => state['name'] == parameters['to'])
          .firstOrNull;
      if (target?['kind'] != 'WORKING') {
        refuse('WorkNotAllowed', {
          'from': story['state'],
          'to': parameters['to'],
          'reason': 'The target is not a working state.',
        });
      }
      final issues = (story['issues'] as List? ?? <dynamic>[]).cast<Map<String, dynamic>>();
      final repositories = issues.map((issue) => issue['repository'] as String).toSet();
      if (repositories.isEmpty) repositories.add('porelo-project');
      return {
        'modes': ['UNATTENDED', 'AGENT'],
        'comment': '',
        'readingRounds': 2,
        'issueReadingRounds': <Map<String, dynamic>>[],
        'revision': board['revision'],
        'coordinator':
            stories.any(
              (other) =>
                  other['work'] is Map &&
                  (other['work'] as Map)['atWork'] == true &&
                  (other['work'] as Map)['coordinator'] != null,
            )
            ? 'TELL'
            : 'START',
        'repositories': [
          for (final repo in repositories)
            {
              'repository': repo,
              'issues': [
                for (final issue in issues)
                  if (issue['repository'] == repo) issue['id'],
              ],
              'main': {
                'name': 'main',
                'agent': 'codex',
                'model': 'proposed-model',
                'role': 'MAIN',
                'brief': 'Read the story and complete its work in $repo.',
              },
              'subAgents': [
                for (final issue in issues.where((issue) => issue['repository'] == repo))
                  for (final kind in ['BUILDER', 'READER'])
                    {
                      'id': '$repo/${issue['id']}/$kind',
                      'issue': issue['id'],
                      'name': kind.toLowerCase(),
                      'agent': kind == 'READER' ? 'claude-code' : 'codex',
                      'model': kind == 'READER' ? 'reader-model' : 'proposed-model',
                      'kind': kind,
                      'workingState': kind == 'READER' ? 'Reading' : parameters['to'],
                      'brief': kind == 'READER' ? 'Read the final changes.' : 'Build the issue.',
                      'choice': 'KEEP',
                    },
              ],
            },
        ],
      };
    }
    if (method == 'StopStoryWork') {
      final work = story['work'];
      if (work is Map<String, dynamic>) {
        work['atWork'] = false;
        for (final task in (work['tasks'] as List? ?? <dynamic>[]).cast<Map<String, dynamic>>()) {
          task['atWork'] = false;
        }
        for (final item in (story['issues'] as List? ?? <dynamic>[]).cast<Map<String, dynamic>>()) {
          item['atWork'] = false;
        }
        for (final item in (work['issues'] as List? ?? <dynamic>[]).cast<Map<String, dynamic>>()) {
          item['atWork'] = false;
        }
        publish();
      }
      return {'work': work};
    }
    if (method != 'StartStoryWork') refuse('NotYetBuilt', {'method': method});
    checkRevision();
    if (story['work'] is Map && (story['work'] as Map)['atWork'] == true) {
      refuse('WorkRunning', {
        'story': story['id'],
        'tasks': [for (final task in (story['work'] as Map)['tasks'] as List) (task as Map)['task']],
      });
    }
    final proposal = call('ProposeStoryWork', {'project': project, 'story': story['id'], 'to': parameters['to']});
    void invalid(String reason) =>
        refuse('WorkNotAllowed', {'from': story['state'], 'to': parameters['to'], 'reason': reason});
    if (!(proposal['modes'] as List).contains(parameters['mode'])) invalid('The project does not allow that mode.');
    final repos = (parameters['repositories'] as List? ?? proposal['repositories'] as List)
        .cast<Map<String, dynamic>>();
    final proposed = (proposal['repositories'] as List).cast<Map<String, dynamic>>();
    if (repos.length != proposed.length || repos.map((repo) => repo['repository']).toSet().length != repos.length) {
      invalid('Choose every repository exactly once.');
    }
    for (final repo in repos) {
      final original = proposed.where((item) => item['repository'] == repo['repository']).firstOrNull;
      if (original == null) invalid('The repository was not proposed.');
      final main = repo['main'] as Map;
      if (main['role'] != 'MAIN' || (main['agent'] as String).isEmpty || (main['model'] as String).isEmpty) {
        invalid('Choose a main agent and model.');
      }
      final assignments = (repo['subAgents'] as List).cast<Map<String, dynamic>>();
      final originals = (original!['subAgents'] as List).cast<Map<String, dynamic>>();
      if (assignments.length != originals.length ||
          assignments.map((sub) => sub['id']).toSet().length != originals.length) {
        invalid('Choose every proposed helper exactly once.');
      }
      for (final sub in assignments) {
        final source = originals.where((item) => item['id'] == sub['id']).firstOrNull;
        if (source == null ||
            ['issue', 'name', 'kind', 'workingState', 'brief'].any((key) => source[key] != sub[key])) {
          invalid('A helper identity or brief was changed.');
        }
        if (!['KEEP', 'CHANGE', 'DROP'].contains(sub['choice']) || sub['kind'] == 'OTHER' && sub['choice'] != 'DROP') {
          invalid('Unknown helpers cannot start.');
        }
        if (sub['choice'] != 'KEEP' && (parameters['comment'] as String? ?? '').trim().isEmpty) {
          invalid('A changed or dropped participant needs a comment.');
        }
      }
    }
    final rounds = parameters['readingRounds'] ?? proposal['readingRounds'];
    if (rounds is! int || rounds < 1) invalid('Reading rounds must be positive.');
    final overrides = parameters['issueReadingRounds'] as List? ?? proposal['issueReadingRounds'] as List;
    for (final value in overrides.cast<Map<String, dynamic>>()) {
      if (value['rounds'] is! int || (value['rounds'] as int) < 1) invalid('Reading rounds must be positive.');
    }
    final work = <String, dynamic>{
      'repositories': repos,
      'comment': parameters['comment'] ?? '',
      'readingRounds': rounds,
      'issueReadingRounds': overrides,
      'coordinator': repos.length > 1 ? 'coordinator' : null,
      'since': 'mock-start',
      'atWork': true,
      'tasks': [
        for (final repo in repos)
          {
            'task': repos.length == 1
                ? (story['id'] as String).toLowerCase()
                : '${(story['id'] as String).toLowerCase()}-${repo['repository']}',
            'containerId': 'mock-${story['id']}-${repo['repository']}',
            'repository': repo['repository'],
            'issues': repo['issues'],
            'state': parameters['to'],
            'done': 'Review',
            'mode': parameters['mode'],
            'agent': (repo['main'] as Map)['agent'],
            'model': (repo['main'] as Map)['model'],
            'role': 'MAIN',
            'since': 'mock-start',
            'atWork': true,
            'ended': null,
          },
        for (final repo in repos)
          for (final sub in (repo['subAgents'] as List).cast<Map<String, dynamic>>())
            if (sub['choice'] != 'DROP' &&
                sub['kind'] != 'READER' &&
                sub['kind'] != 'OTHER' &&
                sub['workingState'] == parameters['to'])
              {
                'task': '${(story['id'] as String).toLowerCase()}-${repo['repository']}-${sub['issue']}-${sub['name']}',
                'containerId': 'mock-${sub['id']}',
                'repository': repo['repository'],
                'issues': [sub['issue']],
                'state': parameters['to'],
                'done': 'Review',
                'mode': parameters['mode'],
                'agent': sub['agent'],
                'model': sub['model'],
                'role': sub['kind'],
                'since': 'mock-start',
                'atWork': true,
                'ended': null,
              },
      ],
      'issues': <Map<String, dynamic>>[],
    };
    final before = story['state'];
    story['state'] = parameters['to'];
    for (final item in (story['issues'] as List? ?? <dynamic>[]).cast<Map<String, dynamic>>()) {
      if (item['state'] == before) {
        item['state'] = parameters['to'];
        item['atWork'] = true;
      }
    }
    work['issues'] = [
      for (final item in (story['issues'] as List).cast<Map<String, dynamic>>())
        {
          'issue': item['id'],
          'rounds': item['rounds'] ?? 0,
          'roundsMost':
              overrides
                  .cast<Map<String, dynamic>>()
                  .where((entry) => entry['issue'] == item['id'])
                  .firstOrNull?['rounds'] ??
              rounds,
          'atWork': item['atWork'] == true,
          'needsYou': item['needsYou'] == true,
          'readingStopped': item['readingStopped'] == true,
          'findings': item['findings'] ?? <Map<String, dynamic>>[],
          'reason': 'NONE',
        },
    ];
    for (final item in (story['issues'] as List).cast<Map<String, dynamic>>()) {
      item['roundsMost'] =
          overrides
              .cast<Map<String, dynamic>>()
              .where((entry) => entry['issue'] == item['id'])
              .firstOrNull?['rounds'] ??
          rounds;
    }
    story['work'] = work;
    publish();
    return {'work': work, 'revision': board['revision']};
  }
}

/// Compact summaries omit the two optional full-detail fields.
Map<String, dynamic> planningSummary(Map<String, dynamic> board) => {
  'stories': [
    for (final story in (board['stories'] as List).cast<Map<String, dynamic>>())
      {
        ...story,
        'description': '',
        'issues': [
          for (final issue in (story['issues'] as List? ?? <dynamic>[]).cast<Map<String, dynamic>>())
            {...issue}
              ..remove('whatMustBeTrue')
              ..remove('subAgents'),
        ],
      },
  ],
  'revision': board['revision'],
};
