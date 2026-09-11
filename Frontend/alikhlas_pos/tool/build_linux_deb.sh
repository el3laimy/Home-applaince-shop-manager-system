#!/usr/bin/env bash
# Builds a self-contained Debian/Ubuntu x64 installer from Flutter's Linux bundle.
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "Usage: $0 <linux-bundle-dir> <output-dir> <debian-version>" >&2
  exit 64
fi

bundle_dir="$(cd "$1" && pwd -P)"
output_dir="$2"
package_version="$3"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
app_dir="$(cd "$script_dir/.." && pwd -P)"
icon_source="$app_dir/assets/brand/app_icon_256.png"

if [[ ! -x "$bundle_dir/alikhlas_pos" ]]; then
  echo "Linux bundle executable is missing: $bundle_dir/alikhlas_pos" >&2
  exit 65
fi

if [[ ! -f "$icon_source" ]]; then
  echo "Application icon is missing: $icon_source" >&2
  exit 66
fi

if [[ ! "$package_version" =~ ^[0-9][0-9A-Za-z.+:~\-]*$ ]]; then
  echo "Invalid Debian package version: $package_version" >&2
  exit 67
fi

mkdir -p "$output_dir"
package_root="$(mktemp -d "${TMPDIR:-/tmp}/alikhlas-pos-deb.XXXXXX")"
trap 'rm -rf "$package_root"' EXIT

install_root="$package_root/opt/alikhlas-pos"
mkdir -p \
  "$install_root" \
  "$package_root/DEBIAN" \
  "$package_root/usr/share/applications" \
  "$package_root/usr/share/icons/hicolor/256x256/apps"

cp -a "$bundle_dir/." "$install_root/"
install -m 0644 "$icon_source" \
  "$package_root/usr/share/icons/hicolor/256x256/apps/alikhlas-pos.png"

cat > "$package_root/DEBIAN/control" <<EOF
Package: alikhlas-pos
Version: $package_version
Section: office
Priority: optional
Architecture: amd64
Maintainer: ALIkhlasPOS
Depends: libgtk-3-0, libstdc++6, liblzma5
Description: تطبيق إخلاص لإدارة متجر الأجهزة المنزلية
 تطبيق سطح مكتب يعمل دون اتصال لإدارة المبيعات والمخزون والحسابات.
EOF

cat > "$package_root/usr/share/applications/alikhlas-pos.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=إخلاص POS
Name[en]=ALIkhlas POS
Comment=إدارة متجر الأجهزة المنزلية
Comment[en]=Home appliance shop management
Exec=/opt/alikhlas-pos/alikhlas_pos
Icon=alikhlas-pos
Terminal=false
Categories=Office;Finance;
StartupWMClass=alikhlas_pos
EOF

output_file="$output_dir/alikhlas-pos_${package_version}_amd64.deb"
dpkg-deb --build --root-owner-group "$package_root" "$output_file" >/dev/null
printf '%s\n' "$output_file"
