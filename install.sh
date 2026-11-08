#!/bin/sh
# SPDX-License-Identifier: MIT OR Apache-2.0
set -eu

usage() {
  printf '%s\n' \
    'Usage: sh install.sh         Install git-etch' \
    '       sh install.sh sounds  Download all missing Pincree voice samples now' \
    'Set INSTALL_DIR to override ~/.local/bin.'
}

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
install_dir=${INSTALL_DIR:-"$HOME/.local/bin"}
target=$install_dir/git-etch
sounds_dir=$install_dir/sounds
# Pincree のガイドラインは素材ファイルの再配布を禁じているので、リポジトリには同梱せず、ユーザーの環境で公式サーバーから取得する。
# 同意を得たら一覧をインストール先にコピーし、git-etch はそれがあるときだけ取得する。
pincree_sounds_b64=$sounds_dir/pincree-sounds.b64
download_timeout=60

# 以下の Pincree の取得処理は bin/git-etch にも同じものがある。直すときは両方そろえる。

# 1行に「バイト数 URL」を出力する。デコード後の JSON Lines はキーの順序に頼らずに読む。
pincree_entries() {
  {
    base64 -d <"$pincree_sounds_b64" 2>/dev/null ||
      base64 -D <"$pincree_sounds_b64" 2>/dev/null ||
      openssl base64 -d <"$pincree_sounds_b64" 2>/dev/null
  } | awk '{
    url = ""; bytes = ""
    if (match($0, /"url"[ \t]*:[ \t]*"[^"]*"/)) {
      url = substr($0, RSTART, RLENGTH); sub(/^"url"[ \t]*:[ \t]*"/, "", url); sub(/"$/, "", url)
    }
    if (match($0, /"bytes"[ \t]*:[ \t]*[0-9]+/)) {
      bytes = substr($0, RSTART, RLENGTH); sub(/^"bytes"[ \t]*:[ \t]*/, "", bytes)
    }
    if (url != "" && bytes != "") print bytes, url
  }'
}

read_bytes() {
  dd if="$1" bs=1 skip="$2" count="$3" 2>/dev/null
}

write_le32() {
  value=$3
  bytes=$(printf '\\%03o\\%03o\\%03o\\%03o' \
    $((value & 255)) $((value >> 8 & 255)) $((value >> 16 & 255)) $((value >> 24 & 255)))
  # shellcheck disable=SC2059 # 書式文字列は、直前で組み立てた8進エスケープそのもの。
  printf "$bytes" | dd of="$1" bs=1 seek="$2" count=4 conv=notrunc 2>/dev/null
}

