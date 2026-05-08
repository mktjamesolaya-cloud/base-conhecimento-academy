#!/usr/bin/env bash
#
# uninstall.sh — remove o launchd agent de sync automático.
#
# Uso:
#   ./tools/sync-agent/uninstall.sh
#

set -euo pipefail

cor_verde="\033[0;32m"
cor_amarela="\033[0;33m"
cor_reset="\033[0m"

info() { printf "${cor_verde}[uninstall]${cor_reset} %s\n" "$*"; }
warn() { printf "${cor_amarela}[uninstall]${cor_reset} %s\n" "$*"; }

LABEL="com.jao.sync-trigger"
PLIST_DEST="$HOME/Library/LaunchAgents/$LABEL.plist"

if launchctl list | grep -q "$LABEL"; then
  info "descarregando agent..."
  launchctl unload "$PLIST_DEST" 2>/dev/null || true
else
  warn "agent não estava carregado."
fi

if [ -f "$PLIST_DEST" ]; then
  info "removendo $PLIST_DEST"
  rm -f "$PLIST_DEST"
else
  warn "plist não encontrado em $PLIST_DEST"
fi

info "pronto. logs antigos ficam em ~/Library/Logs/jao-sync-agent*.log (não removo automaticamente)."
