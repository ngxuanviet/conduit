#! /usr/bin/env dcli

import 'package:dcli/dcli.dart';

/// runs pub get on each project.
/// Use this method after cloning the repo to
/// ensure that all dependencies have been
/// downloaded
void main(List<String> args) {
  var parser = ArgParser();
  parser.addFlag('upgrade',
      defaultsTo: false, help: 'Upgrades all of the project dependencies');

  final parsed = parser.parse(args);

  final upgrade = parsed['upgrade'] as bool;

  final project = DartProject.fromPath('.');

  final action = (upgrade) ? 'upgrade' : 'get';

  find('pubspec.yaml', workingDirectory: dirname(project.pathToProjectRoot))
      .forEach((pubspec) {
    print('Running pub get for ${dirname(pubspec)}');
    DartSdk().runPub(
        args: [action, dirname(pubspec)], progress: Progress.printStdErr());
  });
}
