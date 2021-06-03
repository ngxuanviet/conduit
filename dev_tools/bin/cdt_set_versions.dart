#! /usr/bin/env dcli

import 'dart:io';

import 'package:dcli/dcli.dart';
import 'package:pub_release/pub_release.dart';

/// Updates the version no.s of all top level packages.
///

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('version',
        abbr: 'v', help: 'The version no. to set all packages to.')
    ..addFlag('help', abbr: 'h', help: 'Shows this help message');

  final parsed = parser.parse(args);

  if (!parsed.wasParsed('version')) {
    printerr(red('You must pass a version.'));
    showUseage(parser);
  }

  final version = parsed['version'] as String;

  final settings = MultiSettings.load();
  settings.updateAllVersions(version);
  print(orange('Done.'));
}

void showUseage(ArgParser parser) {
  print(blue('Usage: ${DartScript.self.basename} --version=x.x.x'));
  print('');
  print('''
Sets the version no. of every top level pubspec.yaml to the same version no.
We then update all of the dependency constraints setting the entered version as the minimum value''');
  print(parser.usage);
  exit(1);
}
