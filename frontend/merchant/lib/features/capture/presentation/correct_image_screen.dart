import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';

class CorrectImageScreen extends StatefulWidget {
  const CorrectImageScreen({super.key});

  @override
  State<CorrectImageScreen> createState() => _CorrectImageScreenState();
}

class _CorrectImageScreenState extends State<CorrectImageScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C18),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go(AppRoutes.selectPhotos),
        ),
        title: const Text(
          '校正图片 (1 / 3)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.processing),
            child: const Text(
              '下一步',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _ImageEditArea(spinController: _spinController),
          ),
          const _Toolbar(),
          const _ThumbStrip(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image edit area — dark background + tilted image + corner handles + overlay
// ─────────────────────────────────────────────────────────────────────────────

class _ImageEditArea extends StatelessWidget {
  const _ImageEditArea({required this.spinController});

  final AnimationController spinController;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C18),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Tilted menu image with 4 corner handles
            SizedBox(
              width: 280,
              height: 400,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Image with subtle tilt
                  Transform.rotate(
                    angle: 0.05,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/sample/menu_lunch.png',
                        width: 280,
                        height: 400,
                        fit: BoxFit.cover,
                        color: Colors.white.withAlpha(204), // 80% opacity
                        colorBlendMode: BlendMode.modulate,
                        errorBuilder: (context, err, stack) => Container(
                          width: 280,
                          height: 400,
                          color: AppColors.secondary.withAlpha(77),
                          child: const Icon(
                            Icons.image,
                            color: Colors.white54,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Perspective grid overlay
                  const Positioned.fill(
                    child: _GridOverlay(),
                  ),

                  // Corner handles
                  const Positioned(
                    top: -8,
                    left: -8,
                    child: _CornerHandle(),
                  ),
                  const Positioned(
                    top: -8,
                    right: -8,
                    child: _CornerHandle(),
                  ),
                  const Positioned(
                    bottom: -8,
                    left: -8,
                    child: _CornerHandle(),
                  ),
                  const Positioned(
                    bottom: -8,
                    right: -8,
                    child: _CornerHandle(),
                  ),
                ],
              ),
            ),

            // "智能校正中" loading overlay
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: _LoadingOverlay(spinController: spinController),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid overlay — 3×3 perspective correction grid
// ─────────────────────────────────────────────────────────────────────────────

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = AppColors.primary.withAlpha(128)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = AppColors.primary.withAlpha(77)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Outer border
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);

    // Vertical dividers at 1/3 and 2/3
    final col1 = size.width / 3;
    final col2 = size.width * 2 / 3;
    canvas.drawLine(Offset(col1, 0), Offset(col1, size.height), linePaint);
    canvas.drawLine(Offset(col2, 0), Offset(col2, size.height), linePaint);

    // Horizontal dividers at 1/3 and 2/3
    final row1 = size.height / 3;
    final row2 = size.height * 2 / 3;
    canvas.drawLine(Offset(0, row1), Offset(size.width, row1), linePaint);
    canvas.drawLine(Offset(0, row2), Offset(size.width, row2), linePaint);
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Corner handle — draggable green circle with white border
// ─────────────────────────────────────────────────────────────────────────────

class _CornerHandle extends StatelessWidget {
  const _CornerHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading overlay — "智能校正中" pill with spinning diamond icon
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.spinController});

  final AnimationController spinController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(230),
        borderRadius: BorderRadius.circular(9999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: spinController,
            child: const Icon(
              Icons.diamond_outlined,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '智能校正中',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom toolbar — 5 icon buttons
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C18),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ToolButton(
            icon: Icons.auto_fix_high,
            label: '自动校正',
            isActive: true,
          ),
          _ToolButton(
            icon: Icons.rotate_right,
            label: '旋转',
          ),
          _ToolButton(
            icon: Icons.crop,
            label: '裁剪',
          ),
          _ToolButton(
            icon: Icons.tune,
            label: '对比度增强',
          ),
          _ToolButton(
            icon: Icons.undo,
            label: '撤销',
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : Colors.white.withAlpha(153);

    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColors.primary.withAlpha(51)
                    : Colors.transparent,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom thumbnail strip — 3 thumbnails, first highlighted
// ─────────────────────────────────────────────────────────────────────────────

class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C18),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _ThumbItem(
            assetPath: 'assets/sample/menu_lunch.png',
            index: 1,
            isActive: true,
          ),
          SizedBox(width: 16),
          _ThumbItem(
            assetPath: 'assets/sample/menu_dinner.png',
            index: 2,
            isActive: false,
          ),
          SizedBox(width: 16),
          _ThumbItem(
            assetPath: 'assets/sample/dish_mapo.png',
            index: 3,
            isActive: false,
          ),
        ],
      ),
    );
  }
}

class _ThumbItem extends StatelessWidget {
  const _ThumbItem({
    required this.assetPath,
    required this.index,
    required this.isActive,
  });

  final String assetPath;
  final int index;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final size = isActive ? 64.0 : 56.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x4C154539),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Opacity(
              opacity: isActive ? 1.0 : 0.5,
              child: Image.asset(
                assetPath,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, err, stack) => Container(
                  color: AppColors.secondary.withAlpha(77),
                  child: const Icon(Icons.image, color: Colors.white54),
                ),
              ),
            ),
          ),
        ),
        // Active tint overlay
        if (isActive)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: AppColors.primary.withAlpha(26),
              ),
            ),
          ),
        // Number badge
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.black54,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
