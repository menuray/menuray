import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai/presentation/ai_optimize_screen.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/capture/presentation/camera_screen.dart';
import '../features/capture/presentation/correct_image_screen.dart';
import '../features/capture/presentation/processing_screen.dart';
import '../features/capture/presentation/select_photos_screen.dart';
import '../features/edit/presentation/edit_dish_screen.dart';
import '../features/edit/presentation/organize_menu_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/manage/presentation/menu_management_screen.dart';
import '../features/manage/presentation/statistics_screen.dart';
import '../features/publish/presentation/custom_theme_screen.dart';
import '../features/publish/presentation/preview_menu_screen.dart';
import '../features/publish/presentation/published_screen.dart';
import '../features/publish/presentation/select_template_screen.dart';
import '../features/store/presentation/settings_screen.dart';
import '../features/store/presentation/store_management_screen.dart';

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
  static String menuManageFor(String id) => '/manage/menu/$id';
  static const statistics = '/manage/statistics';
  static const storeManage = '/store/list';
  static const settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshStream = ref.watch(authRepositoryProvider).authStateChanges();
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: GoRouterRefreshStream(refreshStream),
    redirect: (context, state) {
      final session = ref.read(currentSessionProvider);
      final atLogin = state.matchedLocation == AppRoutes.login;
      if (session == null) return atLogin ? null : AppRoutes.login;
      if (atLogin) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginScreen()),
      GoRoute(path: AppRoutes.home, builder: (c, s) => const HomeScreen()),
      GoRoute(path: AppRoutes.camera, builder: (c, s) => const CameraScreen()),
      GoRoute(path: AppRoutes.selectPhotos, builder: (c, s) => const SelectPhotosScreen()),
      GoRoute(path: AppRoutes.correctImage, builder: (c, s) => const CorrectImageScreen()),
      GoRoute(path: AppRoutes.processing, builder: (c, s) => const ProcessingScreen()),
      GoRoute(path: AppRoutes.organize, builder: (c, s) => const OrganizeMenuScreen()),
      GoRoute(path: AppRoutes.editDish, builder: (c, s) => const EditDishScreen()),
      GoRoute(path: AppRoutes.aiOptimize, builder: (c, s) => const AiOptimizeScreen()),
      GoRoute(path: AppRoutes.selectTemplate, builder: (c, s) => const SelectTemplateScreen()),
      GoRoute(path: AppRoutes.customTheme, builder: (c, s) => const CustomThemeScreen()),
      GoRoute(path: AppRoutes.preview, builder: (c, s) => const PreviewMenuScreen()),
      GoRoute(path: AppRoutes.published, builder: (c, s) => const PublishedScreen()),
      GoRoute(
        path: '${AppRoutes.menuManage}/:id',
        builder: (c, s) =>
            MenuManagementScreen(menuId: s.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.statistics, builder: (c, s) => const StatisticsScreen()),
      GoRoute(path: AppRoutes.storeManage, builder: (c, s) => const StoreManagementScreen()),
      GoRoute(path: AppRoutes.settings, builder: (c, s) => const SettingsScreen()),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
          onError: (_) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
