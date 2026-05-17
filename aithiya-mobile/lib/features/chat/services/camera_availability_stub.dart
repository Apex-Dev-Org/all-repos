/// Native (mobile/desktop) stub: assume the device-side `image_picker` plugin
/// will surface its own camera errors. We answer optimistically here so the
/// camera picker is always offered.
Future<bool> hasCameraDevice() async => true;
