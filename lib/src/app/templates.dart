import 'package:flutter/foundation.dart';
import 'package:porelo_frontend/client.dart';

import 'settings.dart';

/// One recurring job, named.
///
/// **What it deliberately cannot carry is the point of it.** A template is a convenience, and a
/// convenience that quietly widens what work may reach is not one — so there is no field here for
/// `noGate` and none for `clearance`. Those are the two parameters of `Start` that weaken what a
/// run is held to, and a job somebody set up last month is the worst possible place for either to
/// be hiding.
///
/// The project's security class is not here either, and cannot be: `Start` has no parameter that
/// sets it. That half of the requirement is answered by the contract rather than by this class.
@immutable
class Template {
  /// Constructor taking everything a template carries.
  const Template({
    required this.name,
    required this.project,
    required this.agent,
    required this.mode,
    required this.prompt,
    this.repository = '',
  });

  /// What somebody calls this job.
  final String name;

  /// Which project it belongs to, by name.
  final String project;

  /// The agent to run, by the name `Agents` reports.
  final String agent;

  /// How somebody is meant to be involved.
  final Mode mode;

  /// What an unattended run is asked to do. Empty for the other modes.
  final String prompt;

  /// The repository it starts in, by name. Empty where none was chosen — a job named before
  /// repositories existed, or on a machine that names none.
  final String repository;

  /// Reads one from what was stored.
  ///
  /// Tolerant in the same way a reply is: a template stored by a later build with fields this one
  /// does not know renders rather than throwing, and one missing a field reads as empty.
  factory Template.fromStored(Map<String, Object?> stored) => Template(
    name: _text(stored['name']),
    project: _text(stored['project']),
    agent: _text(stored['agent']),
    mode: Mode(_text(stored['mode'])),
    prompt: _text(stored['prompt']),
    repository: _text(stored['repository']),
  );

  /// How it is written down.
  Map<String, Object?> get stored => <String, Object?>{
    'name': name,
    'project': project,
    'agent': agent,
    'mode': mode.name,
    'prompt': prompt,
    if (repository.isNotEmpty) 'repository': repository,
  };

  /// Whether this template could start anything at all.
  ///
  /// An unattended job with no prompt would start something and give it nothing to do, which is
  /// the one combination the start dialog already refuses.
  bool get startable =>
      name.isNotEmpty &&
      project.isNotEmpty &&
      agent.isNotEmpty &&
      mode.recognized &&
      (mode != Mode.unattended || prompt.trim().isNotEmpty);

  static String _text(Object? value) => value is String ? value : '';
}

/// The recurring jobs somebody has named, and the keeping of them.
///
/// **They follow the person, not the project.** The requirement asks for templates shared with
/// the project, and nothing in the contract writes to a project file except `SetEgress` — so a
/// template stored here is invisible to somebody else on the same machine, and to the same
/// project on another one. That is a real shortfall and it is said in the requirement rather than
/// papered over here.
class Templates extends ChangeNotifier {
  /// Constructor taking where they are kept.
  Templates(this._settings);

  final Settings _settings;
  List<Template> _all = const <Template>[];

  /// Every template, in the order they were named.
  List<Template> get all => List<Template>.unmodifiable(_all);

  /// The templates for one project.
  List<Template> forProject(String project) => <Template>[
    for (final each in _all)
      if (each.project == project) each,
  ];

  /// Reads back what an earlier run stored.
  Future<void> load() async {
    _all = <Template>[for (final stored in await _settings.templates()) Template.fromStored(stored)];
    notifyListeners();
  }

  /// Names a job, replacing one of the same name in the same project.
  ///
  /// Replacing rather than adding a second: two entries with one name in one project are two
  /// commands reading identically, and whichever ran would be the wrong one half the time.
  Future<void> keep(Template template) async {
    _all = <Template>[
      for (final each in _all)
        if (each.name != template.name || each.project != template.project) each,
      template,
    ];
    await _write();
  }

  /// Forgets one.
  Future<void> forget(Template template) async {
    _all = <Template>[
      for (final each in _all)
        if (each.name != template.name || each.project != template.project) each,
    ];
    await _write();
  }

  Future<void> _write() async {
    await _settings.rememberTemplates(<Map<String, Object?>>[for (final each in _all) each.stored]);
    notifyListeners();
  }
}
