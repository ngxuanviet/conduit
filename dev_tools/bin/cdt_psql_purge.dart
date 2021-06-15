#! /usr/bin/env dcli

import 'package:dcli/dcli.dart';

/// Deletes the test postgres db, the docker container and volume
///
/// Use this script to purge the system of an docker resources
///
void main(List<String> args) {
  print('Purging down Postgres docker container and the database');

  final pathToCiProject =
      join(DartProject.fromPath('.').pathToProjectRoot, '..', 'ci');

  'docker-compose down'.start(workingDirectory: pathToCiProject);

  var images =
      'docker images'.toList().where((line) => line.startsWith('postgres'));

  for (var image in images) {
    image = image.replaceAll(RegExp(r'\s+'), ' ');

    var parts = image.split(' ');

    if (parts.isEmpty) {
      continue;
    }

    final name = parts[0];
    final tag = parts[1];
    final id = parts[2];

    if (confirm('Delete docker image: $name $tag $id')) {
      'docker image rm $id'.run;
    }
    print('Done.');
  }
}
