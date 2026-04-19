# Happy Menu — 商家端（Flutter）

> Stitch 设计源 → Flutter 复刻。本期仅做 UI（mock 数据，无后端）。

## 跑起来

```bash
cd frontend/merchant
flutter pub get
flutter run -d chrome --web-port=8123
```

或者：
```bash
flutter run -d linux       # Linux 桌面窗口
flutter run -d android     # Android 模拟器
flutter run -d ios         # iOS 模拟器（需 macOS）
```

## 架构

- **Flutter** stable + Material 3
- **flutter_riverpod** — 状态管理（已配置 ProviderScope，目前未使用，等接 API 时启用）
- **go_router** — 路由
- **google_fonts** — Manrope 字体
- 主题色板源自 `docs/DESIGN.md`

```
lib/
  main.dart                # ProviderScope + HappyMenuApp
  app.dart                 # MaterialApp.router 配置
  theme/                   # AppColors + AppTheme
  router/                  # go_router 配置 + AppRoutes 常量
  shared/
    models/                # Menu / Dish / Category / Store
    mock/                  # MockData (云间小厨等示例)
    widgets/               # StatusChip / PrimaryButton / SearchInput / MenuCard / DishRow / EmptyState / MerchantBottomNav
  features/
    auth/                  # A1 登录
    home/                  # A2 首页
    capture/               # A3-A6 拍照导入流
    edit/                  # A7-A8 整理 / 编辑
    ai/                    # A9 AI 增强
    publish/               # A10-A13 模板 / 主题 / 预览 / 发布
    manage/                # A14-A15 管理 / 数据
    store/                 # A16-A17 门店 / 设置
```

## 屏幕清单

| 屏 | 路由 | 文件 | Stitch 源 |
|---|---|---|---|
| A1 登录 | `/login` | `features/auth/presentation/login_screen.dart` | `frontend/design/1` |
| A2 首页 | `/` | `features/home/presentation/home_screen.dart` | `frontend/design/2` |
| A3 拍照 | `/capture/camera` | `features/capture/presentation/camera_screen.dart` | `frontend/design/3/3.1` |
| A4 上传 | `/capture/select` | `features/capture/presentation/select_photos_screen.dart` | `frontend/design/3/3.3` |
| A5 校正 | `/capture/correct` | `features/capture/presentation/correct_image_screen.dart` | `frontend/design/3/3.2` |
| A6 OCR | `/capture/processing` | `features/capture/presentation/processing_screen.dart` | `frontend/design/3/3.4` |
| A7 整理 | `/edit/organize` | `features/edit/presentation/organize_menu_screen.dart` | `frontend/design/4` |
| A8 菜品详情 | `/edit/dish` | `features/edit/presentation/edit_dish_screen.dart` | `frontend/design/5` |
| A9 AI 增强 | `/ai/optimize` | `features/ai/presentation/ai_optimize_screen.dart` | `frontend/design/6` |
| A10 模板 | `/publish/template` | `features/publish/presentation/select_template_screen.dart` | `frontend/design/7/7.1` |
| A11 主题 | `/publish/theme` | `features/publish/presentation/custom_theme_screen.dart` | `frontend/design/7/7.2` |
| A12 预览 | `/publish/preview` | `features/publish/presentation/preview_menu_screen.dart` | `frontend/design/8/8.1` |
| A13 发布 | `/publish/done` | `features/publish/presentation/published_screen.dart` | `frontend/design/8/8.2` |
| A14 管理 | `/manage/menu` | `features/manage/presentation/menu_management_screen.dart` | `frontend/design/9/9.1` |
| A15 数据 | `/manage/statistics` | `features/manage/presentation/statistics_screen.dart` | `frontend/design/9/9.2` |
| A16 门店 | `/store/list` | `features/store/presentation/store_management_screen.dart` | `frontend/design/10/10.1` |
| A17 设置 | `/settings` | `features/store/presentation/settings_screen.dart` | `frontend/design/10/10.2` |

## 测试

```bash
flutter test          # 跑所有测试
flutter analyze       # lint + 类型检查
```

- 共享 widgets 有 widget tests（10 个）
- 每屏有 1 个 smoke test 验证可路由 + 不抛异常

## 已知限制

- **纯 UI**：所有数据都是 mock，没有后端、没有持久化、没有真实 OCR
- **顾客端不在本期**：原计划 B1–B4（H5），用单独的 Web 项目实现（未启动）
- **图标**：Stitch HTML 用 Material Symbols Outlined，Flutter 用内置 `Icons.*` — 大部分能对上，少数有视觉差异
- **图片**：菜品/封面图都是占位色块，未来接图床

## 下一步

- 接后端 API（OCR / 菜单 CRUD / 数据统计）
- Riverpod providers 真正写起来
- i18n（中 / 英）
- 真机测试 + 微调
