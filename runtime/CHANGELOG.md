# 2.0.0-b9
Fixed a bug with the conduit build command. We had left in dep overrides 
which should only be used for conduit internal dev.


# 2.0.0-b8
3rd attempt at first release.


# 1.0.0-b2
Invalided null check operator. extendedClause can be null. Changed to ? operator which will cause the comparison to fail which is what you would expect.
Was causing db migrations to fail.

Added repository to pubspec.yaml as pre publishing requirements.


# 1.0.0-b1
Initial release
