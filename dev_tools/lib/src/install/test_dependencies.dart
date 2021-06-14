import 'dart:io';

import 'package:conduit_common/conduit_common.dart';
import 'package:dcli/dcli.dart';

/// Docker functions
void installDocker() {
  if (whichEx('docker')) {
    print('Using an existing docker install.');
    return;
  }

  if (isAptInstalled()) {
    print('Installing docker daemon');
    'apt --assume-yes install docker.io'.start(privileged: true);
  } else {
    printerr(
        red('Docker is not installed. Please install docker and start again.'));
    exit(1);
  }
}

/// Docker-Compose functions
void installDockerCompose() {
  if (whichEx('docker-compose')) {
    print('Using an existing docker-compose install.');
    return;
  }

  if (isAptInstalled()) {
    print('Installing docker-compose');
    'apt --assume-yes install docker-compose'.start(privileged: true);
  } else {
    printerr(red(
        'Docker-Compose is not installed. Please install docker-compose and start again.'));
    exit(1);
  }
}

bool isAptInstalled() => whichEx('apt');
