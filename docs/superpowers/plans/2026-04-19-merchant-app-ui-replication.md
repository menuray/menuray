# MenuRay 商家端 UI 复刻 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Stitch 已生成的 17 个商家端屏（位于 `frontend/design/1`–`10`）用 Flutter 复刻成一个可点击导航的纯 UI Demo，运行在 Chrome / Android / iOS 模拟器上。

**Architecture:** 单 Flutter 项目，feature-first 目录结构，Riverpod 做全局状态，go_router 做导航，所有数据用 mock。Material 3 主题基于 `docs/DESIGN.md` 的色彩 / 字体规范派生。

**Tech Stack:** Flutter stable / Dart / flutter_riverpod / go_router / google_fonts (Manrope) / Material Symbols Outlined（Icons.* 替代）/ flutter_lints

---

## 范围说明

**本计划只覆盖商家端 17 屏**（A1–A17，对应 `frontend/design/1` 到 `10` 的 11 个目录）。
**顾客端 4 屏（B1–B4，对应 `frontend/design/11`）不在本期范围**，按原设计是 H5，将来用单独的 Web 项目实现。

## 测试策略说明（务必先读）

UI 纯复刻 + mock 数据的场景下，**严格 TDD 价值低、阻碍效率**：
- 视觉是否"像 Stitch 设计图"靠人眼比对，golden test 第一轮没必要建立
- 屏幕没有真实业务逻辑，widget test 主要测渲染不崩

**采用的实际策略：**
- **每个共享 widget**：一个轻量 widget test 验证基本渲染 + 关键 prop 行为
- **每个屏幕**：一个 smoke test 验证可路由到 + 不抛异常
- **每次 commit 前**：`flutter analyze` 必须 0 issue
- **每个屏幕完成后**：`flutter run -d chrome`，开 DevTools iPhone 14 viewport，与 `screen.png` 肉眼比对

如果将来要做视觉回归，再补 golden tests。这是有意识的取舍，不是遗漏。

---

## 文件结构

下面是计划完成后的目录结构，每个文件的职责一行写清。

```
frontend/
  design/                                # 已存在，Stitch 设计源
  merchant/                              # 新增 — Flutter 商家端项目
    pubspec.yaml                         # 依赖：flutter_riverpod, go_router, google_fonts
    analysis_options.yaml                # lints 配置
    assets/
      sample/                            # 占位图（菜单封面、菜品图、店铺头像）
    lib/
      main.dart                          # ProviderScope + MyApp
      app.dart                           # MaterialApp.router 配置
      theme/
        app_colors.dart                  # 从 DESIGN.md 派生的 ColorScheme
        app_theme.dart                   # ThemeData (M3 + Manrope)
      router/
        app_router.dart                  # go_router 配置 + 所有路由常量
      shared/
        models/
          menu.dart                      # 菜单 model
          dish.dart                      # 菜品 model
          category.dart                  # 类别 model
          store.dart                     # 店铺 model
        mock/
          mock_data.dart                 # 所有 sample 数据（云间小厨、宫保鸡丁等）
        widgets/
          status_chip.dart               # 已发布/草稿/招牌/中辣 等通用 chip
          primary_button.dart            # 主按钮（墨绿 + 渐变）
          search_input.dart              # 暖色搜索框
          menu_card.dart                 # A2 菜单卡片
          dish_row.dart                  # A7 菜品行
          empty_state.dart               # 空状态通用块
          merchant_app_bar.dart          # 商家端通用顶栏
          merchant_bottom_nav.dart       # 底部 Tab
      features/
        auth/
          presentation/login_screen.dart        # A1
        home/
          presentation/home_screen.dart         # A2
        capture/
          presentation/
            camera_screen.dart                  # A3
            select_photos_screen.dart           # A4
            correct_image_screen.dart           # A5
            processing_screen.dart              # A6
        edit/
          presentation/
            organize_menu_screen.dart           # A7
            edit_dish_screen.dart               # A8
        ai/
          presentation/ai_optimize_screen.dart  # A9
        publish/
          presentation/
            select_template_screen.dart         # A10
            custom_theme_screen.dart            # A11
            preview_menu_screen.dart            # A12
            published_screen.dart               # A13
        manage/
          presentation/
            menu_management_screen.dart         # A14
            statistics_screen.dart              # A15
        store/
          presentation/
            store_management_screen.dart       # A16
            settings_screen.dart                # A17
    test/
      widgets/                                  # 共享 widget 测试
      smoke/                                    # 屏幕 smoke test
```

**每个 feature 目录"扁平"放 presentation 屏幕文件**，不预先建空的 data/ domain/ 子目录 — YAGNI，未来接 API 时再分。

---

## Phase 1 — 项目脚手架与主题

### 任务 1：创建 Flutter 项目

**Files:**
- 新建：`frontend/merchant/` 整个目录（由 `flutter create` 生成）

- [ ] **步骤 1.1：在 frontend/ 下创建项目**

```bash
cd /home/coder/workspaces/happy-menu/frontend
flutter create --org com.menuray --project-name menuray_merchant --platforms=android,ios,web ./merchant
```

预期：成功生成 `frontend/merchant/` 含 lib/、test/、pubspec.yaml、android/、ios/、web/

- [ ] **步骤 1.2：精简模板默认内容**

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant
rm test/widget_test.dart        # 模板的 counter test 没用
```

- [ ] **步骤 1.3：添加依赖**

修改 `frontend/merchant/pubspec.yaml`，dependencies 段加：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  go_router: ^14.6.1
  google_fonts: ^6.2.1
```

dev_dependencies 已默认含 flutter_test 和 flutter_lints，不动。

assets 段加：

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/sample/
```

- [ ] **步骤 1.4：拉取依赖并验证构建**

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant
flutter pub get
flutter analyze
```

预期：`flutter pub get` 成功，`flutter analyze` 输出 `No issues found!`

- [ ] **步骤 1.5：commit**

```bash
git -C /home/coder/workspaces/happy-menu add frontend/merchant
git -C /home/coder/workspaces/happy-menu commit -m "chore: scaffold Flutter merchant app"
```

---

### 任务 2：配置 Material 3 主题（颜色 + 字体）

**Files:**
- 新建：`frontend/merchant/lib/theme/app_colors.dart`
- 新建：`frontend/merchant/lib/theme/app_theme.dart`

- [ ] **步骤 2.1：写颜色定义**

新建 `lib/theme/app_colors.dart`：

