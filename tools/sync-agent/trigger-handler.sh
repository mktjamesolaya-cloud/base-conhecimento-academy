#!/usr/bin/env bash
#
# trigger-handler.sh — chamado pelo launchd quando .sync-trigger ou .pull-trigger
# aparecem na raiz do repositório.
#
# Comportamento:
#   - Se .pull-trigger existir → roda `./sync.sh --pull` e apaga o trigger.
#   - Se .sync-trigger existir → lê o conteúdo (mensagem de commit opcional),
#     roda `./sync.sh "msg"` e apaga o trigger.
#   - Tudo logado em ~/Library/Logs/jao-sync-agent.log.
#
# Não chame este script diretamente — ele é disparado pelo launchd.
# Para rodar manualmente, use ./sync.sh na raiz do projeto.
#

set -uo pipefail

REPO_DIR="${REPO_DIR:-$HOME/Downloads/PROJETOS_DEV/assistente-online}"
LOG_FILE="$HOME/Library/Logs/jao-sync-agent.log"
LOCK_DIR="/tmp/jao-sync-agent.lock"

# PATH mínimo para o launchd encontrar git e ferramentas básicas.
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

if [ ! -d "$REPO_DIR" ]; then
  log "ERRO: REPO_DIR não existe: $REPO_DIR"
  exit 1
fi

cd "$REPO_DIR"

# Fast path: o agent é chamado em loop (StartInterval=2s no plist). Na
# imensa maioria das execuções não tem trigger pra processar — saímos
# silenciosamente sem nem pegar lock nem logar, pra não poluir o log.
if [ ! -f .sync-trigger ] && [ ! -f .pull-trigger ]; then
  exit 0
fi

# Tem algo pra processar. Pega o lock (atômico via mkdir).
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "outro handler ainda rodando ($LOCK_DIR existe), pulando essa rodada."
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

# Limpa .git/index.lock órfão — pode acontecer quando uma tentativa anterior
# de git crashou ou foi feita por um processo (ex: sandbox) sem permissão de
# remover o lock. Só removemos se o lock for antigo (>30s), pra não atropelar
# um git em andamento.
if [ -f .git/index.lock ]; then
  lock_age=$(( $(date +%s) - $(stat -f %m .git/index.lock 2>/dev/null || echo 0) ))
  if [ "$lock_age" -gt 30 ]; then
    log "removendo .git/index.lock órfão (idade=${lock_age}s)"
    rm -f .git/index.lock
  fi
fi

PULL_TRIGGER=".pull-trigger"
SYNC_TRIGGER=".sync-trigger"

# 1) pull-trigger primeiro (faz sentido puxar antes de empurrar)
if [ -f "$PULL_TRIGGER" ]; then
  log "─── pull-trigger detectado ───"
  rm -f "$PULL_TRIGGER"
  if ./sync.sh --pull >>"$LOG_FILE" 2>&1; then
    log "pull OK"
  else
    log "pull FALHOU (exit=$?). veja o log acima."
  fi
fi

# 2) sync-trigger (pull + commit + push)
if [ -f "$SYNC_TRIGGER" ]; then
  log "─── sync-trigger detectado ───"
  msg="$(tr -d '\r' < "$SYNC_TRIGGER" | head -n1)"
  rm -f "$SYNC_TRIGGER"

  if [ -z "$msg" ]; then
    log "sem mensagem customizada, sync.sh vai gerar automaticamente"
    if ./sync.sh >>"$LOG_FILE" 2>&1; then
      log "sync OK"
    else
      log "sync FALHOU (exit=$?). veja o log acima."
    fi
  else
    log "mensagem de commit: $msg"
    if ./sync.sh "$msg" >>"$LOG_FILE" 2>&1; then
      log "sync OK"
    else
      log "sync FALHOU (exit=$?). veja o log acima."
    fi
  fi
fi
