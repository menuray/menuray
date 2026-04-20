import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../home/home_providers.dart';
import '../capture_providers.dart';
import '../capture_repository.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key, this.photos = const []});

  final List<XFile> photos;

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

enum _LocalPhase { uploading, waiting, terminal }

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  _LocalPhase _phase = _LocalPhase.uploading;
  String? _runId;
  String? _error;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (widget.photos.isEmpty) {
      if (!mounted) return;
      setState(() {
        _phase = _LocalPhase.terminal;
        _error = '未选择照片';
      });
      return;
    }
    try {
      final repo = ref.read(captureRepositoryProvider);
      final store = await ref.read(currentStoreProvider.future);
      final runId = _uuidV4();
      final paths = <String>[];
      for (var i = 0; i < widget.photos.length; i++) {
        paths.add(await repo.uploadPhoto(
          file: widget.photos[i],
          storeId: store.id,
          runId: runId,
          index: i,
        ));
      }
      await repo.createParseRun(
        id: runId,
        storeId: store.id,
        paths: paths,
      );
      if (!mounted) return;
      setState(() {
        _runId = runId;
        _phase = _LocalPhase.waiting;
      });
      // Fire-and-forget; realtime is the source of truth.
      unawaited(repo.invokeParseMenu(runId: runId));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _LocalPhase.terminal;
        _error = '$e';
      });
    }
  }

  Future<void> _retry() async {
    final runId = _runId;
    if (runId == null) {
      // No run yet — restart from upload.
      setState(() {
        _phase = _LocalPhase.uploading;
        _error = null;
      });
      await _start();
      return;
    }
    setState(() {
      _phase = _LocalPhase.waiting;
      _error = null;
    });
    try {
      await ref.read(captureRepositoryProvider).invokeParseMenu(runId: runId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _LocalPhase.terminal;
        _error = '$e';
      });
    }
  }

  String _uuidV4() {
    // Minimal v4 generator — avoids adding the uuid package for one call-site.
    final r = Random.secure();
    String hex(int n) =>
        r.nextInt(1 << 32).toRadixString(16).padLeft(8, '0').substring(0, n);
    return '${hex(8)}-${hex(4)}-4${hex(3)}-'
        '${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-'
        '${hex(8)}${hex(4)}';
  }

  @override
  Widget build(BuildContext context) {
    // During "uploading" we can't watch the stream yet.
    if (_phase == _LocalPhase.uploading) {
      return _shell(child: const _Busy(label: '正在上传图片…'));
    }
    if (_phase == _LocalPhase.terminal && _runId == null) {
      return _shell(
        child: _Failed(message: _error ?? '未知错误', onRetry: _start),
      );
    }
    final runId = _runId!;
    final asyncSnap = ref.watch(parseRunStreamProvider(runId));
    return asyncSnap.when(
      loading: () => _shell(child: const _Busy(label: '等待服务器响应…')),
      error: (e, _) => _shell(child: _Failed(message: '$e', onRetry: _retry)),
      data: (snap) {
        if (snap.status == ParseRunStatus.succeeded &&
            snap.menuId != null &&
            !_navigated) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(AppRoutes.organizeFor(snap.menuId!));
          });
          return _shell(child: const _Busy(label: '跳转中…'));
        }
        if (snap.status == ParseRunStatus.failed) {
          return _shell(
            child: _Failed(
              message: snap.errorMessage ?? '解析失败',
              onRetry: _retry,
            ),
          );
        }
        final label = switch (snap.status) {
          ParseRunStatus.ocr => '识别中…',
          ParseRunStatus.structuring => '整理菜单…',
          _ => '排队中…',
        };
        return _shell(child: _Busy(label: label));
      },
    );
  }

  Widget _shell({required Widget child}) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryDark),
            onPressed: () => context.go(AppRoutes.home),
          ),
          title: const Text(
            '导入菜单',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(child: child),
      );
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(label),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: AppColors.error)),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('重试'),
        ),
      ],
    );
  }
}
