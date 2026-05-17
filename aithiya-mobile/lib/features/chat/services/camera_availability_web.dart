import 'dart:js_interop';

// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

/// Web implementation: enumerate media devices and return whether at least
/// one `videoinput` device is present. Labels may be empty without a prior
/// permission grant, but the `kind` field is always populated, so we can
/// detect camera presence without requesting permission.
///
/// Returns `true` if we can't determine (browser too old, no
/// `mediaDevices` API, JS exception) so we don't accidentally hide the
/// camera option on supported browsers.
Future<bool> hasCameraDevice() async {
  try {
    final devices =
        await web.window.navigator.mediaDevices.enumerateDevices().toDart;
    for (final d in devices.toDart) {
      if (d.kind == 'videoinput') return true;
    }
    return false;
  } catch (_) {
    return true;
  }
}
