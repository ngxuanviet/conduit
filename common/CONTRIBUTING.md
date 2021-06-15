- For bug fixes, please file an issue or submit a pull request to master. 
- For documentation improvements (typos, errors, etc.), please submit a pull request to the branch `docs/source`.
- For new features that are not already identified in issues, please file a new issue to discuss.

## Pull Request Requirements

Please document the intent of the pull request. All non-documentation pull requests must also include automated tests that cover the new code, including failure cases. If applicable, please update the documentation in the `docs/source` branch.

## Running Tests

Tests will automatically be run when you submit a pull request, but you will need to run tests locally. 

Run all tests with the following command:

                pub run test -j 1
