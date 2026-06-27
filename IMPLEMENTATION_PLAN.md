# ALIkhlasPOS v2 Apple/iOS Liquid Glass UI Implementation Plan

## Summary

ALIkhlasPOS v2 is now the active offline Flutter desktop application. The v2 engine, SQLite/drift data layer, ledger workflows, tests, Linux build, and v1 cleanup have already been completed.

This plan covers the next focused phase only: upgrade the v2 interface to an Apple/iOS-inspired Liquid Glass visual system and fix Arabic typography with a bundled offline Cairo font.

All implementation work for this phase must stay inside `Frontend/alikhlas_pos`. Do not change financial workflows, use-cases, ledger rules, migrations, or database schema.

## Reliability And Glass Polish Addendum

After the first Liquid Glass pass, the next improvement phase hardens the real owner workflow and makes the glass background more visible without adding heavy assets or reopening a broad UI rewrite.

- Add a full owner operating-day acceptance test: login/change password, open shift, purchase, sale, installment collection, return, close shift, and backup.
- Replace permissive money parsing with a single integer-minor-unit parser that accepts Arabic/English digits and `.` or `,` decimal separators.
- Invalid money input must show a clear Arabic error and must not post a sale, purchase, installment payment, product price, or cash movement as zero.
- Make real blur opt-in on `_GlassPane`; keep `BackdropFilter` centralized and avoid blur inside buttons, fields, lists, tables, and dense rows.
- Strengthen `_GlassStage` with deterministic code-drawn light layers so the glass surfaces have visible depth while preserving readability.
- Expand golden coverage to include Login, Dashboard, POS, and Reports after the background polish.

## Reports And Expense Workflow Addendum

The Reports screen currently displays period expenses, but the UI does not provide a way to create a new expense. The `recordExpense` use-case exists and is covered by use-case tests, while the screen only reads existing `expenses` rows and ledger-derived period totals.

This is a real delivery gap because the shop owner needs to record daily expenses without leaving the app.

- Add a clear `مصروف جديد` action to the Reports screen, and consider a secondary shortcut from the Daily screen after the Reports flow is stable.
- Implement an expense dialog with Arabic validation for:
  - description;
  - amount;
  - payment method: cash or wallet only.
- Use the existing `recordExpense` workflow.
- Preserve the current rules:
  - cash expenses require an open shift;
  - wallet expenses do not require a shift;
  - installment is not allowed for expenses;
  - negative cash or wallet balance requires explicit per-operation approval.
- Refresh the dashboard/report snapshot after a successful expense.
- Keep all period report totals derived from `LedgerLine`; do not introduce manually maintained report totals.
- Add widget coverage proving the owner can record an expense from the UI and see it reflected in `مصروفات الفترة`.
- Add a Reports source audit note documenting which panels are ledger-derived, invoice-table-derived, product-table-derived, or snapshot-derived.

## Current UI Problems

- `Frontend/alikhlas_pos/lib/v2/app/v2_app.dart` currently uses `fontFamily: 'Roboto'`, which is not the right controlled font choice for Arabic UI.
- `Frontend/alikhlas_pos/pubspec.yaml` does not register any bundled app fonts.
- `Frontend/alikhlas_pos/assets/fonts/` does not exist yet.
- The current `TextTheme` is incomplete and leaves many Material text styles to defaults.
- Existing glass surfaces are too light and flat: translucent white panes sit on a pale background, so the Liquid Glass effect is weak.
- Current blur is concentrated inside `_GlassPane`, but the design does not yet separate expensive real blur from cheaper glass-like controls.
- The UI needs an Apple/iOS-inspired direction: soft translucency, clear depth, bright edge highlights, calm rounded surfaces, and excellent readability.

## Key Decisions

- **Icons:** stay on Material Icons by default. Do not use `CupertinoIcons` unless `cupertino_icons` is explicitly added to `pubspec.yaml`; otherwise icons may render as missing glyph boxes.
- **Blur:** use `BackdropFilter` only for large surfaces such as shell panels, major panes, and dialogs. Buttons, inputs, list rows, chips, and table rows must use fake glass styling: translucent fill, visible border, and subtle highlight without real blur.
- **Background:** use a calm but non-flat background. A subtle gradient or soft light layers are allowed to make glass visible. Avoid loud gradients or decorative clutter.
- **Contrast:** body text over glass must meet WCAG AA contrast of at least 4.5:1.
- **Golden tests:** include at least one golden test for Login and one golden or screenshot sanity test for a GlassPane/Workbench shell surface.
- **Cairo weights:** bundle Cairo weights 400, 500, 600, and 700 only. Do not bundle `Cairo-ExtraBold.ttf`, and do not use `FontWeight.w800`.
- **Offline:** do not add `google_fonts` as a runtime dependency. Fonts must be local assets.

