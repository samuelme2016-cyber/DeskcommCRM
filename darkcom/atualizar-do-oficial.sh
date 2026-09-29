#!/usr/bin/env bash
# Traz para o fork Darkcom a última versão publicada do projeto OFICIAL
# (melgarafael/DeskcommCRM), preservando as mudanças do fork.
#
#   bash darkcom/atualizar-do-oficial.sh            # última release oficial
#   bash darkcom/atualizar-do-oficial.sh v1.70.0    # uma release específica
#
# Mescla a RELEASE oficial (nunca o topo da main dele, que não é testado como
# versão). Se houver conflito, o script PARA e lista os arquivos — resolva (o
# Claude Code faz isso), `git commit` e rode `bash darkcom/conferir-fork.sh`.
# Depois: teste e rode `bash darkcom/publicar-versao.sh "Atualizado para a vX.Y.Z oficial"`.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

command -v gh >/dev/null 2>&1 || export PATH="$PATH:/c/Program Files/GitHub CLI"
OFICIAL_REPO="melgarafael/DeskcommCRM"

[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || { echo "✖ Rode a partir da main."; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "✖ Há alterações sem commit. Faça o commit antes."; git status --short; exit 1; }

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "https://github.com/${OFICIAL_REPO}.git"
# As tags do oficial NÃO entram neste clone: o fork tem numeração própria, e uma
# tag oficial com o mesmo nome de uma nossa apontaria para outro commit.
git config remote.upstream.tagOpt --no-tags

ALVO="${1:-}"
if [ -z "$ALVO" ]; then
  ALVO="$(gh api "repos/${OFICIAL_REPO}/releases/latest" --jq .tag_name)"
fi
ATUAL="$(tr -d ' \r\n' < darkcom/VERSAO-OFICIAL 2>/dev/null || true)"
echo "▶ Versão oficial já mesclada: ${ATUAL:-nenhuma} · alvo: $ALVO"
if [ "$ATUAL" = "$ALVO" ]; then echo "✅ Já está na $ALVO. Nada a fazer."; exit 0; fi

git fetch --quiet origin main
git fetch --quiet --no-tags upstream "refs/tags/${ALVO}"
if ! git merge --no-edit -m "merge: versão oficial ${ALVO}" FETCH_HEAD; then
  echo
  echo "⚠ Conflito ao mesclar a $ALVO. Arquivos em conflito:"
  git diff --name-only --diff-filter=U | sed 's/^/   - /'
  echo
  echo "Resolva (peça ao Claude Code), depois:"
  echo "   echo $ALVO > darkcom/VERSAO-OFICIAL && git add -A && git commit --no-edit"
  echo "   bash darkcom/conferir-fork.sh"
  exit 1
fi

printf '%s\n' "$ALVO" > darkcom/VERSAO-OFICIAL
git add darkcom/VERSAO-OFICIAL
git commit --quiet -m "chore(darkcom): base oficial agora é ${ALVO}"

bash darkcom/conferir-fork.sh
echo
echo "✅ $ALVO mesclada na main local (ainda NÃO enviada ao GitHub)."
echo "   Teste, depois: git push origin main && bash darkcom/publicar-versao.sh \"Atualizado para a ${ALVO} oficial\""
