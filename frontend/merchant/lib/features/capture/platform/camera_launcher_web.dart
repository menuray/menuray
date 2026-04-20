import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/app_localizations.dart';

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.cameraTapToCapture,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
}
