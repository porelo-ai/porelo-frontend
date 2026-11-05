import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/client.dart';
import 'package:porelo_frontend/src/app/shell_model.dart';
import 'package:porelo_frontend/src/ui/image_settings_view.dart';

import '../features/support/world.dart';

void main() {
  const ofAProject = ImageSettings(
    known: true,
    baseImage: ImageSetting(value: 'ubuntu:26.04', source: 'project.yml'),
    packages: <ImageSetting>[ImageSetting(value: 'jq', source: 'project.yml')],
    tools: <ImageSetting>[ImageSetting(value: 'git', source: 'porelo')],
    lines: <ImageSetting>[ImageSetting(value: 'ENV TOKEN=<withheld>', source: 'project.yml')],
    agent: ImageSetting(value: 'claude', source: 'agent package'),
    agentVersion: '2.1.0',
    securityClass: ImageSetting(value: 'standard', source: 'project.yml'),
    recorded: '2026-11-05T09:00:00Z',
  );

  Future<void> onWork(WidgetTester tester, String project) async {
    await World.startBackend(World.work);
    World.backend.publish(<Task>[Task.from(wire(World.aTask('$project-work', project)))]);
    await World.startApp(tester);
    await World.fleet.refresh(quietly: true);
    World.shell.goTo(Section.work);
    await World.settle(tester);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('tile-image-settings')));
    await tester.tap(find.byKey(const Key('tile-image-settings')));
    await World.settle(tester);
  }

  Future<void> openRow(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).first);
    await World.settle(tester);
  }

  // Harm: a person cannot tell what the work runs with, or who decided it.
  testWidgets('a task of a project names each setting and that it comes from project.yml', (tester) async {
    await onWork(tester, 'p');
    await openRow(tester, 'p-work');
    World.backend.theImageSays = ofAProject;
    await open(tester);
    expect(World.backend.imagesAsked, <String>['p-work']);
    final words = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((each) => each.textSpan?.toPlainText() ?? each.data ?? '');
    expect(words, contains(contains('ubuntu:26.04  from the project\'s project.yml')));
    expect(words, contains(contains('jq  from the project\'s project.yml')));
    expect(words, contains(contains('git  from Porelo\'s settings')));
    expect(words, contains(contains('ENV TOKEN=<withheld>')));
    expect(words, contains(contains('claude 2.1.0  from the agent\'s package')));
    expect(words, contains(contains('standard  from the project\'s project.yml')));
  });

  testWidgets('a task in Default says its settings are Porelo\'s', (tester) async {
    await onWork(tester, 'default');
    await openRow(tester, 'default-work');
    World.backend.theImageSays = const ImageSettings(
      known: true,
      baseImage: ImageSetting(value: 'ubuntu:26.04', source: 'porelo'),
      agent: ImageSetting(value: 'claude', source: 'agent package'),
      securityClass: ImageSetting(value: 'open', source: 'porelo'),
    );
    await open(tester);
    final words = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((each) => each.textSpan?.toPlainText() ?? each.data ?? '');
    expect(words, contains(contains('ubuntu:26.04  from Porelo\'s settings')));
    // An unset version says nothing rather than a blank after the agent's name.
    expect(words, contains(contains('claude  from the agent\'s package')));
  });

  // Harm: an image that does not say reads as an image with nothing in it.
  testWidgets('an image that does not say is not shown as having nothing', (tester) async {
    await onWork(tester, 'p');
    await openRow(tester, 'p-work');
    await open(tester);
    expect(find.byKey(const Key('image-settings-unknown')), findsOneWidget);
    expect(find.text('None recorded.'), findsNothing);
  });

  testWidgets('an older Porelo, and a task that is gone, are said', (tester) async {
    await onWork(tester, 'p');
    await openRow(tester, 'p-work');
    World.backend.imageSettingsFails = const FeatureNotSupported('ImageSettings');
    await open(tester);
    expect(find.textContaining('needs a newer Porelo'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await World.settle(tester);
    World.backend.imageSettingsFails = const VarlinkException('org.fuin.porelo.Tasks1.NoSuchTask');
    await open(tester);
    expect(find.textContaining('does not know a task called p-work'), findsOneWidget);
  });

  testWidgets('Running opens the same dialog from its bar', (tester) async {
    await World.startBackend(World.work);
    World.backend.publish(<Task>[Task.from(wire(World.aTask('p-work', 'p')))]);
    await World.startApp(tester);
    await World.fleet.refresh(quietly: true);
    World.shell.goTo(Section.work);
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('work-view-running')));
    await World.settle(tester);
    await tester.tap(find.byKey(const Key('running-image-settings')));
    await World.settle(tester);
    expect(find.byKey(const Key('image-settings-dialog')), findsOneWidget);
    expect(World.backend.imagesAsked, <String>['p-work']);
  });

  test('a machine\'s whole path to the project\'s file reads as the file, and where in it', () {
    expect(
      imageSourceWords('/home/me/.config/porelo/projects/x/project.yml (repositories.x.image)'),
      "from the project's project.yml (repositories.x.image)",
    );
  });

  test('a source this window does not know is shown as it comes', () {
    expect(imageSourceWords('the repository\'s Containerfile'), 'the repository\'s Containerfile');
  });

  test('a reply reads, and a reply saying nothing is not known', () {
    final said = ImageSettings.from(<String, dynamic>{
      'known': true,
      'baseImage': <String, dynamic>{'value': 'b', 'source': 's'},
      'lines': <Map<String, dynamic>>[
        <String, dynamic>{'value': 'l', 'source': 'x'},
      ],
      'agentVersion': '',
    });
    expect(said.known, isTrue);
    expect(said.baseImage.source, 's');
    expect(said.lines.single.value, 'l');
    expect(ImageSettings.from(const <String, dynamic>{}).known, isFalse);
  });
}
