#!/bin/sh
# SPDX-License-Identifier: MIT OR Apache-2.0
set -eu

case "${1-}" in
  '') ;;
  --help|-h)
    printf '%s\n' 'Usage: sh uninstall.sh' 'Set INSTALL_DIR to match the installation directory.'
    exit 0
    ;;
  *) printf '%s\n' 'Usage: sh uninstall.sh' >&2; exit 1 ;;
esac

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
install_dir=${INSTALL_DIR:-"$HOME/.local/bin"}
target=$install_dir/git-etch
sounds_dir=$install_dir/sounds
removed=0

remove() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    rm -- "$1"
    removed=$((removed + 1))
    return 0
  fi
  return 1
}

if remove "$target"; then
  printf 'Removed: %s\n' "$target"
fi
for sound in "$source_dir"/sounds/*.wav; do
  [ -f "$sound" ] || continue
  if remove "$sounds_dir/${sound##*/}"; then
    printf 'Removed: %s\n' "$sounds_dir/${sound##*/}"
  fi
done

if remove "$sounds_dir/pincree-sounds.b64"; then
  printf 'Removed: %s\n' "$sounds_dir/pincree-sounds.b64"
fi
# 一覧が更新されて載らなくなった音声や、取得途中で止まった一時ファイルも消せるように、一覧ではなく名前で探す。
pincree_count=0
for file in "$sounds_dir"/pincree-*.wav "$sounds_dir"/pincree-*.part "$sounds_dir"/pincree-*.clip; do
  if [ -f "$file" ] && remove "$file"; then
    pincree_count=$((pincree_count + 1))
  fi
done
if [ "$pincree_count" -gt 0 ]; then
  printf 'Removed: %s Pincree files from %s\n' "$pincree_count" "$sounds_dir"
fi
rmdir -- "$sounds_dir/.pincree-download.lock" 2>/dev/null || true

# ユーザーが自分で追加した音声が残っていれば、ディレクトリは消さない。
rmdir -- "$sounds_dir" 2>/dev/null || true
[ "$removed" -gt 0 ] || printf 'Not installed: %s\n' "$target"
