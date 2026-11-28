#!/bin/sh
# Chamado por "make setup" e pelo verify, dentro do contêiner. Não usa a rede:
# copia para web/node_modules as dependências instaladas na imagem (/opt/web).
set -eu
cd "$(dirname "$0")/.."
image=/opt/web

if [ ! -f web/package.json ]; then
  echo "setup: ainda não há web/package.json; nada a preparar."
  exit 0
fi

for file in package.json package-lock.json; do
  if ! cmp -s "web/$file" "$image/$file"; then
    echo "setup: web/$file difere da cópia usada na imagem (ou falta)." >&2
    echo "As dependências mudaram; reconstrua a imagem (dc build dev)." >&2
    exit 1
  fi
done

stamp=$(cd "$image" && sha256sum package.json package-lock.json)
if [ -f web/node_modules/.skillquest-stamp ] \
  && [ "$(cat web/node_modules/.skillquest-stamp)" = "$stamp" ]; then
  echo "setup: web/node_modules já está atualizado."
  exit 0
fi

# Monta a cópia nova ao lado e só depois troca, para não misturar com a antiga.
tmp="web/.node_modules.new.$$"
trap 'rm -rf "$tmp"' EXIT
echo "setup: copiando as dependências da imagem para web/node_modules..."
cp -a "$image/node_modules" "$tmp"
printf '%s\n' "$stamp" > "$tmp/.skillquest-stamp"
rm -rf web/node_modules
mv "$tmp" web/node_modules
trap - EXIT
echo "setup: pronto."
