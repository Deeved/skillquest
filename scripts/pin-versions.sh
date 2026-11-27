#!/bin/sh
# Rodado por uma pessoa, no computador com Docker e internet.
# Grava o digest de cada imagem e a versão atual do Claude Code em docker/versions.env.
set -eu
cd "$(dirname "$0")/.."
file=docker/versions.env
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

read_var() { sed -n "s/^$1=//p" "$file"; }

echo "# Gerado por scripts/pin-versions.sh. Revise antes de integrar." > "$tmp"
for name in GO_IMAGE NODE_IMAGE POSTGRES_IMAGE; do
  tag=$(read_var "$name"); tag=${tag%@*}
  digest=$(docker buildx imagetools inspect "$tag" --format '{{.Manifest.Digest}}')
  case $digest in sha256:*) ;; *) echo "Sem digest para $tag" >&2; exit 1 ;; esac
  echo "$name=$tag@$digest" >> "$tmp"
done

version=$(read_var CLAUDE_CODE_VERSION)
if [ -z "$version" ]; then
  node=$(sed -n 's/^NODE_IMAGE=//p' "$tmp")
  version=$(docker run --rm "$node" npm view @anthropic-ai/claude-code version)
fi
[ -n "$version" ] || { echo "Sem versão do Claude Code" >&2; exit 1; }
echo "CLAUDE_CODE_VERSION=$version" >> "$tmp"

cat "$tmp" > "$file"
cat "$file"
