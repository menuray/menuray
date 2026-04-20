# CLAUDE.md — Guidance for AI coding agents

> This file is read automatically by Claude Code, Cursor, GitHub Copilot, and similar AI coding tools. Keep it short, opinionated, and current.

## What this project is

**MenuRay** — open-source app that turns paper restaurant menus into shareable digital menus via a single photo. Targets global SMB restaurants. MIT-licensed. Multi-platform (mobile native + web).

Read [`README.md`](README.md) and [`docs/architecture.md`](docs/architecture.md) for the full picture before making non-trivial changes.

## Where to look first

| Question | Doc |
|---|---|
| What does the system do? | [README.md](README.md) |
| How is it laid out? | [docs/architecture.md](docs/architecture.md) |
| Why these technology choices? | [docs/decisions.md](docs/decisions.md) |
| How do I run it? | [docs/development.md](docs/development.md) |
| What's the brand spec? | [docs/DESIGN.md](docs/DESIGN.md) |
| What's left to build? | [docs/roadmap.md](docs/roadmap.md) |
| How to add a language? | [docs/i18n.md](docs/i18n.md) |
| Detailed plan for a feature? | [docs/superpowers/plans/](docs/superpowers/plans/) |

## Tech stack (current)

| Layer | Tech |
|---|---|
| Merchant app | Flutter (stable), Material 3, Riverpod, go_router, google_fonts |
| Customer view | SvelteKit (planned, not implemented yet) |
| Backend | Supabase (planned: Postgres + Auth + Storage + Edge Functions) |
| AI | OCR + LLM (provider-agnostic, planned) |

## Conventions (follow these without asking)

### Code
- **Const constructors on every private stateless widget** — even if it has `context.go(...)` callbacks. Pattern established in `frontend/merchant/lib/features/auth/presentation/login_screen.dart`.
- **`StatefulWidget` for any widget owning a `TextEditingController`, `AnimationController`, or `Timer`** — initialize in `initState`, dispose in `dispose`. Never create controllers inline in build.
- **Use `AppColors` tokens** from `frontend/merchant/lib/theme/app_colors.dart`, not hardcoded hex literals. Two documented exceptions: Stitch's `surface-container-highest` (`#E6E2DB`) and `surface-container-low` (`#F7F3EC`) for input field backgrounds — these may be inline.
- **Use `withValues(alpha: …)`, never `withOpacity(…)`** (latter is deprecated in Flutter 3.41+).
- **Avoid `Spacer()` in `SingleChildScrollView` or `Column(mainAxisSize: min)`** — causes unbounded-height crashes. Use `SizedBox(height: N)` instead.
- **Riverpod for any new state** — `flutter_riverpod` is set up; create `Provider`/`StateProvider` etc. when you need state beyond a screen.
- **`go_router` for navigation** — never `Navigator.push` directly. Add new route constants to `frontend/merchant/lib/router/app_router.dart`.

### Files & folders
- Feature-first under `frontend/merchant/lib/features/<feature>/presentation/<screen>_screen.dart`.
- Shared widgets at `frontend/merchant/lib/shared/widgets/`.
- Shared models at `frontend/merchant/lib/shared/models/`.
- Mock data at `frontend/merchant/lib/shared/mock/mock_data.dart` — only place for sample data.
- Tests at `frontend/merchant/test/widgets/` (shared widget tests) and `frontend/merchant/test/smoke/` (per-screen smoke).

### Brand
- Brand name is **`MenuRay`** (CamelCase, one word). Never write "Menu Ray" with space, never lowercase except in package/URL contexts.
- Slogan: "Snap a photo of any paper menu, get a shareable digital menu in minutes." (English) / "拍一张照，5 分钟生成电子菜单" (Chinese).
- Brand color hex codes are in [`docs/DESIGN.md`](docs/DESIGN.md). Don't invent new ones.

### Tests
- **Skip strict TDD for UI screens** — see [docs/decisions.md](docs/decisions.md) ADR-007. Smoke test (renders without throwing + key text present) is the bar for screens.
- **Widget tests for shared widgets** — must verify props/behavior, not just render.
- **`flutter analyze` must be clean before commit** — non-negotiable.
- **`flutter test` must pass before commit** — non-negotiable.

### Commits
- **Conventional commits**: `<type>(<scope>): <subject>`.
  - Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`.
  - Scopes used so far: `auth`, `home`, `capture`, `edit`, `ai`, `publish`, `manage`, `store`, `shared`, `theme`, `router`, `nav`, `mock`, `models`, `assets`.
- One logical change per commit.
- Co-authored-by trailer for AI agent contributions:
  ```
  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  ```

### Branches
- **`main` is the only branch** for now. Once we have remote + multiple contributors, switch to feature branches + PR.
- Don't push to `main` if a remote exists without a PR.

## Don'ts

- ❌ Don't add new dependencies without justification in the PR description.
- ❌ Don't introduce a different state management library (no `bloc`, no `provider`, no `getx`) — we standardized on Riverpod.
- ❌ Don't hardcode user-visible strings — when i18n is set up (see roadmap), every visible string lives in `.arb` files. For now, write strings in a way that's easy to extract (no string concatenation; full sentences in source).
- ❌ Don't bake in vendor-specific OCR / LLM API calls — abstract behind an interface so providers are swappable.
- ❌ Don't commit secrets / API keys. Use `.env` (already gitignored if present) or Supabase secrets.
- ❌ Don't ship code that's only China-specific (短信宝, 微信支付, 阿里云 OCR) — this project is global. Use international defaults; offer Chinese-specific alternatives via plugin/config later.
- ❌ Don't refactor unrelated code while making a focused change. Stay in scope.

## When in doubt

- Read [`docs/decisions.md`](docs/decisions.md) for "why we did it this way".
- If a decision isn't documented and would matter for future contributors, **add an ADR** to `docs/decisions.md` after making it.
- Before any non-trivial implementation, propose the design and get user approval (see superpowers `brainstorming` skill if available).
- Before claiming "done", run `flutter analyze && flutter test` and paste the output.

## Active work

| Status | What |
|---|---|
| ✅ Done | Brand system; 17 merchant screens built; Supabase backend MVP (ADR-013~016); 13/17 screens wired to Supabase via ADR-017 pattern; `parse-menu` realtime + capture flow (camera / correct_image / processing with self-drawn cropper); full i18n (en/zh ARB, in-app picker); iOS/Android camera permissions; 34 tests passing. Product decisions ratified 2026-04-20 (see `docs/product-decisions.md`); ADR-018 supersedes ADR-013 (auth model). |
| 🔄 Next | **Session 1**: SvelteKit customer view (B1-B4) + 2 launch templates (Minimal + Grid) + merchant polish (logout/register wire, form validation, loading-error-empty audit). Then sessions 2-6: OpenAI adapter → auth migration (ADR-018) → Stripe billing → analytics pipeline → remaining 3 templates. |

See [`docs/roadmap.md`](docs/roadmap.md) for the prioritized list and [`docs/superpowers/plans/`](docs/superpowers/plans/) for detailed plans.
