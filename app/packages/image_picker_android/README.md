# Android image picker used by Kiosk Satellite

This is the runtime source of Flutter's `image_picker_android` 0.8.13+19,
copied from the pub.dev package with its BSD license. Its Dart API and
generated channel code are unchanged. The app selects this copy through
`dependency_overrides` in `app/pubspec.yaml`.

The local change is in `ImagePickerDelegate.java`. Gallery launches catch
`ActivityNotFoundException` and `SecurityException` and finish the pending
request through the delegate's normal error path. That path clears the
callback before replying. Previously a failed launch escaped to Flutter's
channel handler, which replied without clearing the delegate's callback.
A later Android cancellation then replied again and crashed the process.

The regression tests live in
`app/android/app/src/test/kotlin/io/flutter/plugins/imagepicker/ImagePickerLaunchTest.kt`.
Run them from `app/android`:

```sh
./gradlew :app:testDebugUnitTest --tests io.flutter.plugins.imagepicker.ImagePickerLaunchTest
```

When updating this package, retain the launch handling and run those tests.
Remove the override when an upstream release handles the same failure.
