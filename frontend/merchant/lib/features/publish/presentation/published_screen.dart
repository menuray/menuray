import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PublishedScreen extends StatelessWidget {
  const PublishedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable main content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Close button row ───────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: _CloseButton(onTap: () => context.go(AppRoutes.home)),
                  ),
                  const SizedBox(height: 16),

                  // ── Success header ─────────────────────────────────────
                  const _SuccessHeader(),
                  const SizedBox(height: 32),

                  // ── QR code card ───────────────────────────────────────
                  const _QrCard(),
                  const SizedBox(height: 24),

                  // ── Export action buttons ──────────────────────────────
                  const _ExportActions(),
                  const SizedBox(height: 20),

                  // ── Footer hint text ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3EC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '访客扫码即可查看，无需安装 App',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF717975),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Social share row ───────────────────────────────────
                  const _SocialShareRow(),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Sticky bottom CTA ──────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomCta(onTap: () => context.go(AppRoutes.home)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Close button (top-right)
// ---------------------------------------------------------------------------

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xFFE6E2DB),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close,
          color: Color(0xFF404945),
          size: 20,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success header: icon + heading + subtitle
// ---------------------------------------------------------------------------

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            color: Color(0xFFD6E7D8),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 52,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '菜单已发布！',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '云间小厨 · 午市套餐 2025 春',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF404945),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// QR code card (white card, fake QR + link row)
// ---------------------------------------------------------------------------

class _QrCard extends StatelessWidget {
  const _QrCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F1C1C18),
            blurRadius: 40,
            offset: Offset(0, 24),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          // Fake QR code
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x26000000), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 30,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: _FakeQrPainter(),
                ),
                _QrLogo(),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // URL link row
          const _LinkRow(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fake QR CustomPainter — deterministic pseudo-random 25×25 grid
// ---------------------------------------------------------------------------

class _FakeQrPainter extends StatelessWidget {
  const _FakeQrPainter();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _QrCustomPainter(),
      size: const Size(224, 224),
    );
  }
}

class _QrCustomPainter extends CustomPainter {
  static const int _cells = 25;

  // Fixed-seed pseudo-random pattern
  static final List<bool> _pattern = _buildPattern();

  static List<bool> _buildPattern() {
    final rng = Random(0xA13_DEAD_BEEF);
    final cells = <bool>[];
    for (int i = 0; i < _cells * _cells; i++) {
      cells.add(rng.nextBool());
    }

    // Force the three corner finder squares (7×7 each)
    void setBlock(int col, int row) {
      for (int dr = 0; dr < 7; dr++) {
        for (int dc = 0; dc < 7; dc++) {
          final r = row + dr;
          final c = col + dc;
          if (r < _cells && c < _cells) {
            // Outer border black, inner 3x3 black, middle ring white
            final isOuterBorder = dr == 0 || dr == 6 || dc == 0 || dc == 6;
            final isInnerBlock = dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4;
            cells[r * _cells + c] = isOuterBorder || isInnerBlock;
          }
        }
      }
    }

    setBlock(0, 0);          // top-left
    setBlock(_cells - 7, 0); // top-right
    setBlock(0, _cells - 7); // bottom-left

    // Quiet zone around center (for logo overlay)
    const center = _cells ~/ 2;
    for (int dr = -3; dr <= 3; dr++) {
      for (int dc = -3; dc <= 3; dc++) {
        final r = center + dr;
        final c = center + dc;
        if (r >= 0 && r < _cells && c >= 0 && c < _cells) {
          cells[r * _cells + c] = false;
        }
      }
    }

    return cells;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / _cells;
    final cellH = size.height / _cells;

    final black = Paint()..color = Colors.black;
    final white = Paint()..color = Colors.white;

    // Background
    canvas.drawRect(Offset.zero & size, white);

    for (int r = 0; r < _cells; r++) {
      for (int c = 0; c < _cells; c++) {
        if (_pattern[r * _cells + c]) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellW, r * cellH, cellW, cellH),
            black,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// QR logo overlay (restaurant icon in circle)
// ---------------------------------------------------------------------------

class _QrLogo extends StatelessWidget {
  const _QrLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.primaryDark,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.restaurant,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Link row (URL + copy button)
// ---------------------------------------------------------------------------

class _LinkRow extends StatelessWidget {
  const _LinkRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '访问链接',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF404945),
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'menu.menuray.app/luncha-spring',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFE6E2DB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.content_copy,
              color: AppColors.primaryDark,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Export action buttons (3-column row)
// ---------------------------------------------------------------------------

class _ExportActions extends StatelessWidget {
  const _ExportActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _ExportButton(icon: Icons.qr_code, label: '保存二维码', tertiary: false)),
        SizedBox(width: 12),
        Expanded(child: _ExportButton(icon: Icons.picture_as_pdf, label: '导出 PDF', tertiary: false)),
        SizedBox(width: 12),
        Expanded(child: _ExportButton(icon: Icons.share, label: '导出朋友圈图', tertiary: true)),
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.icon,
    required this.label,
    required this.tertiary,
  });

  final IconData icon;
  final String label;
  final bool tertiary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 30,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tertiary
                  ? const Color(0xFF5A3500).withValues(alpha: 0.1)
                  : const Color(0xFFD6E7D8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: tertiary ? const Color(0xFF5A3500) : AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1C1C18),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Social share row (WeChat / Copy / More)
// ---------------------------------------------------------------------------

class _SocialShareRow extends StatelessWidget {
  const _SocialShareRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _SocialButton(
          icon: Icons.chat_bubble,
          color: Color(0xFF07C160),
          label: '微信',
        ),
        SizedBox(width: 24),
        _SocialButton(
          icon: Icons.link,
          color: AppColors.primaryDark,
          label: '复制',
        ),
        SizedBox(width: 24),
        _SocialButton(
          icon: Icons.more_horiz,
          color: Color(0xFF717975),
          label: '更多',
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 30,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF717975),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom CTA bar
// ---------------------------------------------------------------------------

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surface.withValues(alpha: 0),
            AppColors.surface,
            AppColors.surface,
          ],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            '返回菜单首页',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
