#!/usr/bin/env bash
#
# Setup-Sincronizacao.command
#
# Configura a sincronizacao automatica deste projeto com o GitHub.
# COMO USAR:
#   1. No Finder, da duplo-clique neste arquivo
#   2. Se o macOS bloquear: clica com botao direito > "Abrir" > "Abrir"
#   3. Aguarda a mensagem "agent carregado com sucesso"
#   4. Pode fechar a janela do Terminal
#
# Apos isso, voce pode pedir "sincroniza" ou "puxa do github" no Cowork.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

clear
cat <<'EOF'

  =========================================================
   Setup da Sincronizacao Automatica com GitHub
   base-conhecimento-academy - Jay Academy Online
  =========================================================

  Esse script vai:
    1. Verificar se o repositorio esta OK
    2. Instalar um agente que sincroniza com o GitHub
       automaticamente (quando o Cowork pedir)

  Leva uns 5 segundos. Voce nao precisa digitar nada.

EOF

# --- sanity check ----------------------------------------------------------
if [ ! -f "./tools/sync-agent/install.sh" ]; then
  echo ""
  echo "  ERRO: nao achei ./tools/sync-agent/install.sh"
  echo ""
  echo "  Voce esta rodando esse arquivo da pasta certa?"
  echo "  Ele tem que estar na raiz de 'base-conhecimento-academy'."
  echo ""
  read -r -p "  Pressione Enter pra fechar..."
  exit 1
fi

if [ ! -d ".git" ]; then
  echo ""
  echo "  ERRO: essa pasta nao e um repositorio git."
  echo ""
  echo "  Voce precisa primeiro clonar o repositorio do GitHub."
  echo "  Pede ajuda pro responsavel pelo repo."
  echo ""
  read -r -p "  Pressione Enter pra fechar..."
  exit 1
fi

# --- testa se git push funciona (autenticacao OK) --------------------------
echo "  Verificando se voce ja autenticou no GitHub..."
if ! git ls-remote origin >/dev/null 2>&1; then
  echo ""
  echo "  ATENCAO: nao consegui falar com o GitHub."
  echo ""
  echo "  Pode ser autenticacao (PAT/SSH) ainda nao configurada,"
  echo "  ou voce esta sem internet."
  echo ""
  echo "  Continuo mesmo assim? O agent vai instalar, mas se a"
  echo "  autenticacao nao estiver pronta, sync vai falhar."
  echo ""
  read -r -p "  Continuar? [s/N]: " resposta
  if [[ ! "$resposta" =~ ^[sSyY]$ ]]; then
    echo ""
    echo "  Setup cancelado. Configure a autenticacao do git e tente de novo."
    echo ""
    read -r -p "  Pressione Enter pra fechar..."
    exit 1
  fi
fi
echo "  OK."
echo ""

# --- roda o instalador real ------------------------------------------------
chmod +x ./tools/sync-agent/install.sh
./tools/sync-agent/install.sh

echo ""
echo "  ========================================================="
echo "   Pronto! Sincronizacao configurada nesta maquina."
echo "  ========================================================="
echo ""
echo "  A partir de agora, no Cowork voce pode pedir:"
echo ""
echo "    'sincroniza'    ou 'manda pro github'  -> envia mudancas"
echo "    'puxa do github' ou 'atualiza'          -> traz do time"
echo ""
echo "  Pode fechar essa janela do Terminal."
echo ""
read -r -p "  Pressione Enter pra fechar..."
