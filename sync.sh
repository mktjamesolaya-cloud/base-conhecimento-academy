#!/usr/bin/env bash
#
# sync.sh — sincronização do projeto base-conhecimento-academy com o GitHub.
#
# Uso:
#   ./sync.sh                              # pull + add + commit (auto) + push
#   ./sync.sh "mensagem do commit"         # idem, com mensagem customizada
#   ./sync.sh --pull                       # só pull (início de sessão)
#   ./sync.sh --status                     # só mostra o estado atual (não modifica nada)
#
# Comportamento:
#   - Sempre faz `git pull --rebase origin main` antes de commitar (evita conflitos bobos).
#   - Se houver mudanças locais, faz commit (mensagem auto se não passada) e push.
#   - Se não houver mudanças, só reporta e sai.
#

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# ---- helpers ---------------------------------------------------------------

cor_verde="\033[0;32m"
cor_amarela="\033[0;33m"
cor_vermelha="\033[0;31m"
cor_reset="\033[0m"

info()  { printf "${cor_verde}[sync]${cor_reset} %s\n" "$*"; }
warn()  { printf "${cor_amarela}[sync]${cor_reset} %s\n" "$*"; }
erro()  { printf "${cor_vermelha}[sync]${cor_reset} %s\n" "$*" >&2; }

verifica_repo() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    erro "este diretório não é um repositório git: $REPO_DIR"
    exit 1
  fi
  if ! git remote get-url origin >/dev/null 2>&1; then
    erro "remote 'origin' não configurado"
    exit 1
  fi
}

mostra_status() {
  info "branch: $(git branch --show-current)"
  info "remote: $(git remote get-url origin)"
  echo ""
  git status --short
  echo ""
  info "últimos commits:"
  git log --oneline -5
}

faz_pull() {
  info "puxando mudanças do origin/main..."
  # --autostash: estasha mudanças não-commitadas antes do rebase e desestasha
  # depois — evita o erro "cannot pull with rebase: You have unstaged changes"
  # quando há edições locais que ainda não foram commitadas.
  if ! git pull --rebase --autostash origin main; then
    erro "git pull falhou — resolva os conflitos manualmente e rode 'git rebase --continue'"
    exit 1
  fi
  info "pull concluído."
}

faz_commit_e_push() {
  local msg="${1:-}"

  # nada a commitar?
  if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    info "nada para commitar — repositório já está limpo."
    return 0
  fi

  info "adicionando mudanças..."
  git add -A

  # gera mensagem automática se não passada
  if [ -z "$msg" ]; then
    local n_arquivos
    n_arquivos=$(git diff --cached --name-only | wc -l | tr -d ' ')
    local data
    data=$(date '+%Y-%m-%d %H:%M')
    msg="sync: $n_arquivos arquivo(s) atualizado(s) em $data"
  fi

  info "commit: $msg"
  git commit -m "$msg"

  info "empurrando para origin/main..."
  if ! git push origin main; then
    erro "git push falhou — verifique sua autenticação (PAT/SSH)"
    exit 1
  fi
  info "sync concluído com sucesso."
}

# ---- entry point -----------------------------------------------------------

verifica_repo

case "${1:-}" in
  --status|-s)
    mostra_status
    ;;
  --pull|-p)
    faz_pull
    ;;
  --help|-h)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    faz_pull
    faz_commit_e_push "${1:-}"
    ;;
esac