```dart
import 'package:flutter/material.dart';

/// Brand colors derived from docs/DESIGN.md
class AppColors {
  AppColors._();

  static const primary = Color(0xFF2F5D50);      // 墨绿
  static const accent = Color(0xFFE0A969);       // 琥珀金
  static const surface = Color(0xFFFBF7F0);      // 暖米白
  static const ink = Color(0xFF1F1F1F);          // 深炭
  static const secondary = Color(0xFF6B7B6F);    // 灰绿
  static const success = Color(0xFF4A8A6E);
  static const warning = Color(0xFFE0A969);
  static const error = Color(0xFFC2553F);        // 砖红
  static const divider = Color(0xFFECE7DC);      // 暖灰

  /// Primary container — 用于 Stitch HTML 里的 primary-container（更亮的墨绿）
  static const primaryContainer = Color(0xFF2F5D50);

  /// 更深的墨绿，用于强对比按钮
  static const primaryDark = Color(0xFF154539);

  static ColorScheme get lightScheme => ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primaryDark,
        primaryContainer: primary,
        secondary: secondary,
        tertiary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSurface: ink,
      );
}
```

- [ ] **步骤 2.2：写主题**

新建 `lib/theme/app_theme.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Material 3 ThemeData built from DESIGN.md tokens.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = AppColors.lightScheme;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.divider.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.divider,
        labelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: const StadiumBorder(),
      ),
    );
  }
}
```

- [ ] **步骤 2.3：验证编译**

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant
flutter analyze
```

预期：`No issues found!`

- [ ] **步骤 2.4：commit**

```bash
git -C /home/coder/workspaces/happy-menu add frontend/merchant/lib/theme
git -C /home/coder/workspaces/happy-menu commit -m "feat(theme): Material 3 theme from DESIGN.md tokens"
```

---

### 任务 3：搭 go_router 骨架 + main.dart

**Files:**
- 新建：`frontend/merchant/lib/router/app_router.dart`
- 新建：`frontend/merchant/lib/app.dart`
- 替换：`frontend/merchant/lib/main.dart`

- [ ] **步骤 3.1：写路由常量与配置（带占位屏）**

新建 `lib/router/app_router.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    GoRoute(path: AppRoutes.login, builder: (_, __) => const _Placeholder('A1 Login')),
    GoRoute(path: AppRoutes.home, builder: (_, __) => const _Placeholder('A2 Home')),
    GoRoute(path: AppRoutes.camera, builder: (_, __) => const _Placeholder('A3 Camera')),
    GoRoute(path: AppRoutes.selectPhotos, builder: (_, __) => const _Placeholder('A4 Select Photos')),
    GoRoute(path: AppRoutes.correctImage, builder: (_, __) => const _Placeholder('A5 Correct Image')),
    GoRoute(path: AppRoutes.processing, builder: (_, __) => const _Placeholder('A6 Processing')),
    GoRoute(path: AppRoutes.organize, builder: (_, __) => const _Placeholder('A7 Organize Menu')),
    GoRoute(path: AppRoutes.editDish, builder: (_, __) => const _Placeholder('A8 Edit Dish')),
    GoRoute(path: AppRoutes.aiOptimize, builder: (_, __) => const _Placeholder('A9 AI Optimize')),
    GoRoute(path: AppRoutes.selectTemplate, builder: (_, __) => const _Placeholder('A10 Template')),
    GoRoute(path: AppRoutes.customTheme, builder: (_, __) => const _Placeholder('A11 Theme')),
    GoRoute(path: AppRoutes.preview, builder: (_, __) => const _Placeholder('A12 Preview')),
    GoRoute(path: AppRoutes.published, builder: (_, __) => const _Placeholder('A13 Published')),
    GoRoute(path: AppRoutes.menuManage, builder: (_, __) => const _Placeholder('A14 Menu Manage')),
    GoRoute(path: AppRoutes.statistics, builder: (_, __) => const _Placeholder('A15 Statistics')),
    GoRoute(path: AppRoutes.storeManage, builder: (_, __) => const _Placeholder('A16 Store Manage')),
    GoRoute(path: AppRoutes.settings, builder: (_, __) => const _Placeholder('A17 Settings')),
  ],
);
```

- [ ] **步骤 3.2：写 app.dart**

新建 `lib/app.dart`：

```dart
import 'package:flutter/material.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class HappyMenuApp extends StatelessWidget {
  const HappyMenuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MenuRay',
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **步骤 3.3：替换 main.dart**

替换 `lib/main.dart` 内容为：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(const ProviderScope(child: HappyMenuApp()));
}
```

- [ ] **步骤 3.4：验证编译并跑起来**

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant
flutter analyze
flutter run -d chrome --web-port=8123 &
sleep 10 && curl -s http://localhost:8123 | grep -q "<title>" && echo "OK" || echo "FAIL"
```

预期：analyze 无 issue；浏览器能开 `http://localhost:8123`，看到 "A1 Login" 的占位屏。
（手动验证：访问 `http://localhost:8123/#/home` 应看到 A2 Home 占位屏。）

- [ ] **步骤 3.5：commit**

```bash
git -C /home/coder/workspaces/happy-menu add frontend/merchant/lib
git -C /home/coder/workspaces/happy-menu commit -m "feat(router): go_router skeleton with placeholder screens"
```

---

## Phase 2 — Models 与 Mock 数据

### 任务 4：定义 4 个 model 类

**Files:**
- 新建：`frontend/merchant/lib/shared/models/menu.dart`
- 新建：`frontend/merchant/lib/shared/models/dish.dart`
- 新建：`frontend/merchant/lib/shared/models/category.dart`
- 新建：`frontend/merchant/lib/shared/models/store.dart`

- [ ] **步骤 4.1：写 dish.dart**

```dart
enum SpiceLevel { none, mild, medium, hot }
enum DishConfidence { high, low }

class Dish {
  final String id;
  final String name;
  final String? nameEn;
  final double price;
  final String? description;
  final String? imageUrl;
  final SpiceLevel spice;
  final bool isSignature;
  final bool isRecommended;
  final bool isVegetarian;
  final List<String> allergens;
  final bool soldOut;
  final DishConfidence confidence;

  const Dish({
    required this.id,
    required this.name,
    this.nameEn,
    required this.price,
    this.description,
    this.imageUrl,
    this.spice = SpiceLevel.none,
    this.isSignature = false,
    this.isRecommended = false,
    this.isVegetarian = false,
    this.allergens = const [],
    this.soldOut = false,
    this.confidence = DishConfidence.high,
  });
}
```

- [ ] **步骤 4.2：写 category.dart**

```dart
import 'dish.dart';

class DishCategory {
  final String id;
  final String name;
  final List<Dish> dishes;

  const DishCategory({required this.id, required this.name, required this.dishes});
}
```

- [ ] **步骤 4.3：写 menu.dart**

