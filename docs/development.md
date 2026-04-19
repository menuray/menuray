# Development

> Local environment setup, common commands, and troubleshooting for working on MenuRay.

## Prerequisites

| Tool | Version | Why |
|---|---|---|
| **Flutter SDK** | stable channel (3.41+) | Merchant app |
| **Git** | 2.30+ | Source control |
| **Python 3** | 3.10+ | Local static-server fallback (web preview) |

Optional but useful:
- **Node.js** 20+ — for Supabase CLI & customer view (later)
- **Supabase CLI** — when backend work starts ([install](https://supabase.com/docs/guides/cli))
- **Android Studio** — Android emulator + better Flutter inspection
- **VS Code** with Flutter extension — recommended editor

## First-time setup

```bash
# Clone
git clone git@github.com:menuray/menuray.git
cd menuray

# Install Flutter SDK if you haven't
# https://flutter.dev/docs/get-started/install

# Verify Flutter
flutter doctor
```

`flutter doctor` should show ✓ for the platforms you intend to build for. Install missing dependencies it flags.

## Running the merchant app

```bash
cd frontend/merchant
flutter pub get
```

Then pick a target:

| Target | Command | Notes |
|---|---|---|
| iOS simulator | `flutter run -d ios` | macOS only |
| Android emulator | `flutter run -d android` | Need Android Studio + emulator running |
| Linux desktop | `flutter run -d linux` | Quick preview (not mobile UX) |
| Chrome (dev) | `flutter run -d chrome` | Best for headless servers via tunneling — but see below |
| Web (release static) | `flutter build web --release` + serve | Required for HTTPS-tunneled access (no WS) |

### Headless Linux + tunnel access

If you're developing on a Linux server with no browser and accessing via an HTTPS tunnel (e.g. `https://your-tunnel-host/`), the dev server's hot-reload uses `ws://` which is blocked by browsers as Mixed Content. Use the **release static build** instead:

```bash
cd frontend/merchant
flutter build web --release
cd build/web
python3 -m http.server 8123 --bind 0.0.0.0
```

Then access via your tunnel. No hot reload — rerun `flutter build web --release` after code changes.

## Tests

```bash
cd frontend/merchant

flutter test                           # all tests
flutter test test/widgets/             # only widget tests
flutter test test/smoke/               # only smoke tests
flutter test test/widgets/menu_card_test.dart   # one file
```

## Linting & type check

```bash
cd frontend/merchant
flutter analyze        # must be clean before commit
```

Lint config: [`frontend/merchant/analysis_options.yaml`](../frontend/merchant/analysis_options.yaml) (Flutter defaults).

## Pre-commit checklist

Before opening a PR, run from `frontend/merchant/`:

```bash
flutter analyze && flutter test
```

Both must pass clean. If you're using `pre-commit`, set up a hook that runs these — recommended.

## Common commands cheatsheet

| Task | Command |
|---|---|
| Install deps | `flutter pub get` |
| Update deps | `flutter pub upgrade` |
| Show outdated | `flutter pub outdated` |
| Clean build artifacts | `flutter clean` |
| Hot reload (dev) | `r` in terminal where `flutter run` is running |
| Hot restart | `R` in terminal where `flutter run` is running |
| Inspect widget tree | `flutter run` then `w` (or use Flutter DevTools) |
| Generate release APK | `flutter build apk --release` |
| Generate release iOS | `flutter build ios --release` (macOS only) |
| Generate web | `flutter build web --release` |

## IDE setup

### VS Code (recommended)

Install:
- **Dart** extension
- **Flutter** extension

`.vscode/settings.json` (optional, project-local):
```json
{
  "editor.formatOnSave": true,
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code",
    "editor.formatOnSave": true,
    "editor.rulers": [80]
  }
}
```

### Android Studio / IntelliJ

Install Flutter + Dart plugins. Open the `frontend/merchant/` folder as a project.

## Project structure cheat sheet

```
frontend/merchant/
├── lib/
│   ├── main.dart              # ProviderScope + HappyMenuApp
│   ├── app.dart               # MaterialApp.router
│   ├── theme/                 # AppColors, AppTheme
│   ├── router/                # go_router config + AppRoutes
│   ├── shared/
│   │   ├── models/            # Menu, Dish, Category, Store
│   │   ├── mock/              # MockData (the only place for sample data)
│   │   └── widgets/           # StatusChip, PrimaryButton, ...
│   └── features/
│       ├── auth/              # A1 Login
│       ├── home/              # A2 Home
│       ├── capture/           # A3 Camera, A4 Upload, A5 Crop, A6 OCR
│       ├── edit/              # A7 Organize, A8 Edit Dish
│       ├── ai/                # A9 AI Optimize
│       ├── publish/           # A10–A13 Template / Theme / Preview / Published
│       ├── manage/            # A14 Manage, A15 Statistics
│       └── store/             # A16 Stores, A17 Settings
├── assets/sample/             # Placeholder images (menu covers, etc.)
└── test/
    ├── widgets/               # Shared widget tests
    └── smoke/                 # Per-screen smoke tests
```

## Adding a new screen

1. Add the route constant to `lib/router/app_router.dart` (if new) and a `GoRoute` entry pointing to the new screen.
2. Create `lib/features/<feature>/presentation/<screen>_screen.dart` as a `StatelessWidget` (or `StatefulWidget` if it owns controllers).
3. Use shared widgets where applicable (`PrimaryButton`, `MenuCard`, etc.).
4. Use `AppColors.*` tokens from `lib/theme/app_colors.dart` — no hardcoded hex.
5. Add a smoke test at `test/smoke/<screen>_smoke_test.dart` verifying it renders + key text present.
6. `flutter analyze && flutter test` must pass.
7. Visual-check it against any existing design in `frontend/design/`.

## Adding a shared widget

1. Create `lib/shared/widgets/<name>.dart`.
2. **Const constructor** required.
3. Use `AppColors` tokens.
4. Add a widget test at `test/widgets/<name>_test.dart` verifying behavior (not just render).

## Adding a new dependency

Don't, unless you can justify it in the PR description. We standardized on Riverpod / go_router / google_fonts only. If you have a strong case (e.g., "we need QR generation, qr_flutter is the obvious choice"), bring it up in a Discussion first.

## Troubleshooting

### `flutter doctor` complains about Android licenses
```bash
flutter doctor --android-licenses
```

### Tests hang / never complete
Likely a `pumpAndSettle` waiting on a never-completing animation or timer. Use `pump()` (single frame) instead. See `processing_screen_smoke_test.dart` for the pattern.

### Web build error after Riverpod / go_router upgrade
Try:
```bash
flutter clean && flutter pub get && flutter analyze
```

### Android build fails after package rename
You may need to delete `frontend/merchant/build/` and `frontend/merchant/android/.gradle/`:
```bash
flutter clean
rm -rf frontend/merchant/android/.gradle
flutter pub get
flutter build apk --debug
```

### "package:happy_menu_merchant/..." import errors
We renamed to `menuray_merchant`. If you see old imports, your branch is behind `main`. Rebase.

## Where to ask for help

- **Question about how to do X**: open a GitHub Discussion or comment on a related issue
- **Bug**: file an issue with the bug template
- **Process/design question**: see [decisions.md](decisions.md) — if not answered, open a Discussion
