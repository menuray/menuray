import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';
import '../platform/camera_launcher.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final List<XFile> _shots = [];

  void _onCaptured(XFile x) => setState(() => _shots.add(x));

  void _onDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('相机不可用或权限被拒绝')),
    );
  }

  void _finish() {
    if (_shots.isEmpty) return;
    context.go(
      AppRoutes.correctImage,
      extra: List<XFile>.unmodifiable(_shots),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: buildCameraPreview(
                onCaptured: _onCaptured,
                onPermissionDenied: _onDenied,
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => context.go(AppRoutes.home),
              ),
            ),
            Positioned(
              bottom: 24,
              right: 16,
              child: ElevatedButton(
                onPressed: _shots.isEmpty ? null : _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: Text('完成 (${_shots.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
