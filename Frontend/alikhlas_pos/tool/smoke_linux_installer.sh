#!/usr/bin/env bash
# Installs, upgrades, removes, and reinstalls the Debian package on a disposable
# CI runner while proving that application data survives package operations.
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "Usage: $0 <older-package.deb> <current-package.deb>" >&2
  exit 64
fi

older_package="$(readlink -f "$1")"
current_package="$(readlink -f "$2")"
package_name="alikhlas-pos"
executable="/opt/alikhlas-pos/alikhlas_pos"
desktop_file="/usr/share/applications/alikhlas-pos.desktop"

for package in "$older_package" "$current_package"; do
  if [[ ! -f "$package" ]]; then
    echo "Debian package is missing: $package" >&2
    exit 65
  fi
  if [[ "$(dpkg-deb --field "$package" Package)" != "$package_name" ]]; then
    echo "Unexpected package name: $package" >&2
    exit 66
  fi
done

older_version="$(dpkg-deb --field "$older_package" Version)"
current_version="$(dpkg-deb --field "$current_package" Version)"
if ! dpkg --compare-versions "$older_version" lt "$current_version"; then
  echo "The acceptance package must be older than the current package." >&2
  exit 67
fi

for command in xvfb-run timeout find; do
  if ! command -v "$command" >/dev/null; then
    echo "Required acceptance command is missing: $command" >&2
    exit 68
  fi
done

acceptance_home="$(mktemp -d "${TMPDIR:-/tmp}/alikhlas-linux-install.XXXXXX")"
export HOME="$acceptance_home/home"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_RUNTIME_DIR="$HOME/.runtime"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

installed=false
cleanup() {
  if $installed; then
    sudo dpkg --remove "$package_name" >/dev/null 2>&1 || true
  fi
  rm -rf "$acceptance_home"
}
trap cleanup EXIT

install_package() {
  sudo env DEBIAN_FRONTEND=noninteractive dpkg --install "$1" >/dev/null
  installed=true
}

remove_package() {
  sudo env DEBIAN_FRONTEND=noninteractive dpkg --remove "$package_name" >/dev/null
  installed=false
}

run_smoke_check() {
  local log_file="$acceptance_home/smoke.log"
  set +e
  timeout --kill-after=5s 30s xvfb-run -a \
    "$executable" --installer-smoke-check >"$log_file" 2>&1
  local exit_code=$?
  set -e
  if [[ "$exit_code" -ne 0 ]]; then
    cat "$log_file" >&2
    echo "Installed Linux application smoke check failed: $exit_code" >&2
    exit 69
  fi
}

install_package "$older_package"
[[ -x "$executable" ]]
[[ -f "$desktop_file" ]]
run_smoke_check

database_path="$(find "$XDG_DATA_HOME" -type f -name 'alikhlas_v2.db' -print -quit)"
if [[ -z "$database_path" ]]; then
  echo "Installed application did not create its database." >&2
  exit 70
fi
data_directory="$(dirname "$database_path")"
sentinel="$data_directory/installer-data-sentinel"
printf 'preserve-me\n' >"$sentinel"

install_package "$current_package"
if [[ "$(dpkg-query --show --showformat='${Version}' "$package_name")" != "$current_version" ]]; then
  echo "Package manager did not upgrade to $current_version." >&2
  exit 71
fi
run_smoke_check
[[ -f "$database_path" ]]
grep -Fxq 'preserve-me' "$sentinel"

remove_package
[[ ! -e "$executable" ]]
[[ ! -e "$desktop_file" ]]
[[ -f "$database_path" ]]
grep -Fxq 'preserve-me' "$sentinel"

install_package "$current_package"
run_smoke_check
[[ -f "$database_path" ]]
grep -Fxq 'preserve-me' "$sentinel"

remove_package
[[ ! -e "$executable" ]]
[[ -f "$database_path" ]]
grep -Fxq 'preserve-me' "$sentinel"

printf 'Linux installer acceptance passed: %s -> %s; data survived removal and reinstall.\n' \
  "$older_version" "$current_version"