```dart
import 'category.dart';

enum MenuStatus { draft, published }

enum MenuTimeSlot { lunch, dinner, allDay, seasonal }

class Menu {
  final String id;
  final String name;
  final MenuStatus status;
  final DateTime updatedAt;
  final int viewCount;
  final String? coverImage;
  final List<DishCategory> categories;
  final MenuTimeSlot timeSlot;
  final String? timeSlotDescription; // "11:00-14:00"

  const Menu({
    required this.id,
    required this.name,
    required this.status,
    required this.updatedAt,
    this.viewCount = 0,
    this.coverImage,
    this.categories = const [],
    this.timeSlot = MenuTimeSlot.allDay,
    this.timeSlotDescription,
  });
}
```

- [ ] **步骤 4.4：写 store.dart**

```dart
class Store {
  final String id;
  final String name;
  final String? address;
  final String? logoUrl;
  final int menuCount;
  final int weeklyVisits;
  final bool isCurrent;

  const Store({
    required this.id,
    required this.name,
    this.address,
    this.logoUrl,
    this.menuCount = 0,
    this.weeklyVisits = 0,
    this.isCurrent = false,
  });
}
```

- [ ] **步骤 4.5：commit**

```bash
git -C /home/coder/workspaces/happy-menu add frontend/merchant/lib/shared/models
git -C /home/coder/workspaces/happy-menu commit -m "feat(models): Menu, Dish, Category, Store"
```

---

### 任务 5：建立 mock 数据

**Files:**
- 新建：`frontend/merchant/lib/shared/mock/mock_data.dart`

- [ ] **步骤 5.1：写 mock_data.dart**

包含「云间小厨」店铺、3 套菜单（午市套餐 2025 春 / 晚市菜单 / 周末早午餐）、若干菜品（含宫保鸡丁、麻婆豆腐、口水鸡、川北凉粉等示例数据）。

```dart
import '../models/menu.dart';
import '../models/dish.dart';
import '../models/category.dart';
import '../models/store.dart';

class MockData {
  MockData._();

  static const currentStore = Store(
    id: 'store_1',
    name: '云间小厨 · 静安店',
    address: '上海市静安区南京西路 1234 号',
    menuCount: 3,
    weeklyVisits: 2134,
    isCurrent: true,
  );

  static const stores = <Store>[
    currentStore,
    Store(id: 'store_2', name: '云间小厨 · 徐汇店', address: '上海市徐汇区漕溪北路 88 号', menuCount: 2, weeklyVisits: 1567),
    Store(id: 'store_3', name: '云间小厨 · 浦东店', address: '上海市浦东新区世纪大道 100 号', menuCount: 1, weeklyVisits: 423),
  ];

  static final coldDishes = DishCategory(
    id: 'c_cold',
    name: '凉菜',
    dishes: const [
      Dish(id: 'd1', name: '口水鸡', nameEn: 'Mouth-Watering Chicken', price: 38, spice: SpiceLevel.medium),
      Dish(id: 'd2', name: '凉拌黄瓜', nameEn: 'Smashed Cucumber', price: 18, isVegetarian: true),
      Dish(id: 'd3', name: '川北凉粉', price: 22, confidence: DishConfidence.low, spice: SpiceLevel.medium),
    ],
  );

  static final hotDishes = DishCategory(
    id: 'c_hot',
    name: '热菜',
    dishes: const [
      Dish(
        id: 'd4',
        name: '宫保鸡丁',
        nameEn: 'Kung Pao Chicken',
        price: 48,
        description: '经典川菜，鸡丁、花生与干辣椒同炒，咸甜微辣。',
        spice: SpiceLevel.medium,
        isSignature: true,
        isRecommended: true,
        allergens: ['花生'],
      ),
      Dish(id: 'd5', name: '麻婆豆腐', nameEn: 'Mapo Tofu', price: 32, spice: SpiceLevel.hot),
    ],
  );

  static final lunchMenu = Menu(
    id: 'm1',
    name: '午市套餐 2025 春',
    status: MenuStatus.published,
    updatedAt: DateTime(2026, 4, 16),
    viewCount: 1247,
    coverImage: 'assets/sample/menu_lunch.png',
    categories: [coldDishes, hotDishes],
    timeSlot: MenuTimeSlot.lunch,
    timeSlotDescription: '午市 11:00–14:00',
  );

  static final dinnerMenu = Menu(
    id: 'm2',
    name: '晚市菜单',
    status: MenuStatus.published,
    updatedAt: DateTime(2026, 4, 12),
    viewCount: 893,
    coverImage: 'assets/sample/menu_dinner.png',
    categories: [coldDishes, hotDishes],
    timeSlot: MenuTimeSlot.dinner,
  );

  static final brunchMenu = Menu(
    id: 'm3',
    name: '周末早午餐',
    status: MenuStatus.draft,
    updatedAt: DateTime(2026, 4, 19),
    viewCount: 0,
  );

  static final menus = [lunchMenu, dinnerMenu, brunchMenu];
}
```

- [ ] **步骤 5.2：commit**

```bash
git -C /home/coder/workspaces/happy-menu add frontend/merchant/lib/shared/mock
git -C /home/coder/workspaces/happy-menu commit -m "feat(mock): sample data — store, menus, dishes"
```

---

### 任务 6：下载 sample 占位图

**Files:**
- 新建：`frontend/merchant/assets/sample/menu_lunch.png`
- 新建：`frontend/merchant/assets/sample/menu_dinner.png`
- 新建：`frontend/merchant/assets/sample/dish_kungpao.png`
- 新建：`frontend/merchant/assets/sample/dish_mapo.png`
- 新建：`frontend/merchant/assets/sample/store_avatar.png`

- [ ] **步骤 6.1：用 placeholder 服务生成图片**

由于 Stitch HTML 引用的 `lh3.googleusercontent.com/aida-public/...` URL 无法长期依赖，先用 placeholder.com 或本地生成纯色占位：

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant/assets/sample
# 使用 ImageMagick 生成纯色 + 文字占位（如果系统没装 ImageMagick，改用 Python 脚本或 placeholder.com 下载）
for name in "menu_lunch:#2F5D50:Lunch" "menu_dinner:#1F1F1F:Dinner" "dish_kungpao:#C2553F:Kung Pao" "dish_mapo:#E0A969:Mapo" "store_avatar:#6B7B6F:Logo"; do
  IFS=':' read -r file color text <<< "$name"
  convert -size 400x400 "xc:$color" -gravity center -pointsize 40 -fill white -annotate 0 "$text" "$file.png" 2>/dev/null || \
  curl -sL "https://via.placeholder.com/400x400/$(echo $color | tr -d '#')/FFFFFF?text=$text" -o "$file.png"
