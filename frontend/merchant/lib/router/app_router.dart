import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show XFile;

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
import '../features/templates/presentation/select_template_screen.dart';
import '../features/store/active_store_provider.dart';
import '../features/store/membership_providers.dart';
import '../features/store/presentation/settings_screen.dart';
import '../features/store/presentation/store_management_screen.dart';
import '../features/store/presentation/store_picker_screen.dart';
import '../features/store/presentation/team_management_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const login = '/login';
  static const home = '/';
  static const camera = '/capture/camera';
  static const selectPhotos = '/capture/select';
  static const correctImage = '/capture/correct';
  static const processing = '/capture/processing';
  static const organize = '/edit/organize';
  static String organizeFor(String menuId) => '/edit/organize/$menuId';
  static const editDish = '/edit/dish';
  static String editDishFor(String dishId) => '/edit/dish/$dishId';
  static const aiOptimize = '/ai/optimize';
  static const selectTemplate = '/publish/template';
  static String selectTemplateFor(String menuId) => '$selectTemplate/$menuId';
  static const customTheme = '/publish/theme';
  static const preview = '/publish/preview';
  static String previewFor(String menuId) => '/publish/preview/$menuId';
  static const published = '/publish/done';
  static String publishedFor(String menuId) => '/publish/done/$menuId';
  static const menuManage = '/manage/menu';
  static String menuManageFor(String id) => '/manage/menu/$id';
  static const statistics = '/manage/statistics';
  static const storeManage = '/store/list';
  static const settings = '/settings';
  static const storePicker = '/store-picker';
  static const teamManage = '/store/:storeId/team';
  static String teamManageFor(String storeId) => '/store/$storeId/team';
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

      final memberships = ref.read(membershipsProvider).valueOrNull;
      final active = ref.read(activeStoreProvider);
      if (memberships == null) return null; // still loading; re-evaluate on emission

      if (memberships.isEmpty) {
        // Stranded user: signed in but no memberships. Stay put; home screen
        // shows authNoMembershipsBanner via AsyncValue surfacing.
        return null;
      }

      // Auto-select if exactly one membership (so solo merchants skip picker).
      if (active == null && memberships.length == 1) {
        Future.microtask(() => ref
            .read(activeStoreProvider.notifier)
            .autoPickIfSingle(memberships));
        return null;
      }

      if (active == null &&
          memberships.length >= 2 &&
          state.matchedLocation != AppRoutes.storePicker) {
        return AppRoutes.storePicker;
      }

      if (active != null && state.matchedLocation == AppRoutes.storePicker) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginScreen()),
      GoRoute(path: AppRoutes.home, builder: (c, s) => const HomeScreen()),
      GoRoute(path: AppRoutes.camera, builder: (c, s) => const CameraScreen()),
      GoRoute(path: AppRoutes.selectPhotos, builder: (c, s) => const SelectPhotosScreen()),
      GoRoute(
        path: AppRoutes.correctImage,
        builder: (c, s) => CorrectImageScreen(
          photos: (s.extra as List?)?.cast<XFile>() ?? const [],
        ),
      ),
      GoRoute(
        path: AppRoutes.processing,
        builder: (c, s) => ProcessingScreen(
          photos: (s.extra as List?)?.cast<XFile>() ?? const [],
        ),
      ),
      GoRoute(
        path: '${AppRoutes.organize}/:menuId',
        builder: (c, s) => OrganizeMenuScreen(menuId: s.pathParameters['menuId']!),
      ),
      GoRoute(
        path: '${AppRoutes.editDish}/:dishId',
        builder: (c, s) => EditDishScreen(dishId: s.pathParameters['dishId']!),
      ),
      GoRoute(path: AppRoutes.aiOptimize, builder: (c, s) => const AiOptimizeScreen()),
      GoRoute(
        path: '${AppRoutes.selectTemplate}/:menuId',
        builder: (c, s) =>
            SelectTemplateScreen(menuId: s.pathParameters['menuId']!),
      ),
      GoRoute(path: AppRoutes.customTheme, builder: (c, s) => const CustomThemeScreen()),
      GoRoute(
        path: '${AppRoutes.preview}/:menuId',
        builder: (c, s) => PreviewMenuScreen(menuId: s.pathParameters['menuId']!),
      ),
      GoRoute(
        path: '${AppRoutes.published}/:menuId',
        builder: (c, s) => PublishedScreen(menuId: s.pathParameters['menuId']!),
      ),
      GoRoute(
        path: '${AppRoutes.menuManage}/:id',
        builder: (c, s) =>
            MenuManagementScreen(menuId: s.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.statistics, builder: (c, s) => const StatisticsScreen()),
      GoRoute(path: AppRoutes.storeManage, builder: (c, s) => const StoreManagementScreen()),
      GoRoute(path: AppRoutes.settings, builder: (c, s) => const SettingsScreen()),
      GoRoute(path: AppRoutes.storePicker, builder: (c, s) => const StorePickerScreen()),
      GoRoute(
        path: AppRoutes.teamManage,
        builder: (c, s) => TeamManagementScreen(storeId: s.pathParameters['storeId']!),
      ),
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
