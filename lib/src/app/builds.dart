import 'package:porelo_frontend/client.dart';

/// What the builds of a task's pushes say, in words, as the machine follows them at the forge.
///
/// **Three states before any build, never guessed:** no reader follows this task (nothing is said),
/// a reader follows it and nothing was pushed yet, and a reader is named but does not work. The
/// machine says which through `buildReader` and `buildProblem`; a machine older than both says
/// nothing, which is not *no builds*.
abstract final class BuildsSaid {
  /// What a work tile says about builds, or null when there is nothing to say: a headline that
  /// stands out, and the commit, the jobs and the age under it: the build is a step that matters, and
  /// the jobs are only extra.
  static BuildLine? onTheTile(Task task, {DateTime? now}) {
    final reader = task.buildReader;
    if (reader == null || reader.isEmpty) return null;
    final problem = task.buildProblem ?? '';
    if (problem.isNotEmpty) return BuildLine(BuildLook.none, 'Builds not followed', problem);
    final latest = task.builds?.firstOrNull;
    if (latest == null) {
      return BuildLine(BuildLook.none, 'No build yet', 'no push yet; its builds are read from $reader');
    }
    final workflows = workflowsOf(latest);
    final runs = latest.runs;
    final (look, headline) = runs == null ? _fromJobs(latest, workflows) : _fromRuns(latest, workflows);
    final failed = latest.jobs.where((job) => job.result == 'failure').length;
    final age = _age(latest.since, now ?? DateTime.now().toUtc());
    return BuildLine(
      look,
      headline,
      <String>[
        latest.short,
        if (latest.jobs.isNotEmpty)
          '${latest.jobs.length} ${latest.jobs.length == 1 ? 'job' : 'jobs'}${failed > 0 ? ', $failed failed' : ''}',
        if (latest.detail.isNotEmpty) latest.detail,
        ?age,
      ].join(' · '),
      workflows: workflows,
    );
  }

  /// The headline from the jobs, where the machine lists no runs: the verdict covers only the
  /// workflows the forge has run so far.
  static (BuildLook, String) _fromJobs(Build latest, List<WorkflowLine> workflows) {
    final failedOnes = workflows.where((line) => line.named && line.look == BuildLook.failed).toList();
    // A workflow that failed is named, whatever the commit's one verdict says.
    if (failedOnes.isNotEmpty) return (BuildLook.failed, '${failedOnes.map((line) => line.name).join(', ')} failed');
    return latest.verdict == 'success' ? _passed(workflows) : _fromVerdict(latest.verdict);
  }

  /// The headline from the runs the machine lists, each with its own state: passed only where the
  /// machine says success and every run succeeded, none of them unfinished.
  static (BuildLook, String) _fromRuns(Build latest, List<WorkflowLine> workflows) {
    final failedOnes = workflows.where((line) => line.look == BuildLook.failed).toList();
    if (failedOnes.isNotEmpty) return (BuildLook.failed, '${_names(failedOnes)} failed');
    final verdict = _fromVerdict(latest.verdict);
    // A failure, a run underway or a reading that did not succeed is said as the machine says it,
    // never outweighed by the runs it has listed so far, and never read as no run at all.
    if (latest.verdict != 'success') return verdict;
    if (workflows.isEmpty) return (BuildLook.none, 'No workflow ran');
    final unfinished = workflows.where((line) => line.look == BuildLook.running).toList();
    if (unfinished.isNotEmpty) return (BuildLook.running, '${_names(unfinished)} not finished');
    if (workflows.every((line) => line.words == 'skipped')) return (BuildLook.none, 'No workflow ran');
    if (workflows.any((line) => line.look != BuildLook.passed)) return (BuildLook.none, 'Not every workflow passed');
    if (workflows.length == 1) return (BuildLook.passed, '${workflows.single.name} workflow passed');
    return (BuildLook.passed, 'Every workflow passed');
  }

  /// Each name once, in the order they come.
  static String _names(List<WorkflowLine> lines) => lines.map((line) => line.name).toSet().join(', ');

