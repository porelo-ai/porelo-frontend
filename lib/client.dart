/// The Porelo backend, typed.
///
/// Everything the interface does goes through here. Nothing else in this application may open a
/// socket, and nothing anywhere may run the `porelo` CLI.
library;

// The planning records the daemon's planning calls answer with.
export 'package:porelo_planning/planning_models.dart'
    show
        PlanState,
        PlanPhase,
        PlanWork,
        PlanWorkTask,
        PlanIssueReadingRounds,
        PlanWorkIssue,
        PlanIssue,
        PlanStory,
        PlanningSnapshot,
        PlanningMove,
        PlanningStoryMove,
        PlanningIssueMove,
        PlanningMoveResult,
        PlanFinding,
        PlanWorker,
        PlanStoryDetail,
        PlanIssueList,
        PlanIssueDetail,
        WorkEnded,
        PlanAssignment,
        PlanRepositoryWork,
        StoryWorkIssue,
        StoryWorkProposal,
        StoryWorkMainAgent,
        StoryWorkChoice,
        StoryWorkRequest,
        StoryWorkStarted,
        StoryWorkStatus,
        PlanningIssueDetail,
        PlanWorkRule,
        ReadingResolution;

export 'src/client/models.dart';
export 'src/client/porelo_client.dart';
export 'src/wire/varlink_connection.dart';
export 'src/wire/varlink_exception.dart';
