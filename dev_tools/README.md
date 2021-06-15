The conduit dev_tools are designed to make developing and testing conduit easier.

To test conduit you will need a postgres database.

The recommended way to do this is to use a docker container running postgres.

The following scripts are available:

|Script | purpose
|---------------|------------
|cdt_psql_delete.dart | Deletes the Postgres test database
|cdt_psql_purge.dart | Completely removes the Postgres docker container.
|cdt_test.dart | Runs the unit tests of all conduit projects.
|cdt_setup.dart | Configures the unit test environment. Run this before running cdt_run.dart
|cdt_set_versions.dart | sets the version no. of all conduit packages to a single common version no. This should be done when preparing a release and before running cdt_run.dart
|cdt_psql_start.dart | Starts the psql container, recreating the test database.
|cdt_warmup.dart | Runs pub get on all of the conduit packages.  You can also use cdt_warmup to update all dependency versions by running cdt_warmup.dart --upgrade
|cdt_install.dart | Compiles and installs each of the cdt scripts onto your path so that you can directly run the scripts from any where in conduit mono repo. Once installed you can run `cdt_setup` instead of `bin\cdt_setup.dart` Note: for the install to work you must have the ~\.dcli\bin on your path.
|cdt_release.dart | Publishes the complete set of conduit packages to pub.dev. We assume that you have already succesfully ran all unit tests and so do not repeat them here.





