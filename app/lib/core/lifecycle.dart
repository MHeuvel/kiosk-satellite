import 'package:flutter/widgets.dart';

/// Where the app stands on screen, read from the lifecycle states the
/// framework reports.
///
/// On Android the embedding reports [AppLifecycleState.resumed] only once
/// the Activity is resumed and its window holds the input focus. Resumed
/// without focus arrives as [AppLifecycleState.inactive] and stays there,
/// so a device with a focus-holding window over the kiosk (a firmware
/// overlay, the notification shade) never reports resumed at all, and
/// anything that waited for it stayed stuck with the kiosk in plain view
/// (issue #560). Off screen is hidden, paused or detached. Everything
/// else is on screen, null included: nothing has been reported yet, which
/// is the whole first foreground session.
abstract final class Lifecycle {
  /// Whether [state] has the app off screen: behind another app, a dark
  /// panel, or no Activity at all.
  static bool offScreen(AppLifecycleState? state) =>
      state == AppLifecycleState.hidden ||
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached;

  /// Whether the app is on screen by the last state the framework
  /// reported.
  static bool get onScreen =>
      !offScreen(WidgetsBinding.instance.lifecycleState);
}

/// The app's return to the screen, told apart from the other lifecycle
/// events an observer receives.
///
/// Every resumed is a return. An inactive is one only after the app was
/// off screen: on the way out inactive comes before hidden and paused, on
/// the way back it comes after them, and it is where a return without the
/// input focus stops. One watch per observer, fed every state it sees.
class ReturnWatch {
  bool _off = false;

  /// Whether the app was off screen by the last state fed to [returned].
  bool get off => _off;

  /// True when [state] brings the app back on screen.
  bool returned(AppLifecycleState state) {
    if (Lifecycle.offScreen(state)) {
      _off = true;
      return false;
    }
    if (state == AppLifecycleState.resumed) {
      _off = false;
      return true;
    }
    if (!_off) return false;
    _off = false;
    return true;
  }
}
