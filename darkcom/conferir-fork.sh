#!/usr/bin/env bash
# Confere que o fork continua apontando para SI MESMO nos pontos que decidem de
# onde a VPS baixa código e imagens. Uma mesclagem do oficial pode trazer de
# volta `melgarafael` nessas linhas — e aí a VPS voltaria a instalar a versão
# oficial por cima das suas mudanças, em silêncio.
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

DONO="$(git config --get remote.origin.url | sed -E 's#^git@github\.com:#https://github.com/#; s#^https?://[^/]+/##; s#/.*##' | tr '[:upper:]' '[:lower:]')"
[ -n "$DONO" ] && [ "$DONO" != "melgarafael" ] || { echo "✖ origin não é um fork (dono: ${DONO:-?})."; exit 1; }

ARQUIVOS=(
  hostgator-setup-kit/_common.sh
  hostgator-setup-kit/install.sh
  hostgator-setup-kit/comecar.sh
  hostgator-setup-kit/diagnostico.sh
  docker-compose.prod.yml
  .env.hostgator.example
  tests/unit/_identidade-deste-repo.ts
)
# Só linhas de código (comentário citando o oficial é inofensivo).
ACHADOS="$(grep -nH -E 'ghcr\.io/melgarafael|github\.com/melgarafael/DeskcommCRM' "${ARQUIVOS[@]}" \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(#|\*|//)' || true)"

if [ -n "$ACHADOS" ]; then
  echo "✖ Estas linhas voltaram a apontar para o oficial — troque 'melgarafael' por '$DONO':"
  printf '%s\n' "$ACHADOS" | sed 's/^/   /'
  exit 1
fi
grep -q "^IMG_NS=\"ghcr.io/${DONO}\"" hostgator-setup-kit/_common.sh \
  || { echo "✖ IMG_NS em hostgator-setup-kit/_common.sh não é ghcr.io/${DONO}"; exit 1; }
echo "✓ fork conferido: imagens em ghcr.io/${DONO}, código de github.com/${DONO}/DeskcommCRM"
