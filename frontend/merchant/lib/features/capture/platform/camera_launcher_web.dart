import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
export 'package:image_picker/image_picker.dart' show XFile;

/// On web, `camera_screen`'s "shutter" actually opens the browser file picker
/// with camera hint. We render a full-bleed surface that dispatches the shot
/// on tap. Multi-shot accumulation happens in the calling screen.
Widget buildCameraPreview({
  required void Function(XFile shot) onCaptured,
  required VoidCallback onPermissionDenied,
}) {
  return _WebCaptureSurface(onCaptured: onCaptured);
}

class _WebCaptureSurface extends StatelessWidget {
  const _WebCaptureSurface({required this.onCaptured});
  final void Function(XFile) onCaptured;

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x != null) onCaptured(x);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _pick,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt, size: 80, color: Colors.white),
              SizedBox(height: 16),
              Text(
                '点击开始拍摄',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
}
