# GEMINI.md — ALIkhlasPOS v2 Agent Guardrails

## Project Reality

- Active app: `Frontend/alikhlas_pos`.
- Runtime: Flutter Desktop + SQLite/drift in one local process.
- No active .NET Backend, PostgreSQL, Redis, Docker, HTTP API, GetX, or v1 runtime.
- Target platforms: Linux now, Windows after external validation.

## Non-Negotiable Rules

- Do not reintroduce backend/server runtime dependencies.
- Do not store money as `double`; use integer minor units.
- Keep `LedgerEntry`/`LedgerLine` as the financial source of truth.
- Do not change drift schema or ledger posting rules without a focused failing test first.
- Do not delete v2 tests or weaken assertions to make a change pass.
- Keep user-facing Arabic text clear and suitable for a shop owner.

## Development Workflow

Before finishing any financial or UI workflow change, run:

```bash
cd Frontend/alikhlas_pos
dart analyze lib/v2 lib/main.dart test/v2
flutter test
```

Before delivery or release validation, also run:

```bash
HOME=/tmp PUB_CACHE=/home/el3laimy/.pub-cache /home/el3laimy/development/flutter/bin/flutter build linux
```

## Current Acceptance Notes

- Windows build must be validated on Windows or suitable CI before Windows release.
- Thermal/A4 printer output must be validated on target hardware before final handover.
- Installment interest is not refunded automatically on sale returns; any interest refund is a future explicit settlement workflow.
