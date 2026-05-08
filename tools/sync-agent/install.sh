#!/usr/bin/env bash
#
# install.sh — instala o launchd agent que dispara sync.sh quando arquivos
# .sync-trigger ou .pull-trigger aparecem na raiz do repo.
#
# Uso (a partir da raiz do projeto):
#   ./tools/sync-agent/install.sh
#
# Idempotente: pode rodar de novo sem quebrar (descarrega o agent antigo antes).
#

set -euo pipefail

cor_verde="\033[0;32m"
cor_amarela="\033[0;33m"
cor_vermelha="\033[0;31m"
cor_reset="\033[0m"

info() { printf "${cor_verde}[install]${cor_reset} %s\n" "$*"; }
warn() { printf "${cor_amarela}[install]${cor_reset} %s\n" "$*"; }
erro() { printf "${cor_vermelha}[install]${cor_reset} %s\n" "$*" >&2; }

# Caminho da raiz do repositório (o pai do diretório onde este script vive).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LABEL="com.jao.sync-trigger"
PLIST_TMPL="$SCRIPT_DIR/$LABEL.plist.tmpl"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$LABEL.plist"

# ---- sanity checks ---------------------------------------------------------

if [ ! -f "$PLIST_TMPL" ]; then
  erro "template não encontrado: $PLIST_TMPL"
  exit 1
fi

if [ ! -f "$REPO_DIR/sync.sh" ]; then
  erro "sync.sh não encontrado em $REPO_DIR — está rodando o install do lugar certo?"
  exit 1
fi

if [ ! -d "$REPO_DIR/.git" ]; then
  erro "$REPO_DIR não é um repo git — abortando."
  exit 1
fi

# ---- prepara permissões ----------------------------------------------------

chmod +x "$REPO_DIR/sync.sh"
chmod +x "$SCRIPT_DIR/trigger-handler.sh"
chmod +x "$SCRIPT_DIR/uninstall.sh" 2>/dev/null || true

mkdir -p "$LAUNCH_AGENTS_DIR"
mkdir -p "$HOME/Library/Logs"

# ---- descarrega versão antiga, se existir ----------------------------------

if launchctl list | grep -q "$LABEL"; then
  info "descarregando versão anterior do agent..."
  launchctl unload "$PLIST_DEST" 2>/dev/null || true
fi

# ---- gera plist a partir do template ---------------------------------------

info "gerando $PLIST_DEST"
# Usamos um delimitador alternativo no sed porque REPO_DIR pode conter '/'.
# Escapa & e | só por segurança (não esperamos que apareçam em path normal).
escape_sed() {
  printf '%s' "$1" | sed -e 's/[&|]/\\&/g'
}
REPO_DIR_ESC="$(escape_sed "$REPO_DIR")"
HOME_ESC="$(escape_sed "$HOME")"

sed \
  -e "s|__REPO_DIR__|$REPO_DIR_ESC|g" \
  -e "s|__HOME__|$HOME_ESC|g" \
  "$PLIST_TMPL" > "$PLIST_DEST"

# Valida que o plist é XML válido.
if ! plutil -lint "$PLIST_DEST" >/dev/null 2>&1; then
  erro "plist gerado é inválido. Conteúdo:"
  cat "$PLIST_DEST" >&2
  rm -f "$PLIST_DEST"
  exit 1
fi

# ---- carrega o agent -------------------------------------------------------

info "carregando o agent no launchd..."
launchctl load "$PLIST_DEST"

# ---- confirma --------------------------------------------------------------

if launchctl list | grep -q "$LABEL"; then
  info "agent carregado com sucesso."
  echo ""
  info "como testar:"
  echo "  echo 'teste de sync' > '$REPO_DIR/.sync-trigger'"
  echo ""
  info "logs: ~/Library/Logs/jao-sync-agent.log"
  info "para desinstalar: $SCRIPT_DIR/uninstall.sh"
else
  erro "algo deu errado — agent não aparece em 'launchctl list'."
  erro "veja $HOME/Library/Logs/jao-sync-agent.stderr.log"
  exit 1
fi
