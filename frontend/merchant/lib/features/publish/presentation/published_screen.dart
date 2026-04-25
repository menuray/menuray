import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/app_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../shared/models/menu.dart';
import '../../../shared/models/store.dart';
import '../../../theme/app_colors.dart';
import '../../home/home_providers.dart';
import '../../manage/menu_management_provider.dart';
import '../data/qr_export_service.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PublishedScreen extends ConsumerWidget {
  const PublishedScreen({super.key, required this.menuId});

  final String menuId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(menuByIdProvider(menuId));
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: _ErrorBody(
          message: AppLocalizations.of(context)!.publishedLoadFailed('$err'),
          onRetry: () => ref.invalidate(menuByIdProvider(menuId)),
        ),
      ),
      data: (menu) => _PublishedBody(menu: menu),
    );
  }
}

class _PublishedBody extends ConsumerStatefulWidget {
  const _PublishedBody({required this.menu});

  final Menu menu;

  @override
  ConsumerState<_PublishedBody> createState() => _PublishedBodyState();
}

class _PublishedBodyState extends ConsumerState<_PublishedBody> {
  final GlobalKey _shareCardKey = GlobalKey();

  Menu get _menu => widget.menu;

  String get _url => _menu.slug != null
      ? AppConfig.customerMenuUrl(_menu.slug!)
      : AppLocalizations.of(context)!.publishedUnpublished;

  bool get _isDraft => _menu.slug == null;

  Future<void> _handleCopyLink() async {
    if (_isDraft) return;
    final l = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: _url));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.publishedLinkCopied)));
  }

  Future<void> _handleShareUrl(String storeName) async {
    if (_isDraft) return;
    final l = AppLocalizations.of(context)!;
    await SharePlus.instance.share(
      ShareParams(
        text: _url,
        subject: l.publishedShareSubject(storeName),
      ),
    );
  }

  Future<void> _handleShareQrPng(String storeName) async {
    if (_isDraft) return;
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ref
          .read(qrExportServiceProvider)
          .renderToPng(boundaryKey: _shareCardKey, menuId: _menu.id);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: _url,
          subject: l.publishedShareSubject(storeName),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.publishedShareFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final storeAsync = ref.watch(currentStoreProvider);
    final Store? store = storeAsync.asData?.value;
    final storeName = store?.name ?? '';

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
                  _SuccessHeader(menuName: _menu.name),
                  const SizedBox(height: 32),

                  // ── QR code card ───────────────────────────────────────
                  _QrCard(
                    url: _url,
                    isDraft: _isDraft,
                    logoUrl: store?.logoUrl,
                    onCopyLink: _handleCopyLink,
                  ),
                  const SizedBox(height: 24),

                  // ── Export action buttons ──────────────────────────────
                  _ExportActions(
                    onSaveQr: _isDraft ? null : () => _handleShareQrPng(storeName),
                    onShareSocial:
                        _isDraft ? null : () => _handleShareQrPng(storeName),
                  ),
                  const SizedBox(height: 20),

                  // ── Footer hint text ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3EC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l.publishedFooterHint,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF717975),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Social share row ───────────────────────────────────
                  _SocialShareRow(
                    onCopy: _isDraft ? null : _handleCopyLink,
                    onShare: _isDraft ? null : () => _handleShareUrl(storeName),
                  ),
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

            // ── Off-screen capture target for share PNG ────────────────
            // Wrapped in Offstage so it lays out + paints (RepaintBoundary
            // requires a paint pass) but is invisible to the user.
            if (!_isDraft)
              Offstage(
                offstage: true,
                child: RepaintBoundary(
                  key: _shareCardKey,
                  child: _QrShareCard(
                    url: _url,
                    storeName: storeName,
                    scanCaption: l.publishedScanCaption,
                  ),
                ),
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
  const _SuccessHeader({required this.menuName});

  final String menuName;

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
        Text(
          AppLocalizations.of(context)!.publishedSuccessHeading,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          menuName,
          style: const TextStyle(
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
// QR code card — visible on-screen. Real qr_flutter widget; embeds the store
// logo at the centre when available (high error-correction lets us spare
// up to 30% of cells without breaking decode reliability).
// ---------------------------------------------------------------------------

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.url,
    required this.isDraft,
    required this.logoUrl,
    required this.onCopyLink,
  });

  final String url;
  final bool isDraft;
  final String? logoUrl;
  final VoidCallback onCopyLink;

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
          // Real QR (or a "draft" placeholder if no slug yet)
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
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: isDraft
                  ? const _DraftQrPlaceholder()
                  : QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      size: 224,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      embeddedImage: (logoUrl != null && logoUrl!.isNotEmpty)
                          ? NetworkImage(logoUrl!)
                          : null,
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size(48, 48),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // URL caption (monospace) — below the QR
          Text(
            url,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Color(0xFF404945),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          if (isDraft) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE6E2DB),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                AppLocalizations.of(context)!.publishedUnpublished,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF717975),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // URL link row (label + copy button)
          _LinkRow(onTap: isDraft ? null : onCopyLink),
        ],
      ),
    );
  }
}

