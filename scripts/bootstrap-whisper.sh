#!/usr/bin/env bash
#
# whisper-tr'ın çalışması için gereken bağımlılıkları kurar:
#   - ffmpeg (Homebrew üzerinden, macOS)
#   - python3 venv (~/.venv-whisper)
#   - openai-whisper + certifi
#   - ~/.config/whisper-tr/{initial_prompt,postproc_dict}.txt (örnek)
#
# Linux için ffmpeg kurulumunu kendi paket yöneticinizle yapmanız gerekir.
#
# Kullanım:
#   ./scripts/bootstrap-whisper.sh
#   ./scripts/bootstrap-whisper.sh --no-config   # config kopyalamayı atla
#   ./scripts/bootstrap-whisper.sh -h | --help
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SRC="$REPO_ROOT/config"

VENV="${WHISPER_TR_VENV:-$HOME/.venv-whisper}"
CONFIG_DIR="${WHISPER_TR_CONFIG_DIR:-$HOME/.config/whisper-tr}"

WITH_CONFIG=1

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    -h|--help)   usage; exit 0 ;;
    --no-config) WITH_CONFIG=0 ;;
    *)           echo "Bilinmeyen seçenek: $arg" >&2; usage; exit 2 ;;
  esac
done

step() { echo; echo "==> $1"; }

step "ffmpeg kontrolü"
if command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg zaten kurulu: $(ffmpeg -version | head -n 1)"
else
  if command -v brew >/dev/null 2>&1; then
    echo "Homebrew ile ffmpeg kuruluyor..."
    brew install ffmpeg
  else
    echo "ffmpeg yok ve Homebrew bulunamadı."
    echo "Linux/Debian:  sudo apt-get install -y ffmpeg"
    echo "Linux/Fedora:  sudo dnf install -y ffmpeg"
    echo "macOS:         https://brew.sh kurun, sonra brew install ffmpeg"
    exit 1
  fi
fi

step "Python venv: $VENV"
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV"
  echo "venv oluşturuldu."
else
  echo "venv zaten var, atlandı."
fi

step "openai-whisper + certifi"
# shellcheck disable=SC1091
source "$VENV/bin/activate"
pip install --upgrade pip
pip install --upgrade openai-whisper certifi
deactivate

if [ "$WITH_CONFIG" -eq 1 ]; then
  step "Config örnekleri: $CONFIG_DIR"
  mkdir -p "$CONFIG_DIR"
  for name in initial_prompt postproc_dict; do
    src="$CONFIG_SRC/${name}.example.txt"
    dst="$CONFIG_DIR/${name}.txt"
    if [ -e "$dst" ]; then
      echo "var zaten:  $dst (üzerine yazılmadı)"
    elif [ -f "$src" ]; then
      cp "$src" "$dst"
      echo "yazıldı:    $dst"
    fi
  done
fi

echo
echo "Hazır. Şimdi:"
echo "  ./scripts/install.sh --with-cli   # whisper-tr'ı ~/bin altına symlink'le"
echo "  whisper-tr --help                 # PATH'te ise çalışmalı"
echo
if [ "$(uname)" = "Darwin" ]; then
  echo "macOS notu: Canlı kayıt (--record) kullanacaksanız Terminal/Claude Code"
  echo "için Mikrofon iznini açtığınızdan emin olun:"
  echo "  System Settings → Privacy & Security → Microphone → (uygulamayı seç)"
fi