  /// What the commit's one verdict other than success says, where nothing more decides it.
  static (BuildLook, String) _fromVerdict(String verdict) => switch (verdict) {
    'failure' => (BuildLook.failed, 'Build failed'),
    'queued' => (BuildLook.running, 'Build queued'),
    'running' => (BuildLook.running, 'Build running'),
    '' => (BuildLook.none, 'Build: no verdict given'),
    // Final: the forge will not build this push, so no build is to come.
    'none' => (BuildLook.none, 'No build for this push'),
    // Said as it comes, never mapped onto one of the three: a verdict this interface does not
    // know is not a pass, a failure or a run.
    'cancelled' || 'unknown' => (BuildLook.none, 'Build $verdict'),
    final other => (BuildLook.none, 'Build: $other'),
  };

  /// What a commit's verdict of success says. The machine's verdict covers only the workflow runs
  /// the forge has made so far, so a pass is said over the runs that exist now, never as the whole
  /// build, and one workflow that passed is named as a workflow, even one called "Build".
  static (BuildLook, String) _passed(List<WorkflowLine> workflows) {
    final named = workflows.where((line) => line.named).toList();
    if (named.isEmpty) return (BuildLook.none, 'The machine says passed; its workflows are not reported');
    final ran = named.where((line) => line.words != 'skipped').toList();
    if (ran.isEmpty) return (BuildLook.none, 'No workflow ran');
    if (ran.any((line) => line.look != BuildLook.passed)) return (BuildLook.none, 'Not every workflow passed');
    if (ran.length == 1) return (BuildLook.passed, '${ran.single.name} workflow passed');
    return (BuildLook.passed, 'Passed: every workflow that has run');
  }

  /// One line per workflow of [build], in the forge's order, each with its own verdict: one per run
  /// where the machine lists the runs, else grouped from the jobs, and one line that says the
  /// workflow is not known where the machine gives the verdict without either.
  static List<WorkflowLine> workflowsOf(Build build) {
    final runs = build.runs;
    if (runs != null) return <WorkflowLine>[for (final run in runs) _run(run)];
    if (build.jobs.isEmpty) {
      final (look, words) = switch (build.verdict) {
        // Neutral: a pass over workflows nobody named cannot be told from a pass of one of them.
        'success' => (BuildLook.none, 'passed'),
        'failure' => (BuildLook.failed, 'failed'),
        'queued' || 'running' => (BuildLook.running, 'running'),
        '' => (BuildLook.none, 'no verdict given'),
        final other => (BuildLook.none, other),
      };
      return <WorkflowLine>[WorkflowLine(_notReported, look, words, named: false)];
    }
    final results = <String, List<String>>{};
    for (final job in build.jobs) {
      // The forge spells a job "<workflow> / <job>"; a name without the separator is its own workflow.
      final cut = job.name.indexOf(' / ');
      final before = cut < 0 ? job.name : job.name.substring(0, cut);
      // A workflow the forge left unnamed is said by the job's whole name, never as a blank line.
      final workflow = before.trim().isNotEmpty
          ? before
          : job.name.trim().isNotEmpty
          ? job.name.trim()
          : _unnamed;
      results.putIfAbsent(workflow, () => <String>[]).add(job.result);
    }
    return <WorkflowLine>[for (final MapEntry(key: name, value: jobs) in results.entries) _workflow(name, jobs)];
  }

  static const _notReported = 'workflow not reported by the machine';

  static const _unnamed = 'unnamed workflow';

  /// What the forge says of a job that did not pass for a fault of its own run, not a choice.
  static const _failed = <String>{'failure', 'timed_out', 'startup_failure'};

  static const _underway = <String>{'queued', 'in_progress', 'waiting', 'pending', 'requested', 'running'};

  /// What the forge says of a run that has not started yet.
  static const _notStarted = <String>{'queued', 'waiting', 'pending', 'requested'};

  /// One run, with its own verdict; a result not known here is said as the forge says it, and is no pass.
  static WorkflowLine _run(BuildRun run) {
    final name = run.name.trim().isEmpty ? _unnamed : run.name;
    final result = run.result;
    if (result == 'success') return WorkflowLine(name, BuildLook.passed, 'passed');
    if (_failed.contains(result)) return WorkflowLine(name, BuildLook.failed, 'failed');
    if (_notStarted.contains(result)) return WorkflowLine(name, BuildLook.running, 'not started');
    if (_underway.contains(result)) return WorkflowLine(name, BuildLook.running, 'running');
    return WorkflowLine(name, BuildLook.none, result.isEmpty ? 'no result given' : result);
  }

