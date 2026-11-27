#!/bin/sh
# Rodado por uma pessoa, no computador com Docker e internet.
# Grava o digest de cada imagem e a versão atual do Claude Code em docker/versoes.env.
set -eu
cd "$(dirname "$0")/.."
arquivo=docker/versoes.env
novo=$(mktemp)
trap 'rm -f "$novo"' EXIT

ler() { sed -n "s/^$1=//p" "$arquivo"; }

echo "# Gerado por scripts/fixar-versoes.sh. Revise antes de integrar." > "$novo"
for nome in GO_IMAGE NODE_IMAGE POSTGRES_IMAGE; do
  etiqueta=$(ler "$nome"); etiqueta=${etiqueta%@*}
  digest=$(docker buildx imagetools inspect "$etiqueta" --format '{{.Manifest.Digest}}')
  case $digest in sha256:*) ;; *) echo "Sem digest para $etiqueta" >&2; exit 1 ;; esac
  echo "$nome=$etiqueta@$digest" >> "$novo"
done

versao=$(ler CLAUDE_CODE_VERSION)
if [ -z "$versao" ]; then
  node=$(sed -n 's/^NODE_IMAGE=//p' "$novo")
  versao=$(docker run --rm "$node" npm view @anthropic-ai/claude-code version)
fi
[ -n "$versao" ] || { echo "Sem versão do Claude Code" >&2; exit 1; }
echo "CLAUDE_CODE_VERSION=$versao" >> "$novo"

cat "$novo" > "$arquivo"
cat "$arquivo"
