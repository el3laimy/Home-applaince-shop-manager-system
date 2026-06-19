# ALIkhlasPOS v2 Apple/iOS Liquid Glass UI Tasks

This checklist tracks the UI and typography phase described in `IMPLEMENTATION_PLAN.md`.

Status legend:

- `[ ]` Not started.
- `[~]` In progress.
- `[x]` Done.
- `[!]` Blocked or needs decision.

## Phase 0: Baseline And Audit

Review skills:

- `frontend-design`
- `docs-guard`

Tasks:

- [x] Confirm the working branch before editing.
- [x] Confirm `git status --short` is clean or record unrelated changes.
- [x] Inspect current `Roboto`, `FontWeight.w800`, `_GlassStage`, `_GlassPane`, and `BackdropFilter` usage.
- [x] Inspect `pubspec.yaml` for font and icon dependencies.
- [x] Confirm `assets/fonts/` does not already contain font files.
- [x] Run baseline `dart analyze lib/v2 lib/main.dart test/v2` when practical.
- [x] Run baseline `flutter test` when practical.

Acceptance:

- [x] Current UI typography and glass issues are verified from the repo.
- [x] No financial or database files are included in the planned edit set.

## Phase 1: Cairo Arabic Font

Tasks:

- [x] Create `Frontend/alikhlas_pos/assets/fonts/`.
- [x] Add `Cairo-Regular.ttf` weight 400.
- [x] Add `Cairo-Medium.ttf` weight 500.
- [x] Add `Cairo-SemiBold.ttf` weight 600.
- [x] Add `Cairo-Bold.ttf` weight 700.
- [x] Add `assets/fonts/OFL.txt`.
- [x] Register Cairo font assets in `pubspec.yaml`.
- [x] Do not add `Cairo-ExtraBold.ttf`.
- [x] Do not add `google_fonts`.
- [x] Remove `fontFamily: 'Roboto'` from v2 UI.
- [x] Replace app-level font family with `Cairo`.
- [x] Remove or replace every `FontWeight.w800` usage in v2 UI.

Acceptance:

- [x] Cairo works offline as a bundled Flutter font.
- [x] `rg "Roboto" Frontend/alikhlas_pos/lib/v2` returns no v2 UI usage.
- [x] `rg "FontWeight.w800" Frontend/alikhlas_pos/lib/v2` returns no v2 UI usage.
- [x] `rg "Cairo-ExtraBold" Frontend/alikhlas_pos` returns no results.

## Phase 2: Theme And Design Tokens

Tasks:

- [x] Add `lib/v2/app/design_tokens.dart`.
- [x] Move reusable colors into design tokens.
- [x] Move glass fills, borders, shadows, radii, and spacing into design tokens.
- [x] Extract a public `buildV2Theme()` function from the current theme logic.
- [x] Define a complete Cairo-based `TextTheme`.
- [x] Add Arabic-friendly text heights.
- [x] Configure `InputDecorationTheme` for clear glass-like fields without real blur.
- [x] Configure `FilledButtonTheme` and `OutlinedButtonTheme`.
- [x] Keep Material Icons unless `cupertino_icons` is explicitly added.

Acceptance:

- [x] Theme construction is testable without pumping the whole app.
- [x] Body, title, label, and headline styles are explicitly defined.
- [x] Button and input heights, radii, and borders are consistent.
- [x] No `CupertinoIcons` usage exists without a `cupertino_icons` dependency.

## Phase 3: Apple/iOS-Inspired Liquid Glass System

Tasks:

- [x] Rework `_GlassStage` with a calm, non-flat background.
- [x] Keep the background subtle and avoid heavy gradients.
- [x] Rework `_GlassPane` for large surfaces only.
- [x] Limit real `BackdropFilter` blur to large panes, dialogs, and major shell surfaces.
- [x] Add edge highlight and visible glass border to major panes.
- [x] Use one soft shadow style for major panes.
- [x] Create fake glass styling for buttons, inputs, nav items, list rows, chips, and table rows.
- [x] Reduce visual noise from `_LiquidLinesPainter` or replace it with a calmer backdrop treatment.

Acceptance:

- [x] Dense controls do not introduce many nested `BackdropFilter` layers.
- [x] Glass surfaces remain readable and do not disappear into the background.
- [x] The visual direction feels Apple/iOS-inspired without copying Apple assets or branding.
- [x] The app remains dense and operational, not a landing page.

## Phase 4: Priority Screen Polish

Tasks:

- [x] Polish Login screen.
- [x] Polish Change Password screen.
- [x] Polish Workbench shell.
- [x] Polish SideNav selected and hover/pressed states.
- [x] Polish Daily Dashboard panels.
- [x] Polish POS search, cart, payment, and summary surfaces.
- [x] Polish Inventory filters, tables, and low-stock indicators.
- [x] Polish Reports cards, filters, and summary tables.
- [x] Confirm RTL layout remains correct.
- [x] Confirm text does not overflow in compact desktop widths.

Acceptance:

- [x] Login is visually clear and uses Cairo.
- [x] Dashboard has visible Liquid Glass depth and remains easy to scan.
- [x] POS remains fast, readable, and practical for daily sale flow.
- [x] Inventory and Reports remain dense enough for shop work.

## Phase 5: Accessibility And Golden Tests

Tasks:

- [x] Add a theme test proving representative `TextTheme` styles use `Cairo`.
- [x] Add or update a test proving representative text styles use Cairo.
- [x] Add a contrast helper or documented manual contrast check for body text over glass.
- [x] Ensure body text over glass reaches at least 4.5:1 contrast.
- [x] Add golden test for Login.
- [x] Add golden test or screenshot sanity test for GlassPane/Workbench shell.
- [x] Update existing widget tests affected by UI changes.
- [x] Verify no tests depend on old Roboto rendering.

Acceptance:

- [x] Golden coverage exists for Login.
- [x] Golden or screenshot sanity coverage exists for a major glass surface.
- [x] Contrast requirement is checked and recorded.
- [x] Existing v2 widget and use-case tests stay green.

## Phase 6: Verification And Documentation

Review skills:

- `docs-guard`
- `test-guard`
- `clean-code-guard`

Tasks:

- [x] Run `flutter pub get`.
- [x] Run `dart analyze lib/v2 lib/main.dart test/v2`.
- [x] Run `flutter test`.
- [x] Run `HOME=/tmp PUB_CACHE=/home/el3laimy/.pub-cache /home/el3laimy/development/flutter/bin/flutter build linux`.
- [x] Run the app and visually review Login.
- [x] Run the app and visually review Dashboard.
- [!] Run the app and visually review POS.
- [x] Update root `README.md` with Cairo, OFL, and Liquid Glass notes.
- [x] Update `Frontend/alikhlas_pos/README.md` with Cairo, OFL, and Liquid Glass notes.
- [x] Update `RELEASE_NOTES_V2.md` with the UI phase summary.
- [x] Confirm no financial or database files were modified.
- [x] Commit the UI changes with a focused commit message.
- [x] Confirm `git status --short` is clean.

Acceptance:

- [x] Analyze passes.
- [x] Tests pass.
- [x] Linux build passes.
- [!] Login, Dashboard, and POS pass visual review.
- [x] Documentation matches the implemented UI and font assets.
- [x] The final tree is clean after commit.
