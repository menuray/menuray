// Platform-split entry point. Pulls the mobile impl on dart:io targets and the
// web impl on browser targets. Public interface is the free function below
// plus the exported ImagePicker XFile re-export from each impl.
export 'camera_launcher_stub.dart'
    if (dart.library.io) 'camera_launcher_io.dart'
    if (dart.library.html) 'camera_launcher_web.dart';
