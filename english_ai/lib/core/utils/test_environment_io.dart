import 'dart:io';

/// `flutter test` sets FLUTTER_TEST=true. Disable real network calls in unit
/// and widget tests unless the test supplies its own transport.
bool get isFlutterTestEnvironment =>
    Platform.environment['FLUTTER_TEST'] == 'true';
