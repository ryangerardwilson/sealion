#!/usr/bin/env bash
set -euo pipefail

repo_url="${CARBIDE_REPO_URL:-${SEALION_REPO_URL:-https://github.com/ryangerardwilson/carbide.git}}"
archive_url="${CARBIDE_ARCHIVE_URL:-${SEALION_ARCHIVE_URL:-https://github.com/ryangerardwilson/carbide/archive/refs/heads/main.tar.gz}}"
install_dir="${CARBIDE_HOME:-${SEALION_HOME:-$HOME/.carbide}}"
bin_dir="${CARBIDE_BIN_DIR:-${SEALION_BIN_DIR:-$HOME/.local/bin}}"

command -v go >/dev/null 2>&1 || {
  printf 'install failed: Go is required to build the Carbide CLI\n' >&2
  exit 1
}

mkdir -p "$bin_dir"

if command -v git >/dev/null 2>&1; then
  if [ -d "$install_dir/.git" ]; then
    git -C "$install_dir" pull --ff-only
  else
    rm -rf "$install_dir"
    git clone --depth 1 "$repo_url" "$install_dir"
  fi
else
  command -v curl >/dev/null 2>&1 || {
    printf 'install failed: git or curl is required\n' >&2
    exit 1
  }
  command -v tar >/dev/null 2>&1 || {
    printf 'install failed: tar is required\n' >&2
    exit 1
  }
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT
  curl -fsSL "$archive_url" | tar -xz -C "$tmp_dir" --strip-components=1
  rm -rf "$install_dir"
  mkdir -p "$install_dir"
  cp -R "$tmp_dir/." "$install_dir/"
fi

build_dir="$install_dir/.bin"
mkdir -p "$build_dir"
commit=""
if [ -d "$install_dir/.git" ] && command -v git >/dev/null 2>&1; then
  commit="$(git -C "$install_dir" rev-parse --short HEAD 2>/dev/null || true)"
fi
tmp_bin="$build_dir/carbide.$$"
(
  cd "$install_dir"
  go build -ldflags "-X github.com/ryangerardwilson/carbide/internal/carbide.commit=$commit" -o "$tmp_bin" ./cmd/carbide
)
mv "$tmp_bin" "$build_dir/carbide"
chmod +x "$build_dir/carbide"
chmod +x "$install_dir/bin/carbide"
ln -sfn "$build_dir/carbide" "$bin_dir/carbide"
if [ -L "$bin_dir/sealion" ]; then
  rm -f "$bin_dir/sealion"
fi

printf 'installed carbide to %s\n' "$bin_dir/carbide"
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) printf 'add %s to PATH if carbide is not found\n' "$bin_dir" ;;
esac
