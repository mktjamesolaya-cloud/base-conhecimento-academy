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

  # Estratégia anti-conflito (pra equipe sem Terminal):
  # 1. Cria uma branch de backup do estado atual ANTES do pull.
  # 2. Tenta `git pull --rebase --autostash`.
  # 3. Se der certo: apaga a branch de backup e segue.
  # 4. Se der conflito: aborta rebase, salva mudanças não-commitadas em stash,
  #    alinha main com origin/main (--hard reset), e deixa a branch de backup
  #    como rede de proteção. Nada se perde — só fica num lugar diferente.

  local backup_branch
  backup_branch="backup/auto-$(date '+%Y%m%d-%H%M%S')"
  # Cria a branch silenciosamente — se falhar (ex: nome duplicado), seguimos
  # mesmo assim. O `|| true` evita que o set -e pare o script.
  git branch "$backup_branch" 2>/dev/null || true

  # --autostash: estasha mudanças não-commitadas antes do rebase e desestasha
  # depois — evita o erro "cannot pull with rebase: You have unstaged changes"
  # quando há edições locais que ainda não foram commitadas.
  if git pull --rebase --autostash origin main; then
    info "pull concluído."
    # Sem conflito: apaga a branch de backup pra não acumular lixo no repo.
    git branch -D "$backup_branch" 2>/dev/null || true
    return 0
  fi

  # --- recuperação automática de conflito ----------------------------------
  warn "houve conflito durante o pull — iniciando recuperação automática..."

  # Aborta qualquer rebase/merge em progresso pra liberar o repo.
  git rebase --abort 2>/dev/null || true
  git merge --abort  2>/dev/null || true

  # Se sobrou alguma mudança não-commitada (autostash não conseguiu
  # restaurar, por exemplo), salva em stash explícito antes do reset.
  if ! (git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]); then
    git stash push -u -m "auto-backup pre-reset $(date '+%Y%m%d-%H%M%S')" 2>/dev/null || true
  fi

  # Alinha main local com o remoto.
  if ! git fetch origin main; then
    erro "git fetch falhou após conflito — verifique conexão e autenticação."
    erro "seu trabalho local está preservado na branch: $backup_branch"
    return 1
  fi
  git reset --hard origin/main

  warn "main local foi alinhado com origin/main."
  warn "seu trabalho anterior foi preservado em:"
  warn "  branch: $backup_branch"
  warn "  stash:  rode 'git stash list' pra ver entradas 'auto-backup'"
  warn ""
  warn "pra recuperar essas mudanças, alguém com acesso ao Terminal precisa fazer merge manual."

  return 0
}

untrack_arquivos_ignorados() {
  # Remove do tracking arquivos que estão no .gitignore mas que já estão
  # commitados (caso comum: alguém adicionou uma pasta ao .gitignore depois
  # de já ter commitado arquivos dela).
  #
  # `git ls-files --cached --ignored --exclude-standard` lista exatamente
  # esses arquivos. Se a saída for vazia, xargs com -r não roda nada.
  #
  # Idempotente: depois da primeira execução vira no-op.
  local ignorados
  ignorados=$(git ls-files --cached --ignored --exclude-standard 2>/dev/null || true)
  if [ -n "$ignorados" ]; then
    local n
    n=$(printf '%s\n' "$ignorados" | wc -l | tr -d ' ')
    info "removendo $n arquivo(s) trackeado(s) que agora estão no .gitignore..."
    # Usa -z + xargs -0 pra lidar com nomes com espaços/unicode.
    git ls-files --cached --ignored --exclude-standard -z | \
      xargs -0 -r git rm --cached --quiet
  fi
}

faz_commit_e_push() {
  local msg="${1:-}"

  # Limpa arquivos trackeados que viraram ignorados (one-shot, idempotente).
  untrack_arquivos_ignorados

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
