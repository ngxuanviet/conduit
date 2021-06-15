import 'package:fs_test_agent/dart_project_agent.dart';
import 'package:test/test.dart';

void main() {
  test("Create agent", () {
    final agent = DartProjectAgent("test_project");
    print(agent.workingDirectory); //ignore: avoid_print
  });
}