  static WorkflowLine _workflow(String name, List<String> results) {
    if (results.any(_failed.contains)) return WorkflowLine(name, BuildLook.failed, 'failed');
    if (results.any(_underway.contains)) return WorkflowLine(name, BuildLook.running, 'running');
    if (results.every((result) => result == 'skipped')) return WorkflowLine(name, BuildLook.none, 'skipped');
    // A job skipped beside one that passed is the workflow choosing not to run it, not a fault.
    final other = results.where((result) => result != 'success' && result != 'skipped');
    if (other.isEmpty) return WorkflowLine(name, BuildLook.passed, 'passed');
    final said = other.first.isEmpty ? 'no result given' : other.first;
    return WorkflowLine(name, BuildLook.none, said);
  }

  /// How long ago, from the time the machine wrote; null when it wrote none this can read.
  static String? _age(String since, DateTime now) {
    final then = DateTime.tryParse(since);
    if (then == null) return null;
    final gone = now.difference(then);
    if (gone.inMinutes < 1) return 'just now';
    if (gone.inHours < 1) return '${gone.inMinutes} min ago';
    if (gone.inDays < 1) return '${gone.inHours} h ago';
    return '${gone.inDays} d ago';
  }

  /// The lines the work's detail shows, newest build first; empty when there is nothing to say.
  static List<String> inTheDetail(Task task) {
    final reader = task.buildReader;
    if (reader == null || reader.isEmpty) return const [];
    final problem = task.buildProblem ?? '';
    final builds = task.builds ?? const <Build>[];
    return <String>[
      if (problem.isNotEmpty) 'not followed: $problem',
      if (problem.isEmpty && builds.isEmpty) 'no push yet; read from $reader',
      for (final build in builds) ...<String>[
        '${build.short}: ${_verdict(build)}${build.since.isEmpty ? '' : ', since ${build.since}'}',
        if (build.underway)
          '  no jobs yet'
        else
          for (final job in build.jobs)
            '  ${job.name}: ${job.result}, ${job.log.isEmpty ? 'no log here' : 'log in /porelo/files/${job.log}'}',
      ],
    ];
  }

  static String _verdict(Build build) {
    final failed = build.jobs.where((job) => job.result == 'failure').length;
    final verdict = build.verdict.isEmpty ? 'no verdict given' : build.verdict;
    return <String>[
      verdict,
      if (build.jobs.isNotEmpty) '${build.jobs.length} ${build.jobs.length == 1 ? 'job' : 'jobs'}',
      if (failed > 0) '$failed failed',
      if (build.detail.isNotEmpty) build.detail,
    ].join(', ');
  }
}

/// How a build reads at a glance: each drawn with its own shape and colour, and said in a word.
enum BuildLook {
  /// Every job passed.
  passed,

  /// A job failed, or the build did.
  failed,

  /// It has not ended.
  running,

  /// There is no build to show.
  none,
}

/// One workflow of a pushed commit, with its own verdict.
final class WorkflowLine {
  /// Constructor taking its name, how it looks and its verdict in a word.
  const WorkflowLine(this.name, this.look, this.words, {this.named = true});

  /// The workflow as the forge names it, or that the machine did not name it.
  final String name;

  /// Passed, failed, running, or none of them.
  final BuildLook look;

  /// Its verdict in a word, or as the forge says it where this interface does not know it.
  final String words;

  /// Whether [name] is the forge's, rather than words saying it is not known.
  final bool named;
}

/// What a work tile says about the build of its last push.
final class BuildLine {
  /// Constructor taking how it looks, its headline, its detail and its workflows.
  const BuildLine(this.look, this.headline, this.detail, {this.workflows = const <WorkflowLine>[]});

  /// One line per workflow of the commit; empty where there is no build to show.
  final List<WorkflowLine> workflows;

  /// Passed, failed, running, or none of them.
  final BuildLook look;

  /// The word that stands out, such as "Build failed".
  final String headline;

  /// The commit, the jobs and the age, or why there is no build.
  final String detail;
}
