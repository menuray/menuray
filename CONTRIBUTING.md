# Contributing to MenuRay

Thanks for your interest! MenuRay is open source and welcomes contributions of all sizes — code, docs, design, translations, bug reports.

## Before you start

- Read the [README](README.md) for project overview.
- Check [docs/roadmap.md](docs/roadmap.md) for current priorities.
- For non-trivial changes, **open an issue or Discussion first** to align on direction before writing code. This avoids wasted effort.

## Code of Conduct

Participation in this project is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). Be excellent to each other.

## Setup

See [docs/development.md](docs/development.md) for full local setup.

TL;DR for the merchant app:

```bash
git clone git@github.com:menuray/menuray.git
cd menuray/frontend/merchant
flutter pub get
flutter analyze && flutter test    # should be clean
flutter run -d chrome
```

## Workflow

1. **Fork** the repo (unless you have direct write access).
2. **Branch from `main`**: `git checkout -b feat/your-feature` or `fix/short-description`.
3. **Make focused commits** following the [Commit message convention](#commit-messages) below.
4. **Run checks** before opening a PR:
   ```bash
   cd frontend/merchant
   flutter analyze     # must report 0 issues
   flutter test        # all tests must pass
   ```
5. **Open a PR** against `main`. Fill in the PR template — explain what & why.
6. **Address review feedback** in additional commits (don't force-push during review unless asked).
7. Once approved, a maintainer will merge.

## Commit messages

We use **[Conventional Commits](https://www.conventionalcommits.org/)**:

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

**Types:** `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `style`, `perf`

**Scopes** (current): `auth`, `home`, `capture`, `edit`, `ai`, `publish`, `manage`, `store`, `shared`, `theme`, `router`, `nav`, `mock`, `models`, `assets`, `infra`. Add new scopes as the codebase grows.

Examples:
- `feat(auth): add Supabase phone OTP flow`
- `fix(home): MenuCard tap navigates to /manage/menu`
- `docs(architecture): add data-flow diagram for OCR pipeline`
- `chore(deps): bump flutter_riverpod to 2.7.0`

## Code style

We follow patterns established in [CLAUDE.md](CLAUDE.md). Key rules:

- **Const constructors** on every private stateless widget.
- **`StatefulWidget`** for any widget owning a controller (`TextEditingController`, `AnimationController`, `Timer`) — proper `initState`/`dispose`.
- **Use `AppColors` tokens** — no hardcoded hex (with documented exceptions).
- **Use `withValues(alpha: …)`** instead of deprecated `withOpacity()`.
- **Riverpod for state** — no `bloc`, no `provider`, no `getx`.
- **`go_router` for navigation** — no direct `Navigator.push`.
- **Avoid `Spacer()` in scroll contexts** — use `SizedBox(height: N)`.

## Tests

| Change | Required test |
|---|---|
| New shared widget | Widget test in `frontend/merchant/test/widgets/` verifying props/behavior |
| New screen | Smoke test in `frontend/merchant/test/smoke/` — renders without throwing + key text present |
| Bug fix | Regression test that fails before, passes after |
| Refactor with no behavior change | No new test required, but existing tests must still pass |

We don't enforce strict TDD on UI screens — see [docs/decisions.md](docs/decisions.md) ADR-007 for reasoning.

## Adding a new language

See [docs/i18n.md](docs/i18n.md). Submitting a new translation is one of the most welcome contributions.

## Reporting bugs

Use the **bug report** issue template. Include:
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots / logs if relevant
- Environment (OS, Flutter version, device)

## Proposing features

Open a **Discussion** first (or feature request issue if Discussions aren't enabled). Describe:
- The user problem (not the solution)
- Why current behavior is inadequate
- Proposed approach (rough sketch is fine)

We'll align on direction before implementation starts.

## Security issues

**Do not** open public issues for security vulnerabilities. See [SECURITY.md](SECURITY.md).

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE) — the same license as the project.

## AI-assisted contributions

Using Claude / Cursor / Copilot is welcome. If you do:
- Make sure the code follows our conventions (see [CLAUDE.md](CLAUDE.md) — your AI tool will read this automatically).
- Add a `Co-Authored-By:` trailer crediting the model.
- You're still responsible for reviewing what gets committed; "the AI wrote it" isn't a defense for buggy code.

## Questions?

Open a Discussion or ping a maintainer in an existing issue. Happy hacking 🍜
