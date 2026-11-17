/// Conditional export of [AppLocalDatabase] to ensure cross-platform compatibility:
/// - Native platforms (Android, iOS, Windows, macOS, Linux, VM tests) use `app_local_database_io.dart` (SQLite via `package:sqlite3`).
/// - Web platforms (Chrome, Firefox, Safari, Edge) use `app_local_database_web.dart` (In-memory storage without `dart:ffi`).
export 'app_local_database_io.dart'
    if (dart.library.js_interop) 'app_local_database_web.dart'
    if (dart.library.html) 'app_local_database_web.dart';