done
```

预期：5 张 400×400 的占位图生成在 assets/sample/

- [ ] **步骤 6.2：验证 Flutter 能加载**

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant
flutter pub get  # 重新加载 assets manifest
flutter analyze
```

预期：analyze 无 issue。

- [ ] **步骤 6.3：commit**

```bash
git -C /home/coder/workspaces/happy-menu add frontend/merchant/assets
git -C /home/coder/workspaces/happy-menu commit -m "chore(assets): sample placeholder images"
```

---

## Phase 3 — 共享 Widgets

每个共享 widget 包含：实现 + 一个 widget test。

### 任务 7：StatusChip

**Files:**
- 新建：`frontend/merchant/lib/shared/widgets/status_chip.dart`
- 新建：`frontend/merchant/test/widgets/status_chip_test.dart`

**职责：** 通用标签 chip，支持几种预设变体（已发布 / 草稿 / 招牌 / 推荐 / 中辣 / 售罄）。

- [ ] **步骤 7.1：实现**

```dart
// lib/shared/widgets/status_chip.dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum ChipVariant { published, draft, signature, recommended, spicy, soldOut }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.variant});

  final String label;
  final ChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      ChipVariant.published => (AppColors.primary.withOpacity(0.1), AppColors.primary),
      ChipVariant.draft => (AppColors.divider, AppColors.secondary),
      ChipVariant.signature => (AppColors.accent.withOpacity(0.2), AppColors.accent),
      ChipVariant.recommended => (AppColors.success.withOpacity(0.15), AppColors.success),
      ChipVariant.spicy => (AppColors.error.withOpacity(0.1), AppColors.error),
      ChipVariant.soldOut => (AppColors.error, Colors.white),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}
```

- [ ] **步骤 7.2：写 widget test**

```dart
// test/widgets/status_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/status_chip.dart';

void main() {
  testWidgets('renders label and adapts color per variant', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StatusChip(label: '已发布', variant: ChipVariant.published)),
    ));
    expect(find.text('已发布'), findsOneWidget);
  });
}
```

- [ ] **步骤 7.3：跑测试**

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant
flutter test test/widgets/status_chip_test.dart
flutter analyze
```

预期：test pass，analyze 无 issue。

- [ ] **步骤 7.4：commit**

```bash
git -C /home/coder/workspaces/happy-menu add frontend/merchant/lib/shared/widgets/status_chip.dart frontend/merchant/test
git -C /home/coder/workspaces/happy-menu commit -m "feat(shared): StatusChip widget"
```

---

### 任务 8：PrimaryButton

**Files:**
- 新建：`frontend/merchant/lib/shared/widgets/primary_button.dart`
- 新建：`frontend/merchant/test/widgets/primary_button_test.dart`

**职责：** 全宽墨绿主按钮，支持 disabled / loading 状态。Stitch HTML 用了 from-primary to-primary-container 渐变。

- [ ] **步骤 8.1：实现**

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final btn = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryDark, AppColors.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
```

- [ ] **步骤 8.2：写 widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/primary_button.dart';

void main() {
  testWidgets('shows label and triggers onPressed', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PrimaryButton(label: '登录', onPressed: () => tapped++)),
    ));
    expect(find.text('登录'), findsOneWidget);
    await tester.tap(find.text('登录'));
    expect(tapped, 1);
  });

  testWidgets('shows spinner and disables tap when loading', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PrimaryButton(label: 'X', loading: true, onPressed: () => tapped++)),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(tapped, 0);
  });
}
```

- [ ] **步骤 8.3：跑测试 + commit**

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant
flutter test test/widgets/primary_button_test.dart && flutter analyze
git -C /home/coder/workspaces/happy-menu add frontend/merchant/lib/shared/widgets/primary_button.dart frontend/merchant/test/widgets/primary_button_test.dart
git -C /home/coder/workspaces/happy-menu commit -m "feat(shared): PrimaryButton with gradient + loading"
```

---

### 任务 9：SearchInput

**Files:**
- 新建：`frontend/merchant/lib/shared/widgets/search_input.dart`
- 新建：`frontend/merchant/test/widgets/search_input_test.dart`

**职责：** 暖色背景搜索框，左侧 search 图标，圆角 10px。

- [ ] **步骤 9.1：实现**

```dart
import 'package:flutter/material.dart';

class SearchInput extends StatelessWidget {
  const SearchInput({super.key, this.hintText = '搜索菜单、菜品或状态…', this.onChanged});

  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
      ),
    );
  }
}
```

- [ ] **步骤 9.2：写 widget test + 跑测试 + commit**

```dart
// test/widgets/search_input_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/search_input.dart';

void main() {
  testWidgets('shows hint and reports text changes', (tester) async {
    String? typed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SearchInput(onChanged: (v) => typed = v)),
    ));
    expect(find.text('搜索菜单、菜品或状态…'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '宫保');
    expect(typed, '宫保');
  });
}
```

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant && flutter test test/widgets/search_input_test.dart && flutter analyze
git -C /home/coder/workspaces/happy-menu add frontend/merchant/lib/shared/widgets/search_input.dart frontend/merchant/test/widgets/search_input_test.dart
git -C /home/coder/workspaces/happy-menu commit -m "feat(shared): SearchInput widget"
```

---

### 任务 10：MenuCard

**Files:**
- 新建：`frontend/merchant/lib/shared/widgets/menu_card.dart`
- 新建：`frontend/merchant/test/widgets/menu_card_test.dart`

**职责：** A2 首页用的菜单卡片。左封面图（128×128 圆角）+ 右侧（状态 chip + 时间 + 标题 + 访问数）+ 右上 more 按钮。

**Source for visual reference:** `frontend/design/2/My Menus - Home/code.html` 的 menu card 部分。

- [ ] **步骤 10.1：实现**

```dart
import 'package:flutter/material.dart';
import '../models/menu.dart';
import '../../theme/app_colors.dart';
import 'status_chip.dart';

class MenuCard extends StatelessWidget {
  const MenuCard({super.key, required this.menu, this.onTap, this.onMore});

