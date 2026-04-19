# MenuRay

> **拍一张纸质菜单照片 — 几分钟内得到一份可分享的电子菜单。**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B.svg?logo=flutter)](https://flutter.dev)
[![English](https://img.shields.io/badge/lang-English-blue.svg)](README.md)

MenuRay 是一个开源的、AI 辅助的工具，让餐厅通过拍一张照片就能把纸质菜单变成精美的电子菜单。顾客扫描二维码就能在自己的语言下查看、搜索和翻译菜单 — 无需安装任何 App。

面向**全球中小餐饮市场**，原生支持多语言菜单与自部署。

---

## 项目状态

🚧 **正在开发中**。从第一行代码起就是开源。

| 模块 | 状态 |
|---|---|
| 品牌与视觉设计 | ✅ 完成 — 见 [`docs/DESIGN.md`](docs/DESIGN.md) |
| Stitch UI 设计稿（21 屏） | ✅ 完成 — 见 [`frontend/design/`](frontend/design/) |
| 商家移动端（Flutter，17 屏） | ✅ UI 完成（mock 数据） |
| 顾客扫码查看 H5（4 屏） | 🔄 待实现 |
| 后端（Supabase） | 🔄 规划中 |
| Logo（最终成品） | 🔄 提示词已就绪，待生成 |
| App Store / Play Store 上架 | 🔄 远期 |

详细待办见 [`docs/roadmap.md`](docs/roadmap.md)。

---

## 快速开始

### 跑商家端 App

**前置条件：** [Flutter SDK](https://flutter.dev/docs/get-started/install)（stable 通道）。

```bash
git clone git@github.com:menuray/menuray.git
cd menuray/frontend/merchant
flutter pub get

# 选一个目标平台：
flutter run -d chrome      # 浏览器（最简单）
flutter run -d ios         # iOS 模拟器（需要 macOS）
flutter run -d android     # Android 模拟器
flutter run -d linux       # Linux 桌面窗口
```

如果是无浏览器的 Linux 服务器（通过隧道访问），用**静态构建**模式：

```bash
flutter build web --release
cd build/web && python3 -m http.server 8080 --bind 0.0.0.0
```

完整的环境配置和故障排查见 [`docs/development.md`](docs/development.md)。

---

## 工作原理

```
┌────────────┐   ┌──────────┐   ┌────────────┐   ┌──────────┐
│  商家拍下  │──▶│   OCR    │──▶│  LLM       │──▶│ 数据库   │
│  纸质菜单  │   │  (Vision │   │  解析器    │   │ (Postgres│
│  照片      │   │   API)   │   │ (Claude /  │   │  via     │
│            │   │          │   │  GPT)      │   │ Supabase)│
└────────────┘   └──────────┘   └────────────┘   └─────┬────┘
                                                       │
       ┌───────────────────────────────────────────────┘
       ▼
┌────────────┐   ┌──────────┐   ┌────────────┐
│ 自动生成   │──▶│  公开链接│──▶│  顾客扫码  │
│  菜单页面  │   │  + 二维码│   │  打开网页  │
└────────────┘   └──────────┘   └────────────┘
```

完整的数据流图与组件边界见 [`docs/architecture.md`](docs/architecture.md)。

---

## 技术栈

| 层 | 选型 | 原因 |
|---|---|---|
| 商家端 App | **Flutter** + Material 3 + Riverpod + go_router | 跨平台、原生体验、单代码库 |
| 顾客端 | **SvelteKit**（计划） | 首屏极小、扫码即开、SEO 友好 |
| 后端 | **Supabase**（Postgres + Auth + Storage + Edge Functions） | 开源 BaaS、RLS 多租户、可自部署 |
| OCR | Google Vision（计划） | 多语言覆盖最好 |
| LLM（解析与增强） | Anthropic Claude / OpenAI（可替换） | 服务商抽象 |
| i18n | `flutter_localizations` + `.arb`（计划） | Flutter 标准方案 |

完整理由见 [`docs/decisions.md`](docs/decisions.md)。

---

## 仓库结构

```
menuray/
├── docs/                          # 所有文档（从这里开始）
│   ├── DESIGN.md                  # 品牌色、字体、设计 token
│   ├── architecture.md            # 系统架构与数据流
│   ├── decisions.md               # 架构决策记录（ADR）
│   ├── development.md             # 开发环境配置
│   ├── i18n.md                    # 国际化策略
│   ├── roadmap.md                 # 优先级待办（P0 → P3）
│   ├── stitch-prompts.md          # Stitch UI 生成提示词
│   ├── logo-prompts.md            # Logo 生成提示词
│   └── superpowers/plans/         # 详细实施计划
├── frontend/
│   ├── design/                    # Stitch 生成的 UI 设计稿（HTML + PNG）
│   └── merchant/                  # Flutter 商家端
├── .github/                       # Issue & PR 模板，CI 工作流
├── CLAUDE.md                      # 给 AI 编程 agent 的约定
├── CONTRIBUTING.md                # 如何贡献
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── LICENSE                        # MIT
└── README.md                      # 英文版
```

---

## 贡献

欢迎所有形式的贡献 — 代码、文档、设计、翻译、bug 上报。

- **发现 bug？** 用 bug 模板开 issue。
- **想提议新功能？** 先在 Discussions 对齐，再写代码。
- **加新语言？** 见 [`docs/i18n.md`](docs/i18n.md)。
- **改进商家端？** 看 open issues + [`docs/roadmap.md`](docs/roadmap.md) 优先级。

提 PR 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

参与即表示你同意遵守 [行为准则](CODE_OF_CONDUCT.md)。

---

## 安全

发现漏洞？**请勿**在公开 issue 中讨论。负责任披露见 [SECURITY.md](SECURITY.md)。

---

## 致谢

- UI 设计由 [Google Stitch](https://stitch.withgoogle.com/) 生成
- 基于 [Flutter](https://flutter.dev/) 和 [Supabase](https://supabase.com/) 构建
- 灵感来自所有还在用记号笔改菜单价格的餐厅老板

---

## 许可证

[MIT](LICENSE) — 想干嘛干嘛，保留版权声明就行。
