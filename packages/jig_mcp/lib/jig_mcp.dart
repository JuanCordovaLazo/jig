/// A Model Context Protocol server for jig, over stdio.
///
/// Built on `JigVerbs` from `jig_driver`, so it is another client of the existing
/// extensions rather than a new surface: the ten-extension budget is untouched.
library;

export 'src/connect.dart';
export 'src/lazy.dart';
export 'src/rpc.dart';
export 'src/server.dart';