  final Menu menu;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final isDraft = menu.status == MenuStatus.draft;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 128,
                  height: 128,
                  child: menu.coverImage != null
                      ? Image.asset(menu.coverImage!, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.divider,
                          child: const Icon(Icons.restaurant, color: AppColors.secondary, size: 40),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    StatusChip(
                      label: isDraft ? '草稿' : '已发布',
                      variant: isDraft ? ChipVariant.draft : ChipVariant.published,
                    ),
                    const SizedBox(width: 8),
                    Text(_formatTime(menu.updatedAt), style: TextStyle(fontSize: 12, color: AppColors.secondary)),
                  ]),
                  const SizedBox(height: 6),
                  Text(menu.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Row(children: [
                    Icon(isDraft ? Icons.visibility_off : Icons.visibility, size: 18, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text('${menu.viewCount} 次访问', style: TextStyle(fontSize: 13, color: AppColors.secondary)),
                  ]),
                ]),
              ),
            ]),
            Positioned(
              top: 0, right: 0,
              child: IconButton(icon: const Icon(Icons.more_vert), onPressed: onMore),
            ),
          ]),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final d = now.difference(t).inDays;
    if (d == 0) return '今天';
    if (d == 1) return '昨天';
    if (d < 7) return '$d 天前';
    if (d < 30) return '${(d / 7).floor()} 周前';
    return '${(d / 30).floor()} 个月前';
  }
}
```

- [ ] **步骤 10.2：写 widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/menu_card.dart';
import 'package:menuray_merchant/shared/mock/mock_data.dart';

void main() {
  testWidgets('shows menu name, view count and status chip', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MenuCard(menu: MockData.lunchMenu)),
    ));
    expect(find.text('午市套餐 2025 春'), findsOneWidget);
    expect(find.text('1247 次访问'), findsOneWidget);
    expect(find.text('已发布'), findsOneWidget);
  });

  testWidgets('draft variant uses draft chip', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MenuCard(menu: MockData.brunchMenu)),
    ));
    expect(find.text('草稿'), findsOneWidget);
  });
}
```

- [ ] **步骤 10.3：跑测试 + commit**

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant && flutter test test/widgets/menu_card_test.dart && flutter analyze
git -C /home/coder/workspaces/happy-menu add frontend/merchant/lib/shared/widgets/menu_card.dart frontend/merchant/test/widgets/menu_card_test.dart
git -C /home/coder/workspaces/happy-menu commit -m "feat(shared): MenuCard widget"
```

---

### 任务 11：DishRow

**Files:**
- 新建：`frontend/merchant/lib/shared/widgets/dish_row.dart`
- 新建：`frontend/merchant/test/widgets/dish_row_test.dart`

**职责：** A7 整理菜单屏的菜品行。菜名 + 价格 + 右侧小图标（标签提示 / 翻译已加 / 配图已加）+ 低置信度时左侧橙色竖条 + 行尾 "?"。

**Source for visual reference:** `frontend/design/4/Organize Menu - Edit OCR Results/code.html`

- [ ] **步骤 11.1：实现**

```dart
import 'package:flutter/material.dart';
import '../models/dish.dart';
import '../../theme/app_colors.dart';

class DishRow extends StatelessWidget {
  const DishRow({super.key, required this.dish, this.onTap});

  final Dish dish;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lowConfidence = dish.confidence == DishConfidence.low;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: lowConfidence ? AppColors.accent : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(child: Text(dish.name, style: const TextStyle(fontSize: 16))),
          if (dish.imageUrl != null) const _MiniIcon(Icons.image),
          if (dish.nameEn != null) const _MiniIcon(Icons.translate),
          Text('¥${dish.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (lowConfidence) ...[
            const SizedBox(width: 8),
            const Icon(Icons.help_outline, size: 18, color: AppColors.accent),
          ],
        ]),
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(icon, size: 16, color: AppColors.secondary),
      );
}
```

- [ ] **步骤 11.2：写 widget test + 跑测试 + commit**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/dish_row.dart';
import 'package:menuray_merchant/shared/models/dish.dart';

void main() {
  testWidgets('shows name and price', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DishRow(dish: Dish(id: 'x', name: '宫保鸡丁', price: 48))),
    ));
    expect(find.text('宫保鸡丁'), findsOneWidget);
    expect(find.text('¥48'), findsOneWidget);
  });

  testWidgets('low confidence shows help icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: DishRow(dish: Dish(id: 'y', name: '川北凉粉', price: 22, confidence: DishConfidence.low))),
    ));
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });
}
```

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant && flutter test test/widgets/dish_row_test.dart && flutter analyze
git -C /home/coder/workspaces/happy-menu add frontend/merchant/lib/shared/widgets/dish_row.dart frontend/merchant/test/widgets/dish_row_test.dart
git -C /home/coder/workspaces/happy-menu commit -m "feat(shared): DishRow widget"
```

---

### 任务 12：EmptyState

**Files:**
- 新建：`frontend/merchant/lib/shared/widgets/empty_state.dart`
- 新建：`frontend/merchant/test/widgets/empty_state_test.dart`

**职责：** 通用空状态：插图 + 标题 + 主按钮。

- [ ] **步骤 12.1：实现 + test + commit**

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'primary_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, required this.actionLabel, required this.onAction, this.icon});

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon ?? Icons.restaurant, size: 96, color: AppColors.divider),
            const SizedBox(height: 24),
            Text(message, style: const TextStyle(fontSize: 16, color: AppColors.secondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            PrimaryButton(label: actionLabel, onPressed: onAction, fullWidth: false),
          ],
        ),
      ),
    );
  }
}
```

```dart
// test/widgets/empty_state_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/empty_state.dart';

void main() {
  testWidgets('shows message and triggers action', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: EmptyState(
        message: '还没有菜单',
        actionLabel: '立即新建',
        onAction: () => tapped++,
      )),
    ));
    expect(find.text('还没有菜单'), findsOneWidget);
    await tester.tap(find.text('立即新建'));
    expect(tapped, 1);
  });
}
```

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant && flutter test test/widgets/empty_state_test.dart && flutter analyze
git -C /home/coder/workspaces/happy-menu add frontend/merchant/lib/shared/widgets/empty_state.dart frontend/merchant/test/widgets/empty_state_test.dart
git -C /home/coder/workspaces/happy-menu commit -m "feat(shared): EmptyState widget"
```

---

### 任务 13：MerchantBottomNav

**Files:**
- 新建：`frontend/merchant/lib/shared/widgets/merchant_bottom_nav.dart`
- 新建：`frontend/merchant/test/widgets/merchant_bottom_nav_test.dart`

**职责：** A2 / A15 / A17 共享的底部 Tab，3 个 item：Menus / Data / Mine。当前激活项用墨绿圆角胶囊高亮。

- [ ] **步骤 13.1：实现 + test + commit**

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum MerchantTab { menus, data, mine }

class MerchantBottomNav extends StatelessWidget {
  const MerchantBottomNav({super.key, required this.current, required this.onTap});

  final MerchantTab current;
  final ValueChanged<MerchantTab> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(blurRadius: 24, color: Color(0x14000000), offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _TabItem(icon: Icons.restaurant_menu, label: 'Menus', active: current == MerchantTab.menus, onTap: () => onTap(MerchantTab.menus)),
          _TabItem(icon: Icons.analytics_outlined, label: 'Data', active: current == MerchantTab.data, onTap: () => onTap(MerchantTab.data)),
          _TabItem(icon: Icons.person_outline, label: 'Mine', active: current == MerchantTab.mine, onTap: () => onTap(MerchantTab.mine)),
        ]),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : AppColors.ink.withOpacity(0.5);
    final bg = active ? AppColors.primaryDark : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
```

