import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Full-screen black background (camera viewfinder) ──────────
            const _ViewfinderBackground(),

            // ── Edge detection frame (green = detected) ───────────────────
            const _DetectionFrame(),

            // ── "可以拍了" success pill above frame ───────────────────────
            const _SuccessBubble(),

            // ── Light warning toast (below top bar) ───────────────────────
            const _LightWarningToast(),

            // ── Top bar overlay (close / flash / gallery) ─────────────────
            const _TopBar(),

            // ── Bottom controls (thumbnails / shutter / done) ─────────────
            const _BottomControls(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Viewfinder background — solid black simulating camera feed
// ─────────────────────────────────────────────────────────────────────────────

class _ViewfinderBackground extends StatelessWidget {
  const _ViewfinderBackground();

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.black);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edge detection frame — green border centered at ~70% w × 55% h
// ─────────────────────────────────────────────────────────────────────────────

class _DetectionFrame extends StatelessWidget {
  const _DetectionFrame();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameW = size.width * 0.80;
    final frameH = size.height * 0.55;

    return Center(
      child: SizedBox(
        width: frameW,
        height: frameH,
        child: Stack(
          children: [
            // Outer dim overlay effect — a shadow that dims outside the frame
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(102), // 40% black outside
                    blurRadius: 0,
                    spreadRadius: 9999,
                  ),
                ],
              ),
            ),
            // Corner accent — top-left
            const Positioned(
              top: -1,
              left: -1,
              child: _CornerAccent(corner: Corner.topLeft),
            ),
            // Corner accent — top-right
            const Positioned(
              top: -1,
              right: -1,
              child: _CornerAccent(corner: Corner.topRight),
            ),
            // Corner accent — bottom-left
            const Positioned(
              bottom: -1,
              left: -1,
              child: _CornerAccent(corner: Corner.bottomLeft),
            ),
            // Corner accent — bottom-right
            const Positioned(
              bottom: -1,
              right: -1,
              child: _CornerAccent(corner: Corner.bottomRight),
            ),
          ],
        ),
      ),
    );
  }
}

enum Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerAccent extends StatelessWidget {
  const _CornerAccent({required this.corner});

  final Corner corner;

  @override
  Widget build(BuildContext context) {
    final isTop = corner == Corner.topLeft || corner == Corner.topRight;
    final isLeft = corner == Corner.topLeft || corner == Corner.bottomLeft;

    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        painter: _CornerPainter(
          isTop: isTop,
          isLeft: isLeft,
          color: Colors.green,
          strokeWidth: 4,
          radius: 10,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.isTop,
    required this.isLeft,
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final bool isTop;
  final bool isLeft;
  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, radius);
      path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width - radius, 0);
      path.arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius));
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - radius);
      path.arcToPoint(Offset(radius, size.height), radius: Radius.circular(radius));
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height - radius);
      path.arcToPoint(Offset(size.width - radius, size.height),
          radius: Radius.circular(radius));
      path.lineTo(0, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.isTop != isTop ||
      old.isLeft != isLeft;
}

// ─────────────────────────────────────────────────────────────────────────────
// Success bubble — green pill "可以拍了 ✓" above the detection frame
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessBubble extends StatelessWidget {
  const _SuccessBubble();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Position above the detection frame center
    final frameH = size.height * 0.55;
    final topOffset = (size.height - frameH) / 2 - 44;

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '可以拍了',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.check, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Light warning toast — yellow pill below the top bar
// ─────────────────────────────────────────────────────────────────────────────

class _LightWarningToast extends StatelessWidget {
  const _LightWarningToast();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 72, // below the 64px top bar
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0C0), // warm yellow
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFF8B6200), size: 18),
              SizedBox(width: 6),
              Text(
                '光线偏暗，建议开启闪光灯',
                style: TextStyle(
                  color: Color(0xFF8B6200),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar — transparent overlay with close / flash / gallery
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // ── Close (X) ─────────────────────────────────────────────
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => context.go(AppRoutes.home),
            ),
            const Spacer(),
            // ── Flash toggle ─────────────────────────────────────────
            IconButton(
              icon: const Icon(Icons.flash_off, color: Colors.white),
              onPressed: () {}, // no-op
            ),
            // ── Gallery link ──────────────────────────────────────────
            TextButton(
              onPressed: () => context.go(AppRoutes.selectPhotos),
              child: const Text(
                '换相册上传',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom controls — thumbnails | shutter | done button
// ─────────────────────────────────────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  const _BottomControls();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left: thumbnail strip "3 张已拍" ──────────────────────
            const Expanded(
              child: _ThumbnailStrip(),
            ),
            // ── Center: shutter button ────────────────────────────────
            const _ShutterButton(),
            // ── Right: done button ────────────────────────────────────
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: const _DoneButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thumbnail strip — 3 overlapping small image previews with badge
// ─────────────────────────────────────────────────────────────────────────────

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Thumbnail 1 — back (slight left rotation)
          Positioned(
            left: 0,
            child: Transform.rotate(
              angle: -0.1,
              child: _ThumbBox(
                assetPath: 'assets/sample/menu_lunch.png',
                borderColor: Colors.white.withAlpha(51),
              ),
            ),
          ),
          // Thumbnail 2 — middle (slight right rotation)
          Positioned(
            left: 14,
            child: Transform.rotate(
              angle: 0.05,
              child: _ThumbBox(
                assetPath: 'assets/sample/menu_dinner.png',
                borderColor: Colors.white.withAlpha(51),
              ),
            ),
          ),
          // Thumbnail 3 — front (no rotation, green border = latest)
          Positioned(
            left: 28,
            child: _ThumbBox(
              assetPath: 'assets/sample/dish_mapo.png',
              borderColor: AppColors.success,
              borderWidth: 2,
            ),
          ),
          // Badge "3"
          Positioned(
            left: 60,
            top: -6,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Text(
                '3',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbBox extends StatelessWidget {
  const _ThumbBox({
    required this.assetPath,
    required this.borderColor,
    this.borderWidth = 1,
  });

  final String assetPath;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: borderWidth),
        color: AppColors.secondary.withAlpha(128),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, err, stack) => Container(
            color: AppColors.secondary.withAlpha(77),
            child: const Icon(Icons.image, color: Colors.white54, size: 20),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shutter button — large white circle with ring border
// ─────────────────────────────────────────────────────────────────────────────

class _ShutterButton extends StatelessWidget {
  const _ShutterButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // no-op for now
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withAlpha(128),
            width: 4,
          ),
        ),
        child: Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A1C1C18),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Done button — green pill "完成 (3)"
// ─────────────────────────────────────────────────────────────────────────────

class _DoneButton extends StatelessWidget {
  const _DoneButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(AppRoutes.correctImage),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26154539),
              blurRadius: 24,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          '完成 (3)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