# 先頭から JSON Lines の bytes の分 (ヘッダと約3秒の音声) だけを取得し、切り詰めたファイルも正しい WAV として読めるように RIFF チャンクと data チャンクのサイズを書き換える。
fetch_pincree_clip() {
  clip_bytes=$1
  url=$2
  out=$sounds_dir/pincree-${url##*/}
  raw=$out.$$.part
  clip=$out.$$.clip
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 5 --max-time "$download_timeout" -r "0-$((clip_bytes - 1))" -o "$raw" "$url"
  else
    wget -q -T "$download_timeout" --header="Range: bytes=0-$((clip_bytes - 1))" -O "$raw" "$url"
  fi || { rm -f -- "$raw"; return 1; }
  # サーバーが Range を無視してファイル全体を返した場合も、ここで切り詰められる。
  dd if="$raw" of="$clip" bs="$clip_bytes" count=1 2>/dev/null
  rm -f -- "$raw"
  if [ "$(wc -c <"$clip" | tr -d ' ')" -ne "$clip_bytes" ] ||
     [ "$(read_bytes "$clip" 0 4)" != RIFF ] ||
     [ "$(read_bytes "$clip" 8 4)" != WAVE ] ||
     [ "$(read_bytes "$clip" 36 4)" != data ]; then
    rm -f -- "$clip"
    return 1
  fi
  write_le32 "$clip" 4 $((clip_bytes - 8))
  write_le32 "$clip" 40 $((clip_bytes - 44))
  mv -- "$clip" "$out"
}

confirm() {
  printf '%s [Y/n] ' "$1"
  # 入力が無い (非対話で stdin が空) ときは、年齢確認と同意を勝手に通さないように「いいえ」として扱う。
  if ! read -r answer; then
    printf '\n'
    return 1
  fi
  case "$answer" in
    ''|y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

enable_pincree_sounds() {
  printf '\n'
  printf '%s\n' \
    'git-etch can download voice samples from Pincree (https://pincree.jp/).' \
    'They are fetched from the official server; this repository does not ship them.' \
    'Pincree requires users to be 18 or older and to follow its guidelines:' \
    '  https://pincree.jp/en/guidelines' \
    'Do not redistribute the downloaded files.'
  if ! confirm 'Download the Pincree voice samples?' ||
     ! confirm 'Are you 18 or older?' ||
     ! confirm 'Do you agree to the Pincree guidelines?'; then
    printf '%s\n' 'Skipped Pincree samples. Run "sh install.sh sounds" to download them later.'
    return 1
  fi
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    printf '%s\n' 'Neither curl nor wget was found; skipped Pincree samples.' >&2
    return 1
  fi
  mkdir -p -- "$sounds_dir"
  cp -- "$source_dir/pincree-sounds.b64" "$pincree_sounds_b64"
  printf '%s\n' 'Voice samples: 音声素材_Pincree (https://pincree.jp/)'
}

download_all_pincree_sounds() {
  if ! entries=$(pincree_entries) || [ -z "$entries" ]; then
    printf 'Could not decode %s; skipped Pincree samples.\n' "$pincree_sounds_b64" >&2
    return 0
  fi
  fetched=0
  cached=0
  failed=0
  total=$(printf '%s\n' "$entries" | wc -l | tr -d ' ')
  current=0
  while read -r clip_bytes url; do
    current=$((current + 1))
    if [ -f "$sounds_dir/pincree-${url##*/}" ]; then
      cached=$((cached + 1))
      continue
    fi
    # 配布元に負荷をかけないようにリクエストの間を空ける。
    [ "$((fetched + failed))" -eq 0 ] || sleep 1
    printf '\r  Downloading %s/%s ' "$current" "$total"
    if fetch_pincree_clip "$clip_bytes" "$url"; then
      fetched=$((fetched + 1))
    else
      failed=$((failed + 1))
    fi
  done <<EOF
$entries
EOF
  printf '\rPincree samples: %s downloaded, %s already present, %s failed.\n' "$fetched" "$cached" "$failed"
}

install() {
  if [ -e "$target" ] || [ -L "$target" ]; then
    printf 'Refusing to overwrite existing file: %s\n' "$target" >&2
    printf '%s\n' 'Run "sh uninstall.sh" first, then run this script again.' >&2
    exit 1
  fi

  mkdir -p -- "$sounds_dir"
  cp -- "$source_dir/bin/git-etch" "$target"
  chmod 755 "$target"
  for sound in "$source_dir"/sounds/*.wav; do
    [ -f "$sound" ] || continue
    cp -- "$sound" "$sounds_dir/"
  done
  printf 'Installed: %s\n' "$target"

  if enable_pincree_sounds; then
    printf '%s\n' \
      'When "git etch" picks a sample that is not downloaded yet, it downloads that one before playing.' \
      'Run "sh install.sh sounds" to download all of them at once.'
  fi

  case ":$PATH:" in
    *":$install_dir:"*) printf '\n%s\n' 'Try: git etch origin' ;;
    *)
      printf '\n%s\n' 'Add the installation directory to PATH in your shell configuration:'
      printf '  export PATH="%s:$PATH"\n' "$install_dir"
      ;;
  esac
}

download_sounds() {
  if [ ! -e "$target" ]; then
    printf 'Not installed: %s\n' "$target" >&2
    exit 1
  fi
  if [ -f "$pincree_sounds_b64" ]; then
    # 同意済みなら聞き直さず、一覧だけリポジトリの最新に差し替える。
    cp -- "$source_dir/pincree-sounds.b64" "$pincree_sounds_b64"
  elif ! enable_pincree_sounds; then
    return 0
  fi
  download_all_pincree_sounds
}

case "${1-}" in
  '') install ;;
  sounds) download_sounds ;;
  --help|-h) usage ;;
  *) usage >&2; exit 1 ;;
esac
