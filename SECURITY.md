# Security Policy

## Reporting a vulnerability

**Please do not file a public GitHub issue for security vulnerabilities.**

If you discover a security issue in MenuRay, report it privately so we can fix it before it's exploited.

### Preferred channels

1. **GitHub Security Advisories** — [Open a private advisory](https://github.com/menuray/menuray/security/advisories/new)  *(preferred)*
2. **Email** — `security@menuray.com` *(set up once domain is registered; until then, see channel above)*

### What to include

- Description of the vulnerability
- Steps to reproduce (proof-of-concept welcome)
- Impact assessment (what an attacker could do)
- Affected versions / commit SHA
- Your suggested fix (optional)

### What to expect

| Stage | Timeline |
|---|---|
| Initial acknowledgment | Within 72 hours |
| Severity assessment | Within 7 days |
| Fix development & coordinated disclosure window | 30–90 days depending on severity |
| Public disclosure & advisory | After patch released |

We aim to credit reporters in the security advisory unless they prefer to remain anonymous.

## Scope

In scope:
- The MenuRay merchant app (Flutter codebase under `frontend/merchant/`)
- The customer view web app (when added)
- Backend code (Supabase Edge Functions, RLS policies, schema — when added)
- CI/CD pipelines and release artifacts in this repo

Out of scope:
- Vulnerabilities in third-party services we depend on (Supabase, Flutter, OCR/LLM providers) — please report to those vendors directly
- Self-hosted deployments by third parties (we maintain the code; deployment security is the operator's responsibility)
- Social engineering, physical attacks, DoS

## Supported versions

The project is pre-1.0 and rapidly changing. We support the **latest commit on `main`** for security fixes. Once we cut tagged releases, this section will be updated to specify which versions get backported fixes.

## Safe harbor

We support good-faith security research. As long as you:

- Make a good-faith effort to avoid privacy violations, data destruction, and service disruption,
- Only access data necessary to demonstrate the vulnerability,
- Do not exploit the issue beyond proof-of-concept,
- Give us reasonable time to fix before disclosure,

…we will not pursue legal action against you.

Thank you for helping keep MenuRay and its users safe.