## Implementation Changes

### Arabic Font And Theme

- Add local Cairo font files under `Frontend/alikhlas_pos/assets/fonts/`:
  - `Cairo-Regular.ttf` weight 400.
  - `Cairo-Medium.ttf` weight 500.
  - `Cairo-SemiBold.ttf` weight 600.
  - `Cairo-Bold.ttf` weight 700.
  - `OFL.txt` for the font license.
- Register Cairo in `Frontend/alikhlas_pos/pubspec.yaml`.
- Replace `fontFamily: 'Roboto'` with Cairo at the application theme level.
- Extract the theme into a testable public function such as `buildV2Theme()`.
- Define a complete Arabic-friendly `TextTheme` with controlled size, weight, and `height` values.
- Remove or replace any `FontWeight.w800` usage in v2 UI.

### Design Tokens

- Add `Frontend/alikhlas_pos/lib/v2/app/design_tokens.dart`.
- Centralize colors, spacing, radii, shadows, glass fills, and borders.
- Use tokens in the theme, `_GlassStage`, `_GlassPane`, navigation, buttons, inputs, and priority screens.
- Keep the token system practical and compact; do not refactor every numeric spacing value in the large UI file in one pass unless the value is touched for this UI phase.

### Apple/iOS-Inspired Liquid Glass

- Rework `_GlassStage` to provide a soft, non-flat backdrop that makes glass surfaces visible.
- Rework `_GlassPane` for large surfaces only:
  - real blur around sigma 10-12;
  - translucent white surface with stronger readability;
  - visible light border;
  - subtle top/edge highlight;
  - one soft shadow;
  - consistent rounded corners.
- Use fake glass styling for controls and dense content:
  - buttons;
  - text fields;
  - navigation items;
  - chips;
  - list rows;
  - table rows.
- Preserve the shop-app character: dense, fast to scan, and operational. Do not turn the app into a landing page or marketing layout.

### Priority Screens

Polish these screens in order:

1. Login.
2. Change password.
3. Workbench shell and side navigation.
4. Daily dashboard.
5. POS.
6. Inventory.
7. Reports.

Each screen must remain readable, RTL-safe, and efficient for repeated daily shop use.

## Test Plan

- Add or update a test proving the app theme uses Cairo.
- Add text/search checks proving v2 no longer contains:
  - `fontFamily: 'Roboto'`;
  - `FontWeight.w800`;
  - `Cairo-ExtraBold.ttf`;
  - `CupertinoIcons` without a `cupertino_icons` dependency.
- Update affected widget tests in `Frontend/alikhlas_pos/test/v2`.
- Add golden coverage for Login and one GlassPane/Workbench surface.
- Run these commands before closing the phase:

```bash
cd Frontend/alikhlas_pos
flutter pub get
dart analyze lib/v2 lib/main.dart test/v2
flutter test
HOME=/tmp PUB_CACHE=/home/el3laimy/.pub-cache /home/el3laimy/development/flutter/bin/flutter build linux
```

- Run the app and visually review Login, Dashboard, and POS.

## Acceptance Criteria

- Cairo is bundled locally and works offline.
- No v2 UI code uses Roboto.
- No v2 UI code uses `FontWeight.w800`.
- The app does not bundle `Cairo-ExtraBold.ttf`.
- No `CupertinoIcons` are used unless `cupertino_icons` is present in `pubspec.yaml`.
- Real blur is limited to large panes; dense controls do not create many nested `BackdropFilter` layers.
- Body text over glass meets 4.5:1 contrast.
- Login, Dashboard, and POS visually read as Apple/iOS-inspired Liquid Glass while staying practical for shop operations.
- Analyze, tests, and Linux build pass.
- Documentation mentions Cairo, OFL licensing, offline font bundling, and the Liquid Glass direction.
- `git status --short` is clean after the final commit.

## Assumptions

- Material Icons remain the default icon set for this phase.
- Cairo is the approved Arabic font because it is already used by the PDF layer and works well for Arabic UI.
- Apple/iOS is visual inspiration only; do not copy Apple branding, assets, or proprietary UI imagery.
- Accessibility and performance take priority over dramatic glass effects.
- Financial and database code remains untouched in this phase.
