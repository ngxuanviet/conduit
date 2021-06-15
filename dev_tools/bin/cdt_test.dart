#! /usr/bin/env dcli

import 'dart:io';

import 'package:conduit_common/conduit_common.dart';
import 'package:dcli/dcli.dart';
import 'package:conduit_dev_tools/conduit_dev_tools.dart';

/// This script will run the conduit unit tests
///
/// To run this script install dcli:
///
/// ```pub global activate dcli
/// ```
///
/// Then you can run:
///
/// ```
/// ./run_unit_tests.dart
/// ```
///
void main(List<String> args) {
  if (!whichEx('critical_test')) {
    print('Installing global package critical_test');
    DartSdk().globalActivate('critical_test');
  }
  if (!whichEx('pub_release')) {
    print('Installing global package pub_release');
    DartSdk().globalActivate('pub_release');
  }

  /// Required by conduit_config/test/config_test.dart
  env['TEST_VALUE'] = '1';
  env['TEST_BOOL'] = 'true';
  env['TEST_DB_ENV_VAR'] = 'postgres://user:password@host:5432/dbname';

  /// we use a fixed version no. for all of the projects.
  /// This avoid issues with pub publish bitching if some
  /// version no.s are beta releases and some not.
  DartProject conduitProject;
  if (exists('dev_tools')) {
    conduitProject = DartProject.fromPath('conduit');
  } else {
    conduitProject = DartProject.fromPath('.');
    if (conduitProject.pubSpec.name == 'dev_tools') {
      conduitProject = DartProject.fromPath('../conduit');
    }
  }
  if (!conduitProject.hasPubSpec) {
    printerr(red("We can't find the conduit project folder"));
    printerr('You must run this script from within the Conduit mono repo');
    exit(1);
  }

  final pathToCiProjectRoot =
      join(conduitProject.pathToProjectRoot, '..', 'ci');

  final version = conduitProject.pubSpec.version;

  final dbSettings = DbSettings.load();
  final pmgr = PostgresManager(dbSettings);
  if (!pmgr.isPostgresRunning()) {
    if (dbSettings.useContainer) {
      print('Starting postges daemon');
      pmgr.startPostgresDaemon(pathToCiProjectRoot, dbSettings);
    } else {
      printerr(red('Please start postgres and try again.'));
      print('''
The expected settings are:
Host: ${dbSettings.host}
Port: ${dbSettings.port}
User: ${dbSettings.username}
Password: ${dbSettings.password}
Database: ${dbSettings.dbName}''');
      exit(1);
    }
  }

  runEx('pub_release',
      args: 'multi --dry-run --no-git --setVersion=$version',
      workingDirectory: pathToCiProjectRoot);
}
