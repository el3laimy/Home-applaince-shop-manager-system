# Implementation batch 30 — opening-balance end-user flow

## Scope

- Added the end-user entry point for opening balances in Settings.
- Supports customer receivables, supplier payables, cash, and wallet balances.
- Requires a reviewed confirmation before writing and submits through the existing durable pending-financial-operation contract.

## Verified behavior

- The dialog accepts Arabic money digits, requires the related customer or supplier where applicable, and records the selected due date.
- Customer and supplier opening balances create one installment plan; cash and wallet opening balances are distinct from the physical opening cash count of a shift.
- The 1024x720 widget flow navigates to Settings, selects a customer, reviews the value, records it once, and confirms the resulting plan, receivable total, and integrity audit.

## Validation

- `dart analyze lib/v2 lib/main.dart test/v2`: no issues.
- `flutter test --no-pub test/v2`: 160 passed.
- `HOME=/tmp PUB_CACHE=/home/el3laimy/.pub-cache /home/el3laimy/development/flutter/bin/flutter build linux --release --no-pub`: succeeded.
- `git diff --check`: succeeded.

## Boundary

This is local automated evidence. A supervised conversion of a real shop's paper balances and a clean-install trial on Windows and Linux remain required before end-user release acceptance.