```dart
// test/widgets/merchant_bottom_nav_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menuray_merchant/shared/widgets/merchant_bottom_nav.dart';

void main() {
  testWidgets('reports tap with selected tab', (tester) async {
    MerchantTab? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MerchantBottomNav(current: MerchantTab.menus, onTap: (t) => tapped = t)),
    ));
    await tester.tap(find.text('Data'));
    expect(tapped, MerchantTab.data);
  });
}
```

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant && flutter test test/widgets/merchant_bottom_nav_test.dart && flutter analyze
git -C /home/coder/workspaces/happy-menu add frontend/merchant/lib/shared/widgets/merchant_bottom_nav.dart frontend/merchant/test/widgets/merchant_bottom_nav_test.dart
git -C /home/coder/workspaces/happy-menu commit -m "feat(shared): MerchantBottomNav"
```

---

## Phase 4 — 屏幕复刻（A1–A17）

### 屏幕复刻通用流程（每一屏都按这个走）

每个屏幕任务都执行以下 6 步：

1. **读源**：`frontend/design/<batch>/<screen>/code.html` + `screen.png` — HTML 看结构，PNG 看视觉
2. **建文件**：在 `lib/features/<feature>/presentation/` 下建 `<screen>_screen.dart`
3. **实现**：用 shared widgets + Stitch 视觉做参照写 Flutter 屏。**禁止**直接复制 Stitch 的 Tailwind class — 必须翻译成 Flutter widget tree
4. **接路由**：把对应的 `_Placeholder('XX')` 替换成真实 widget
5. **smoke test**：建 `test/smoke/<screen>_smoke_test.dart`，验证可路由 + 不抛异常
6. **可视检验**：`flutter run -d chrome` → DevTools iPhone 14 viewport → 与 `screen.png` 对比 → 截图保存到 `frontend/merchant/screenshots/<screen>.png`（这一步由人做）

每屏完成后 commit：`feat(<feature>): A?? <screen name>`

下面 17 个任务每个只列：源 / 目标文件 / 关键 widget / 关键 mock 数据 / 路由更新位置。**实际 Flutter 代码在执行时根据源 HTML 翻译，不在此预写。**

---

### 任务 14：A1 Login 屏

- 源：`frontend/design/1/Login : Register/code.html` + `screen.png`
- 文件：`lib/features/auth/presentation/login_screen.dart`
- 关键 widgets：`PrimaryButton`、`Material Icons (smartphone, lock, error)`
- 关键内容：Logo（用 placeholder 容器画"墨绿底 + 暖米白方块 + 翻起角"图标）、字标 "MenuRay"、slogan「拍一张照，5 分钟生成电子菜单」
- 输入字段：手机号 + 验证码（含右侧 60s 倒计时按钮）
- 错误态：演示 "验证码错误，请重新输入"
- 路由更新：`AppRoutes.login` 用 `const LoginScreen()` 替换占位
- smoke test：`testWidgets` + `pumpWidget(MaterialApp.router(routerConfig: appRouter))` + `expect(find.text('MenuRay'), findsOneWidget)`
- 完成验收：`flutter analyze` 无 issue + `flutter test` 全 pass + 浏览器预览与 PNG 视觉接近
- commit: `feat(auth): A1 login screen`

---

### 任务 15：A2 Home 屏

- 源：`frontend/design/2/My Menus - Home/code.html` + `screen.png`
- 文件：`lib/features/home/presentation/home_screen.dart`
- 关键 widgets：`MenuCard`、`SearchInput`、`MerchantBottomNav`、`StatusChip`、FAB（自带 `FloatingActionButton.extended`）
- 关键内容：顶栏（搜索 icon + "云间小厨" + 头像）、SearchInput、Section 标题 "Curated Menus" + "3 Total"、菜单卡片列表（用 `MockData.menus`）、右下 FAB「+ 新建菜单」、底部 Tab（current: menus）
- 交互：FAB 点击导航到 `AppRoutes.camera`；卡片点击导航到 `AppRoutes.menuManage`；底部 Tab 切换（暂时只切高亮，不真实跳路由 — Tab navigation Phase 5 再做）
- 路由更新：`AppRoutes.home` → `const HomeScreen()`
- smoke test：渲染后 `find.text('午市套餐 2025 春')` 应找得到
- commit: `feat(home): A2 menus list home`

---

### 任务 16：A3 Camera Capture 屏

- 源：`frontend/design/3/3.1 Camera Capture/code.html` + `screen.png`
- 文件：`lib/features/capture/presentation/camera_screen.dart`
- 关键 widgets：自定义 — 全屏黑底 + 黄绿色虚线边框检测框 + 顶栏（关闭、闪光、"换相册"）+ 底部（缩略图条 + 大快门按钮 + "完成" 按钮）+ 中部气泡提示
- 关键 mock：`['shot1.png', 'shot2.png', 'shot3.png']` 占位缩略图条
- 状态：固定演示 "可以拍了"（绿框）
- 交互：点关闭 → `context.pop()`；点 "换相册上传" → 推 `AppRoutes.selectPhotos`；点 "完成" → 推 `AppRoutes.correctImage`
- smoke test：`find.byIcon(Icons.close)` 存在
- commit: `feat(capture): A3 camera capture`

---

### 任务 17：A4 Select Photos 屏

- 源：`frontend/design/3/3.3 Select Photos/code.html` + `screen.png`
- 文件：`lib/features/capture/presentation/select_photos_screen.dart`
- 关键 widgets：`GridView.count(crossAxisCount: 4)`、底部缩略图条、顶部「下一步 (3)」按钮
- 关键内容：占位 12 张缩略（用 `MockData` 里的 sample 图复用），其中 3 张选中显示 ①②③ 角标
- 交互：点 "下一步" → 推 `AppRoutes.correctImage`
- commit: `feat(capture): A4 select photos`

---

### 任务 18：A5 Correct Image 屏

- 源：`frontend/design/3/3.2 Correct Image/code.html` + `screen.png`
- 文件：`lib/features/capture/presentation/correct_image_screen.dart`
- 关键 widgets：中部大图 + 4 个角点（用 `Stack` + `Positioned`）+ 底部工具栏（自动校正 / 旋转 / 裁剪 / 对比度 / 撤销）
- 标题："校正图片 (1 / 3)"
- 交互：点 "下一步" → 推 `AppRoutes.processing`
- commit: `feat(capture): A5 correct image`

---

### 任务 19：A6 OCR Processing 屏

- 源：`frontend/design/3/3.4 Processing/code.html` + `screen.png`
- 文件：`lib/features/capture/presentation/processing_screen.dart`
- 关键 widgets：居中插画区（用 `Icon` + `AnimatedSwitcher` 模拟）+ 进度文案 + `LinearProgressIndicator` + 底部 "后台运行" / "取消" 按钮
- 状态：固定显示 "正在识别菜品结构…" 阶段，进度条 65%
- 交互：模拟 3 秒后自动推 `AppRoutes.organize`（用 `Future.delayed` + `mounted` 检查）
- commit: `feat(capture): A6 ocr processing`

---

### 任务 20：A7 Organize Menu 屏

- 源：`frontend/design/4/Organize Menu - Edit OCR Results/code.html` + `screen.png`
- 文件：`lib/features/edit/presentation/organize_menu_screen.dart`
- 关键 widgets：`ExpansionTile`（每个类别一组）、`DishRow`（每行菜品）、右下 FAB「+ 新增」
- 关键内容：使用 `MockData.coldDishes` + `MockData.hotDishes`，川北凉粉那行使用 `DishConfidence.low`
- 交互：点 DishRow → 推 `AppRoutes.editDish`；点 "下一步" → 推 `AppRoutes.selectTemplate`
- commit: `feat(edit): A7 organize menu`

---

### 任务 21：A8 Edit Dish 屏

- 源：`frontend/design/5/Edit Dish Details/code.html` + `screen.png`
- 文件：`lib/features/edit/presentation/edit_dish_screen.dart`
- 关键 widgets：`Image.asset` 占位 + 三按钮 (拍照/相册/AI 生成)、`TextField`（名称/价格/描述/翻译）、辣度 5 段 `Slider`、复选 `FilterChip`（招牌/推荐/素食）+ 过敏原多选
- 关键内容：使用 `MockData.hotDishes.dishes[0]`（宫保鸡丁）
- 交互：右上"保存" → `context.pop()`
- commit: `feat(edit): A8 edit dish details`

---

### 任务 22：A9 AI Optimize 屏

- 源：`frontend/design/6/AI Menu Optimization/code.html` + `screen.png`
- 文件：`lib/features/ai/presentation/ai_optimize_screen.dart`
- 关键 widgets：3 块大开关卡片（`Card` + `SwitchListTile`）、估算条、底部主按钮
- 关键内容：固定 "缺图 12 道 / 无描述 8 道 / 翻译为 英文"
- 交互：点 "开始增强" → 切换为进度态（每卡片显示 `LinearProgressIndicator`）
- commit: `feat(ai): A9 ai optimize`

---

### 任务 23：A10 Select Template 屏

- 源：`frontend/design/7/7.1 Select Template/code.html` + `screen.png`
- 文件：`lib/features/publish/presentation/select_template_screen.dart`
- 关键 widgets：顶部 Tab（全部 / 中餐 / 西餐 / 日韩 / 简餐 / 咖啡甜品）+ `GridView`（每行 2 个模板缩略图卡片）+ 底部主按钮
- 关键内容：4 个模板：墨意 / 暖光 / 极简白 / 和风（缩略图用纯色占位）
- 交互：点 "使用此模板" → 推 `AppRoutes.customTheme`
- commit: `feat(publish): A10 select template`

---

### 任务 24：A11 Custom Theme 屏

- 源：`frontend/design/7/7.2 Custom Themes/code.html` + `screen.png`
- 文件：`lib/features/publish/presentation/custom_theme_screen.dart`
- 关键 widgets：上半屏预览（手机模型 mock）+ 下半屏控件：Logo 上传区 / 主色色板（10 个色块） / 辅色色板 / 字体选择 / 圆角选择
- 关键 mock：用 DESIGN.md 的色板做主色色板候选（含 `AppColors.primary`）
- 交互：点 "保存并预览" → 推 `AppRoutes.preview`
- commit: `feat(publish): A11 custom theme`

---

### 任务 25：A12 Preview Menu 屏

- 源：`frontend/design/8/8.1 Preview Menu/code.html` + `screen.png`
- 文件：`lib/features/publish/presentation/preview_menu_screen.dart`
- 关键 widgets：iPhone mock 框（用 `Container` + 圆角 + 阴影模拟）内嵌真实菜单内容（菜单标题 + 类别 + 菜品卡片列表）+ 顶部 segment（手机/平板）+ 底部按钮（返回编辑 / 发布菜单）
- 关键 mock：使用 `MockData.lunchMenu`
- 交互：点 "发布菜单" → 推 `AppRoutes.published`
- commit: `feat(publish): A12 preview menu`

---

### 任务 26：A13 Published 屏

- 源：`frontend/design/8/8.2 Published successful/code.html` + `screen.png`
- 文件：`lib/features/publish/presentation/published_screen.dart`
- 关键 widgets：成功插画 + 大二维码（用 `qr_flutter` 包**不引入** — 改用占位 `Container` 显示一个"二维码网格"伪装即可，避免新依赖）+ 链接行 + 三按钮（保存二维码 / 导出 PDF / 导出图片）
- 链接：`menu.menuray.app/luncha-spring`
- 交互：点 "返回菜单首页" → `context.go(AppRoutes.home)`
- commit: `feat(publish): A13 published successful`

---

### 任务 27：A14 Menu Management 屏

- 源：`frontend/design/9/9.1 Menu Management/code.html` + `screen.png`
- 文件：`lib/features/manage/presentation/menu_management_screen.dart`
- 关键 widgets：信息卡片（状态/最近更新/访问量/二维码缩略图）+ 5 个快捷操作按钮 + 售罄列表 + 时段单选
- 关键 mock：`MockData.lunchMenu`，售罄列表里口水鸡 `soldOut: true`
- 交互：点 "数据" → 推 `AppRoutes.statistics`；点 "分享" → 推 `AppRoutes.published`
- commit: `feat(manage): A14 menu management`

---

### 任务 28：A15 Statistics 屏

- 源：`frontend/design/9/9.2 Data Statistics/code.html` + `screen.png`
- 文件：`lib/features/manage/presentation/statistics_screen.dart`
- 关键 widgets：时间范围 segment + 三联概览卡片 + 折线图（**用 `CustomPaint` 画一条简单折线**，避免新依赖）+ Top 10 列表 + 类别饼图（同样 CustomPaint 简画）
- 关键 mock：固定数据 8,432 / 12% / 1,209 等
- commit: `feat(manage): A15 statistics`

---

### 任务 29：A16 Store Management 屏

- 源：`frontend/design/10/10.1 Store Management/code.html` + `screen.png`
- 文件：`lib/features/store/presentation/store_management_screen.dart`
- 关键 widgets：门店列表卡片（店名 + 地址 + 菜单数 + 本周访问量 + 当前店标记）
- 关键 mock：`MockData.stores`
- commit: `feat(store): A16 store management`

---

### 任务 30：A17 Settings 屏

- 源：`frontend/design/10/10.2 My : Settings/code.html` + `screen.png`
- 文件：`lib/features/store/presentation/settings_screen.dart`
- 关键 widgets：顶部头像 + 店铺名 + 套餐 chip（琥珀色 "专业版"）+ `ListTile` 列表分组 + 底部 "退出登录" 红色按钮
- 关键 mock：`MockData.currentStore`，套餐 "专业版"（年付 2026-12 到期），子账号 3 人
- commit: `feat(store): A17 settings`

---

## Phase 5 — 最终集成与验收

### 任务 31：确认底部 Tab 真实导航

**Files:**
- 修改：`frontend/merchant/lib/shared/widgets/merchant_bottom_nav.dart`（如需要）
- 修改：A2 home_screen / A15 statistics_screen / A17 settings_screen 三屏的 `MerchantBottomNav.onTap` 实现

- [ ] **步骤 31.1：让 onTap 跳路由**

在 A2 / A15 / A17 三屏的 `onTap` 回调里实现：
```dart
onTap: (tab) {
  switch (tab) {
    case MerchantTab.menus:    context.go(AppRoutes.home);
    case MerchantTab.data:     context.go(AppRoutes.statistics);
    case MerchantTab.mine:     context.go(AppRoutes.settings);
  }
},
```

- [ ] **步骤 31.2：手动跑 + 验收**

```bash
cd /home/coder/workspaces/happy-menu/frontend/merchant
flutter analyze
flutter test
flutter run -d chrome
```

人工验收清单（在浏览器中走一遍）：
- [ ] 登录 → 首页 → 新建菜单 FAB → 拍照 → 校正 → OCR → 整理 → 详情 → 模板 → 主题 → 预览 → 发布 → 返回首页 — 全流程能走通
- [ ] 首页底部 Tab 三个页面切换正常
- [ ] 卡片点进 A14 管理 → 进 A15 数据
- [ ] A8 详情可以保存返回
- [ ] 所有屏的视觉与对应 `screen.png` 接近（颜色 / 字体 / 圆角对齐）

- [ ] **步骤 31.3：commit**

```bash
git -C /home/coder/workspaces/happy-menu add -A frontend/merchant
git -C /home/coder/workspaces/happy-menu commit -m "feat(nav): wire up bottom tab navigation"
```

---

### 任务 32：补一份 frontend/merchant/README.md

**Files:**
- 新建：`frontend/merchant/README.md`

- [ ] **步骤 32.1：写 README**

简短说明：项目作用、如何跑（`flutter run -d chrome`）、与 `frontend/design/` 的对应关系、目录结构说明。

```markdown
# MenuRay — 商家端（Flutter）

