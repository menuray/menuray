import 'package:camera/camera.dart' as cam;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;
export 'package:image_picker/image_picker.dart' show XFile;

class _CameraBody extends StatefulWidget {
  const _CameraBody({required this.onCaptured, required this.onDenied});
  final void Function(XFile) onCaptured;
  final VoidCallback onDenied;

  @override
  State<_CameraBody> createState() => _CameraBodyState();
}

class _CameraBodyState extends State<_CameraBody> {
  cam.CameraController? _controller;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await cam.availableCameras();
      if (cams.isEmpty) {
        setState(() => _initFailed = true);
        widget.onDenied();
        return;
      }
      final ctrl = cam.CameraController(
        cams.first,
        cam.ResolutionPreset.high,
        enableAudio: false,
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() => _controller = ctrl);
    } catch (_) {
      if (mounted) setState(() => _initFailed = true);
      widget.onDenied();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return;
    final file = await c.takePicture(); // returns an XFile (camera pkg)
    widget.onCaptured(XFile(file.path));
  }

  @override
  Widget build(BuildContext context) {
    if (_initFailed) {
      return const Center(
        child: Text(
          '相机不可用',
          style: TextStyle(color: Color(0xFFFFFFFF)),
        ),
      );
    }
    final c = _controller;
    if (c == null) return const ColoredBox(color: Color(0xFF000000));
    return Stack(
      fit: StackFit.expand,
      children: [
        cam.CameraPreview(c),
        Align(
          alignment: const Alignment(0, 0.85),
          child: GestureDetector(
            onTap: _shoot,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget buildCameraPreview({
  required void Function(XFile shot) onCaptured,
  required VoidCallback onPermissionDenied,
}) =>
    _CameraBody(onCaptured: onCaptured, onDenied: onPermissionDenied);