// Draft placeholder — neutral grid pattern so the screen still has visual
// presence before the menu has been published. Decorative only.
class _DraftQrPlaceholder extends StatelessWidget {
  const _DraftQrPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.qr_code_2,
          size: 96,
          color: Color(0xFFB8B0A0),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Off-screen share card. Captured via RepaintBoundary → PNG → share_plus.
// Fixed 600 logical-px width so the resulting PNG looks the same regardless
// of device size. No embedded logo (avoids network-image timing risk during
// the off-screen capture).
// ---------------------------------------------------------------------------

class _QrShareCard extends StatelessWidget {
  const _QrShareCard({
    required this.url,
    required this.storeName,
    required this.scanCaption,
  });

  final String url;
  final String storeName;
  final String scanCaption;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: 600,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (storeName.isNotEmpty) ...[
                Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primaryDark,
                    width: 2,
                  ),
                ),
                child: QrImageView(
                  data: url,
                  version: QrVersions.auto,
                  size: 460,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                scanCaption,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                url,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: Color(0xFF717975),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              const Text(
                'menuray.com',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF98968F),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Link row (URL + copy button)
// ---------------------------------------------------------------------------

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F3EC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.publishedCopyLink,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: onTap == null
                      ? const Color(0xFF98968F)
                      : AppColors.primaryDark,
                  letterSpacing: 0.4,
                ),
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
              child: Icon(
                Icons.content_copy,
                color: onTap == null
                    ? const Color(0xFF98968F)
                    : AppColors.primaryDark,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Export action buttons. PDF export is deferred to P1; we render only Save QR
// + Share Social and let them both invoke the share-PNG handler — the system
// share sheet exposes "Save Image" so the merchant can save or hand off to
// any installed app from a single source of truth.
// ---------------------------------------------------------------------------

class _ExportActions extends StatelessWidget {
  const _ExportActions({
    required this.onSaveQr,
    required this.onShareSocial,
  });

  final VoidCallback? onSaveQr;
  final VoidCallback? onShareSocial;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _ExportButton(
            icon: Icons.qr_code,
            label: l.publishedExportQr,
            tertiary: false,
            onTap: onSaveQr,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ExportButton(
            icon: Icons.share,
            label: l.publishedExportSocial,
            tertiary: true,
            onTap: onShareSocial,
          ),
        ),
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.icon,
    required this.label,
    required this.tertiary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool tertiary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Container(
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
                  color: tertiary
                      ? const Color(0xFF5A3500)
                      : AppColors.primaryDark,
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
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Social share row (WeChat-styled / Copy / More).
//
// WeChat and More both invoke the system share sheet: iOS / Android route to
// installed apps including WeChat. Copy invokes the clipboard handler.
// ---------------------------------------------------------------------------

class _SocialShareRow extends StatelessWidget {
  const _SocialShareRow({required this.onCopy, required this.onShare});

  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialButton(
          icon: Icons.chat_bubble,
          color: const Color(0xFF07C160),
          label: l.publishedSocialWeChat,
          onTap: onShare,
        ),
        const SizedBox(width: 24),
        _SocialButton(
          icon: Icons.link,
          color: AppColors.primaryDark,
          label: l.publishedSocialCopy,
          onTap: onCopy,
        ),
        const SizedBox(width: 24),
        _SocialButton(
          icon: Icons.more_horiz,
          color: const Color(0xFF717975),
          label: l.publishedSocialMore,
          onTap: onShare,
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
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Column(
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
        ),
      ),
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
          child: Text(
            AppLocalizations.of(context)!.publishedReturnHome,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error body — shown when menuByIdProvider fails
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFF717975),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF404945),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
              ),
              child: Text(AppLocalizations.of(context)!.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