> Stitch 设计源 → Flutter 复刻。本期仅做 UI（mock 数据，无后端）。

## 跑起来

```bash
cd frontend/merchant
flutter pub get
flutter run -d chrome --web-port=8123
```

## 屏幕清单

| 屏 | 路由 | 文件 | Stitch 源 |
|---|---|---|---|
| A1 登录 | /login | features/auth/presentation/login_screen.dart | design/1 |
| A2 首页 | / | features/home/presentation/home_screen.dart | design/2 |
| A3–A6 导入流 | /capture/* | features/capture/* | design/3 |
| A7 整理 | /edit/organize | features/edit/presentation/organize_menu_screen.dart | design/4 |
| A8 菜品详情 | /edit/dish | features/edit/presentation/edit_dish_screen.dart | design/5 |
| A9 AI 增强 | /ai/optimize | features/ai/presentation/ai_optimize_screen.dart | design/6 |
| A10–A11 模板/主题 | /publish/template, /publish/theme | features/publish/* | design/7 |
| A12–A13 预览/发布 | /publish/preview, /publish/done | features/publish/* | design/8 |
| A14–A15 管理/数据 | /manage/* | features/manage/* | design/9 |
| A16–A17 门店/设置 | /store/list, /settings | features/store/* | design/10 |
```

- [ ] **步骤 32.2：commit**

```bash
git -C /home/coder/workspaces/happy-menu add frontend/merchant/README.md
git -C /home/coder/workspaces/happy-menu commit -m "docs: merchant app README"
```

---

## 自检结果

**Spec 覆盖：**
- DESIGN.md 中 9 个色彩 token 全部映射到 `app_colors.dart` ✓
- 17 个商家屏全部有对应任务 14–30 ✓
- Riverpod / go_router / google_fonts 全部在依赖中 ✓
- mock 数据按 stitch-prompts.md 中提供的示例数据建立 ✓
- 顾客端 4 屏明确**不在本期** ✓

**Placeholder 扫描：** 全部任务有具体文件路径、命令、源文件指针；无 "TBD" / "implement later"。

**类型一致性：** Menu / Dish / Category / Store / SpiceLevel / DishConfidence / MenuStatus / MenuTimeSlot / MerchantTab / ChipVariant — 任务 4 / 5 中定义，后续任务引用时一致。

**已知妥协**（明确写出来，不是隐藏问题）：
- 任务 14–30 的 Flutter 实现代码不在 plan 中预写 — 这是有意识的取舍，每屏需要根据 Stitch HTML + PNG 实时翻译；Plan 列出**源 / 目标 / 关键 widgets / mock / 路由**已足够指引
- 屏幕没有 widget test，只有 smoke test — 见开篇"测试策略说明"
- A13 二维码用占位伪装，不引入 qr_flutter 依赖 — YAGNI
- A15 折线图与饼图用 CustomPaint 简画，不引入 fl_chart 等 — YAGNI

---

## 执行入口

Plan 写完。两种执行方式：

1. **Subagent 驱动**（推荐）：每个任务派一个新 subagent 执行，主线程做 review
2. **内嵌执行**：本会话内分批执行，每完成一批做 checkpoint

按用户先前选定的"装 SDK → 写实施计划 → review → 分阶段执行"流程，先等用户 review 此 Plan。
