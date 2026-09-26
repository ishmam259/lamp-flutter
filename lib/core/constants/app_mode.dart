import 'package:flutter/foundation.dart';

/// Whether the testing tools are on screen: the demo controls (move the clock,
/// reset the world), the auto-scan, and the planted misrouted carton.
///
/// They make a debug build easy to exercise end to end. A release build is
/// for the pharmacists, officers and bank staff who use the app, and none of
/// that tooling belongs in front of them.
///
/// A tester build can switch them on in release mode too:
/// `flutter build apk --release --dart-define=DEMO_TOOLS=true`.
const bool kDemoTools =
    !kReleaseMode || bool.fromEnvironment('DEMO_TOOLS');
