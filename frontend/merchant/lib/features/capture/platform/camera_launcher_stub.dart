import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;
export 'package:image_picker/image_picker.dart' show XFile;

/// Builds the camera-preview surface for the current platform. [onCaptured]
/// is invoked once per shot; callers accumulate into their own List.
Widget buildCameraPreview({
  required void Function(XFile shot) onCaptured,
  required VoidCallback onPermissionDenied,
}) =>
    throw UnsupportedError('camera_launcher: no platform impl');
