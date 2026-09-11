# Implementation batch 31 — Debian package installability gate

## Scope

- Corrected the GTK runtime dependency for both classic Debian/Ubuntu packages and Ubuntu 24.04's `t64` transition.
- Added a package verification script and made it a required `Desktop Release Build` CI step.
- Enabled the desktop workflow for pull requests and updates to `main`.

## Verified behavior

- A newly built package passes control-field, extracted-content, desktop-entry, icon, dynamic-library, and APT dependency-resolution checks.
- The prior package is rejected because its sole `libgtk-3-0` dependency has no candidate on Ubuntu 24.04.

## Validation

- `bash -n tool/build_linux_deb.sh tool/verify_linux_deb.sh`: succeeded.
- A fresh package built from `build/linux/x64/release/bundle` passed `bash tool/verify_linux_deb.sh`.
- The previous package was rejected with exit code 69, as expected.
- Workflow YAML parsed successfully and `git diff --check` succeeded.

## Boundary

This verifies package installability and content without modifying the developer machine. A clean-device install, upgrade, launch, and removal still require a supported Debian/Ubuntu system; Windows build, signing, and field validation also remain open.
