import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';

class SelectPhotosScreen extends StatefulWidget {
  const SelectPhotosScreen({super.key});

  @override
  State<SelectPhotosScreen> createState() => _SelectPhotosScreenState();
}

class _SelectPhotosScreenState extends State<SelectPhotosScreen> {
  List<XFile> _picked = const [];
  bool _pickerOpened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pickerOpened) {
      _pickerOpened = true;
      // Fire-and-forget on a microtask so the first frame can paint before the
      // native picker takes over. addPostFrameCallback would block the test
      // harness on the awaited dialog.
      Future.microtask(_openPicker);
    }
  }

  Future<void> _openPicker() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (!mounted) return;
    if (picked.isEmpty) {
      // Nothing chosen — don't strand the user on an empty grid.
      context.go(AppRoutes.home);
    } else {
      setState(() => _picked = picked);
    }
  }

  void _next() {
    if (_picked.isEmpty) return;
    context.go(AppRoutes.correctImage, extra: _picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text(
            '取消',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        leadingWidth: 72,
        title: const Text(
          '选择菜单图片',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _picked.isEmpty ? null : _next,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: const StadiumBorder(),
            ),
            child: Text(
              '下一步 (${_picked.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _picked.isEmpty
          ? const Center(
              child: Text(
                '未选择照片',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: _picked.length,
              itemBuilder: (ctx, i) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: FutureBuilder<Uint8List>(
                  future: _picked[i].readAsBytes(),
                  builder: (c, s) => s.hasData
                      ? Image.memory(s.data!, fit: BoxFit.cover)
                      : const ColoredBox(color: Color(0xFFE6E2DB)),
                ),
              ),
            ),
    );
  }
}
