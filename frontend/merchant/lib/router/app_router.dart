import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/capture/presentation/camera_screen.dart';
import '../features/capture/presentation/correct_image_screen.dart';
import '../features/capture/presentation/processing_screen.dart';
import '../features/capture/presentation/select_photos_screen.dart';
import '../features/edit/presentation/edit_dish_screen.dart';
import '../features/edit/presentation/organize_menu_screen.dart';
import '../features/home/presentation/home_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const login = '/login';
  static const home = '/';
  static const camera = '/capture/camera';
  static const selectPhotos = '/capture/select';
  static const correctImage = '/capture/correct';
  static const processing = '/capture/processing';
  static const organize = '/edit/organize';
  static const editDish = '/edit/dish';
  static const aiOptimize = '/ai/optimize';
  static const selectTemplate = '/publish/template';
  static const customTheme = '/publish/theme';
  static const preview = '/publish/preview';
  static const published = '/publish/done';
  static const menuManage = '/manage/menu';
  static const statistics = '/manage/statistics';
  static const storeManage = '/store/list';
  static const settings = '/settings';
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text('TODO: $title')),
      );
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  routes: [
    GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
    GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
    GoRoute(path: AppRoutes.camera, builder: (context, state) => const CameraScreen()),
    GoRoute(path: AppRoutes.selectPhotos, builder: (context, state) => const SelectPhotosScreen()),
    GoRoute(path: AppRoutes.correctImage, builder: (context, state) => const CorrectImageScreen()),
    GoRoute(path: AppRoutes.processing, builder: (context, state) => const ProcessingScreen()),
    GoRoute(path: AppRoutes.organize, builder: (context, state) => const OrganizeMenuScreen()),
    GoRoute(path: AppRoutes.editDish, builder: (context, state) => const EditDishScreen()),
    GoRoute(path: AppRoutes.aiOptimize, builder: (context, state) => const _Placeholder('A9 AI Optimize')),
    GoRoute(path: AppRoutes.selectTemplate, builder: (context, state) => const _Placeholder('A10 Template')),
    GoRoute(path: AppRoutes.customTheme, builder: (context, state) => const _Placeholder('A11 Theme')),
    GoRoute(path: AppRoutes.preview, builder: (context, state) => const _Placeholder('A12 Preview')),
    GoRoute(path: AppRoutes.published, builder: (context, state) => const _Placeholder('A13 Published')),
    GoRoute(path: AppRoutes.menuManage, builder: (context, state) => const _Placeholder('A14 Menu Manage')),
    GoRoute(path: AppRoutes.statistics, builder: (context, state) => const _Placeholder('A15 Statistics')),
    GoRoute(path: AppRoutes.storeManage, builder: (context, state) => const _Placeholder('A16 Store Manage')),
    GoRoute(path: AppRoutes.settings, builder: (context, state) => const _Placeholder('A17 Settings')),
  ],
);
