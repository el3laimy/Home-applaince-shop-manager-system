#!/usr/bin/env bash
# Verifies the Debian package can be resolved and contains a runnable bundle.
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "Usage: $0 <package.deb>" >&2
  exit 64
fi

deb_path="$(readlink -f "$1")"
if [[ ! -f "$deb_path" ]]; then
  echo "Debian package is missing: $deb_path" >&2
  exit 65
fi

field() {
  dpkg-deb --field "$deb_path" "$1"
}

if [[ "$(field Package)" != "alikhlas-pos" ]]; then
  echo "Unexpected Debian package name" >&2
  exit 66
fi
if [[ "$(field Architecture)" != "amd64" ]]; then
  echo "Debian package must target amd64" >&2
  exit 67
fi
if [[ -z "$(field Version)" ]]; then
  echo "Debian package version is missing" >&2
  exit 68
fi

depends="$(field Depends)"
if [[ "$depends" != *"libgtk-3-0 | libgtk-3-0t64"* ]] ||
  [[ "$depends" != *"libstdc++6"* ]] ||
  [[ "$depends" != *"liblzma5"* ]]; then
  echo "Debian runtime dependencies are incomplete: $depends" >&2
  exit 69
fi

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/alikhlas-pos-deb-check.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
dpkg-deb --extract "$deb_path" "$staging_dir"

bundle_root="$staging_dir/opt/alikhlas-pos"
executable="$bundle_root/alikhlas_pos"
desktop_file="$staging_dir/usr/share/applications/alikhlas-pos.desktop"
icon_file="$staging_dir/usr/share/icons/hicolor/256x256/apps/alikhlas-pos.png"

[[ -x "$executable" ]]
[[ -f "$desktop_file" ]]
[[ -f "$icon_file" ]]
grep -Fxq 'Exec=/opt/alikhlas-pos/alikhlas_pos' "$desktop_file"
grep -Fxq 'Icon=alikhlas-pos' "$desktop_file"

if LD_LIBRARY_PATH="$bundle_root/lib" ldd "$executable" | grep -Fq 'not found'; then
  echo "The packaged executable has unresolved shared libraries" >&2
  exit 70
fi

if command -v apt-get >/dev/null 2>&1; then
  apt-get --simulate install "$deb_path" >/dev/null
fi

printf 'Debian package verified: %s\n' "$deb_path"
