#!/usr/bin/env bash
# Publica uma versão NOVA do fork Darkcom — é o que faz a VPS enxergar as mudanças.
#
#   bash darkcom/publicar-versao.sh "O que mudou, em uma frase"
#   bash darkcom/publicar-versao.sh "O que mudou" v1.70.1   # número escolhido à mão
#
# O que acontece, em ordem:
#   1. confere que a `main` está limpa e igual à do GitHub;
#   2. calcula o número: patch+1 sobre o MAIOR entre a última versão do fork e a
#      versão oficial já mesclada (darkcom/VERSAO-OFICIAL);
#   3. escreve a seção da versão no CHANGELOG.md (é o que a tela "Atualizar" mostra);
#   4. commit + push + release no GitHub → o robô `publish-image.yml` compila as
#      imagens em ghcr.io/<você>/… e move o canal `stable` quando as 3 sobem;
#   5. a VPS passa a oferecer a versão no botão "Nova versão" (em até 5 min
#      depois que as imagens ficam prontas — o build leva ~15-25 min).
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

command -v gh >/dev/null 2>&1 || export PATH="$PATH:/c/Program Files/GitHub CLI"
command -v gh >/dev/null 2>&1 || { echo "✖ GitHub CLI (gh) não encontrado."; exit 1; }

DESCRICAO="${1:-}"
VERSAO="${2:-}"
[ -n "$DESCRICAO" ] || { echo "✖ Diga o que mudou: bash darkcom/publicar-versao.sh \"descrição\""; exit 1; }

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
case "$REPO" in
  melgarafael/*) echo "✖ Este clone aponta para o projeto OFICIAL ($REPO), não para o fork."; exit 1 ;;
esac

# ── 1. main limpa e em dia ──────────────────────────────────────────────────
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || { echo "✖ Publique a partir da main (está em $(git rev-parse --abbrev-ref HEAD))."; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "✖ Há alterações sem commit. Faça o commit antes de publicar."; git status --short; exit 1; }
git fetch --quiet origin main
if [ "$(git rev-list --count HEAD..origin/main)" != "0" ]; then
  echo "✖ O GitHub tem commits que este PC não tem. Rode: git pull --ff-only origin main"; exit 1
fi

# ── 2. número da versão ─────────────────────────────────────────────────────
maior() { printf '%s\n%s\n' "$1" "$2" | sed '/^$/d' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1; }
if [ -z "$VERSAO" ]; then
  ULTIMA_FORK="$(gh release list -R "$REPO" --exclude-drafts --exclude-pre-releases --limit 1 --json tagName -q '.[0].tagName // ""' | sed 's/^v//')"
  OFICIAL="$(tr -d ' \r\n' < darkcom/VERSAO-OFICIAL 2>/dev/null | sed 's/^v//')"
  BASE="$(maior "$ULTIMA_FORK" "$OFICIAL")"
  [ -n "$BASE" ] || BASE="0.0.0"
  IFS=. read -r MA MI PA <<<"$BASE"
  VERSAO="v${MA}.${MI}.$((PA + 1))"
fi
case "$VERSAO" in v[0-9]*.[0-9]*.[0-9]*) ;; *) echo "✖ Versão inválida: $VERSAO (use vX.Y.Z)"; exit 1 ;; esac
case "$VERSAO" in *-*) echo "✖ Sem sufixo com hífen: o instalador ignora versões assim."; exit 1 ;; esac
git ls-remote --exit-code --tags origin "refs/tags/$VERSAO" >/dev/null 2>&1 && { echo "✖ $VERSAO já existe no fork."; exit 1; }

echo "▶ Publicando $VERSAO em $REPO"
echo "  $DESCRICAO"

# ── 3. CHANGELOG ────────────────────────────────────────────────────────────
HOJE="$(date +%F)"
SECAO="## [${VERSAO#v}] — ${HOJE}\n\n### Darkcom\n\n- ${DESCRICAO}\n"
awk -v secao="$SECAO" '
  !feito && /^## \[[0-9]/ { printf "%s\n", secao; feito=1 }
  { print }
' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md

# ── 4. commit, push, release ────────────────────────────────────────────────
git add CHANGELOG.md
git commit --quiet -m "release(${VERSAO#v}): ${DESCRICAO}"
git push --quiet origin main
gh release create "$VERSAO" -R "$REPO" --target main --title "$VERSAO" --notes "$DESCRICAO" >/dev/null

echo "✅ Release $VERSAO criada: https://github.com/$REPO/releases/tag/$VERSAO"
echo "   Compilação das imagens (15-25 min): https://github.com/$REPO/actions/workflows/publish-image.yml"
echo "   Quando terminar verde, a VPS oferece a versão em 'Nova versão' (ou: bash hostgator-setup-kit/update.sh)."
