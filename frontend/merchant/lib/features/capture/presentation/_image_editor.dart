import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../l10n/app_localizations.dart';

/// Self-drawn rotate + axis-aligned crop editor for a single XFile.
///
/// Loads the bytes once, paints them via [RawImage] rotated by
/// [_rotationTurns] × 90°, and overlays a 4-handle crop rectangle in
/// normalised (0..1) coords over the displayed (post-rotation) image.
/// On Apply, the bytes are re-decoded with `package:image`, rotated,
/// cropped, JPEG-encoded, and emitted as a new [XFile] via [onApply].
class ImageEditor extends StatefulWidget {
  const ImageEditor({super.key, required this.photo, required this.onApply});

  final XFile photo;
  final void Function(XFile edited) onApply;

  @override
  State<ImageEditor> createState() => _ImageEditorState();
}

class _ImageEditorState extends State<ImageEditor> {
  Uint8List? _bytes;
  ui.Image? _uiImage;
  int _rotationTurns = 0;
  // Normalised (0..1) in the currently-displayed (possibly rotated) image space.
  Rect _cropNorm = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);
  bool _processing = false;
  String? _error;

  static const double _minSize = 0.1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.photo.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _uiImage = frame.image;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context)!.correctImageDecodeFailed;
      });
    }
  }

  void _rotate() => setState(() {
    _rotationTurns = (_rotationTurns + 1) % 4;
    _cropNorm = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);
  });

  Future<void> _apply() async {
    if (_bytes == null) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    final decodeFailedMsg = AppLocalizations.of(
      context,
    )!.correctImageDecodeFailed;
    try {
      final decoded = img.decodeImage(_bytes!);
      if (decoded == null) {
        if (!mounted) return;
        setState(() {
          _error = decodeFailedMsg;
          _processing = false;
        });
        return;
      }
      var rotated = decoded;
      if (_rotationTurns != 0) {
        rotated = img.copyRotate(decoded, angle: _rotationTurns * 90);
      }
      final w = rotated.width;
      final h = rotated.height;
      final left = (_cropNorm.left * w).round().clamp(0, w - 1);
      final top = (_cropNorm.top * h).round().clamp(0, h - 1);
      final right = (_cropNorm.right * w).round().clamp(left + 1, w);
      final bottom = (_cropNorm.bottom * h).round().clamp(top + 1, h);
      final cropped = img.copyCrop(
        rotated,
        x: left,
        y: top,
        width: right - left,
        height: bottom - top,
      );
      final out = Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
      final edited = XFile.fromData(
        out,
        mimeType: 'image/jpeg',
        name: 'edited.jpg',
      );
      if (!mounted) return;
      setState(() => _processing = false);
      widget.onApply(edited);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_uiImage == null) {
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (ctx, cons) {
        final size = cons.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: Transform.rotate(
                angle: _rotationTurns * math.pi / 2,
                child: RawImage(image: _uiImage, fit: BoxFit.contain),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _CropOverlay(_cropNorm)),
              ),
            ),
            ..._buildHandles(size),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _processing ? null : _rotate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    icon: const Icon(Icons.rotate_90_degrees_cw),
                    label: Text(l.correctImageRotate),
                  ),
                  const Spacer(),
                  if (_error != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _processing ? null : _apply,
                    child: _processing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(l.correctImageProcessing),
                            ],
                          )
                        : Text(l.correctImageApply),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Builds the 4 draggable corner handles. Uses pan-delta accumulator
  // maths (d.delta / size) so the rect updates smoothly regardless of
  // where this widget sits in the widget tree.
  Iterable<Widget> _buildHandles(Size size) sync* {
    const handleSize = 32.0;

    Widget handleAt(
      double dx,
      double dy,
      void Function(Offset normalisedDelta) onDelta,
    ) {
      return Positioned(
        left: dx - handleSize / 2,
        top: dy - handleSize / 2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            onDelta(Offset(d.delta.dx / size.width, d.delta.dy / size.height));
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
          ),
        ),
      );
    }

    yield handleAt(
      _cropNorm.left * size.width,
      _cropNorm.top * size.height,
      (n) => setState(() {
        final newLeft = (_cropNorm.left + n.dx).clamp(
          0.0,
          _cropNorm.right - _minSize,
        );
        final newTop = (_cropNorm.top + n.dy).clamp(
          0.0,
          _cropNorm.bottom - _minSize,
        );
        _cropNorm = Rect.fromLTRB(
          newLeft,
          newTop,
          _cropNorm.right,
          _cropNorm.bottom,
        );
      }),
    );
    yield handleAt(
      _cropNorm.right * size.width,
      _cropNorm.top * size.height,
      (n) => setState(() {
        final newRight = (_cropNorm.right + n.dx).clamp(
          _cropNorm.left + _minSize,
          1.0,
        );
        final newTop = (_cropNorm.top + n.dy).clamp(
          0.0,
          _cropNorm.bottom - _minSize,
        );
        _cropNorm = Rect.fromLTRB(
          _cropNorm.left,
          newTop,
          newRight,
          _cropNorm.bottom,
        );
      }),
    );
    yield handleAt(
      _cropNorm.left * size.width,
      _cropNorm.bottom * size.height,
      (n) => setState(() {
        final newLeft = (_cropNorm.left + n.dx).clamp(
          0.0,
          _cropNorm.right - _minSize,
        );
        final newBottom = (_cropNorm.bottom + n.dy).clamp(
          _cropNorm.top + _minSize,
          1.0,
        );
        _cropNorm = Rect.fromLTRB(
          newLeft,
          _cropNorm.top,
          _cropNorm.right,
          newBottom,
        );
      }),
    );
    yield handleAt(
      _cropNorm.right * size.width,
      _cropNorm.bottom * size.height,
      (n) => setState(() {
        final newRight = (_cropNorm.right + n.dx).clamp(
          _cropNorm.left + _minSize,
          1.0,
        );
        final newBottom = (_cropNorm.bottom + n.dy).clamp(
          _cropNorm.top + _minSize,
          1.0,
        );
        _cropNorm = Rect.fromLTRB(
          _cropNorm.left,
          _cropNorm.top,
          newRight,
          newBottom,
        );
      }),
    );
  }
}

class _CropOverlay extends CustomPainter {
  _CropOverlay(this.rect);
  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = const Color(0x99000000);
    final r = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    );
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, r.top), shade);
    canvas.drawRect(Rect.fromLTRB(0, r.bottom, size.width, size.height), shade);
    canvas.drawRect(Rect.fromLTRB(0, r.top, r.left, r.bottom), shade);
    canvas.drawRect(
      Rect.fromLTRB(r.right, r.top, size.width, r.bottom),
      shade,
    );
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(r, stroke);
  }

  @override
  bool shouldRepaint(covariant _CropOverlay old) => old.rect != rect;
}
