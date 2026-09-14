/// The width to hand the WebView's own page capture, in logical pixels.
///
/// The screenshot command counts [width] in physical pixels, the same unit
/// the window capture uses. The WebView capture (the fallback without a
/// window: Android 7, or a backgrounded app) takes its width in logical
/// pixels and multiplies by the density itself, so passing the physical
/// number scaled a 1080-wide page up three times over on a 2 GB Android 7
/// phone and died allocating a hundred megabytes for the result. The width
/// is converted, and never exceeds the screen: the capture starts from a
/// bitmap the size of the view, so anything wider is an upscale that costs
/// memory and shows nothing more.
///
/// Null means "no scaling": the caller asked for nothing usable, or the
/// screen size is not known yet.
double? webViewSnapshotWidth({
  required int width,
  required double physicalWidth,
  required double devicePixelRatio,
}) {
  if (width <= 0 || devicePixelRatio <= 0) return null;
  if (physicalWidth <= 0) return null;
  final capped = width > physicalWidth ? physicalWidth : width.toDouble();
  return capped / devicePixelRatio;
}
