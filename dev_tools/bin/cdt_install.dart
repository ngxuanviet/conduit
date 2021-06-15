#! /usr/bin/env dcli

import 'package:dcli/dcli.dart';

void main() {
  final bin = DartProject.fromPath('.').pathToBinDir;

  final scripts = find('*.dart', workingDirectory: bin).toList();

  for (final script in scripts) {
    if (!Settings().isInstalled) {
      DCliPaths().dcliInstallName.run;
    }
    DartScript.fromFile(script).compile(install: true, overwrite: true);
  }
}
