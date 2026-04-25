#!/usr/bin/env bash
#
# voice_to_prompt skill'ini ~/.claude/skills/ altına kurar ve isteğe bağlı
# olarak whisper-tr CLI'ı ~/bin altına yerleştirir.
#
# Kullanım:
#   ./scripts/install.sh                  # skill'i symlink olarak kur
#   ./scripts/install.sh --copy           # symlink yerine kopyala
#   ./scripts/install.sh --with-cli       # whisper-tr'ı da ~/bin altına kur
#   ./scripts/install.sh --with-config    # config örneklerini ~/.config altına kopyala (yok ise)
#   ./scripts/install.sh --all            # skill + cli + config (en hızlı yol)
#   ./scripts/install.sh --uninstall      # skill'i geri al (cli/config'e dokunmaz)
#   ./scripts/install.sh -h | --help      # bu yardımı göster
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"
BIN_SRC="$REPO_ROOT/bin"
CONFIG_SRC="$REPO_ROOT/config"

TARGET_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
TARGET_BIN_DIR="${VOICE_PROMPT_BIN_DIR:-$HOME/bin}"
TARGET_CONFIG_DIR="${WHISPER_TR_CONFIG_DIR:-$HOME/.config/whisper-tr}"

MODE="symlink"
ACTION="install"
WITH_CLI=0
WITH_CONFIG=0

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    -h|--help)      usage; exit 0 ;;
    --copy)         MODE="copy" ;;
    --with-cli)     WITH_CLI=1 ;;
    --with-config)  WITH_CONFIG=1 ;;
    --all)          WITH_CLI=1; WITH_CONFIG=1 ;;
    --uninstall)    ACTION="uninstall" ;;
    *)              echo "Bilinmeyen seçenek: $arg" >&2; usage; exit 2 ;;
  esac
done

install_skill() {
  local src="$SKILLS_SRC/voice-to-prompt"
  local dst="$TARGET_SKILLS_DIR/voice-to-prompt"

  [ ! -f "$src/SKILL.md" ] && { echo "Hata: $src/SKILL.md yok." >&2; exit 1; }

  mkdir -p "$TARGET_SKILLS_DIR"
  if [ -L "$dst" ] || [ -e "$dst" ]; then
    rm -rf "$dst"
  fi

  if [ "$MODE" = "copy" ]; then
    cp -R "$src" "$dst"
    echo "kopyalandı: $dst"
  else
    ln -s "$src" "$dst"
    echo "symlink:    $dst -> $src"
  fi
}

uninstall_skill() {
  local dst="$TARGET_SKILLS_DIR/voice-to-prompt"
  if [ -L "$dst" ] || [ -e "$dst" ]; then
    rm -rf "$dst"
    echo "kaldırıldı: $dst"
  else
    echo "zaten yok:  $dst"
  fi
}

install_cli() {
  local src="$BIN_SRC/whisper-tr"
  local dst="$TARGET_BIN_DIR/whisper-tr"

  [ ! -f "$src" ] && { echo "Hata: $src yok." >&2; exit 1; }

  mkdir -p "$TARGET_BIN_DIR"
  if [ -L "$dst" ] || [ -e "$dst" ]; then
    rm -rf "$dst"
  fi

  if [ "$MODE" = "copy" ]; then
    cp "$src" "$dst"
    chmod +x "$dst"
    echo "kopyalandı: $dst"
  else
    ln -s "$src" "$dst"
    echo "symlink:    $dst -> $src"
  fi

  case ":$PATH:" in
    *":$TARGET_BIN_DIR:"*) ;;
    *) echo "uyarı:      $TARGET_BIN_DIR PATH'te değil — shell rc'nize ekleyin." ;;
  esac
}

install_config() {
  mkdir -p "$TARGET_CONFIG_DIR"
  for name in initial_prompt postproc_dict; do
    local src="$CONFIG_SRC/${name}.example.txt"
    local dst="$TARGET_CONFIG_DIR/${name}.txt"

    [ ! -f "$src" ] && { echo "atlandı:    $src yok." >&2; continue; }

    if [ -e "$dst" ]; then
      echo "var zaten:  $dst (üzerine yazılmadı)"
    else
      cp "$src" "$dst"
      echo "yazıldı:    $dst"
    fi
  done
}

case "$ACTION" in
  install)
    install_skill
    [ $WITH_CLI -eq 1 ] && install_cli
    [ $WITH_CONFIG -eq 1 ] && install_config
    echo
    echo "Tamam. Claude Code'u yeniden başlatıp skill'i test edebilirsiniz."
    if [ $WITH_CLI -eq 0 ]; then
      echo "Not: whisper-tr CLI henüz kurulu değil; bağımlılıkları için:"
      echo "  ./scripts/bootstrap-whisper.sh"
      echo "  ./scripts/install.sh --with-cli --with-config"
    fi
    ;;
  uninstall)
    uninstall_skill
    ;;
esac
