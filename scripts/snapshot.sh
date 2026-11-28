#!/bin/sh
# Imprime o sha256 de cada arquivo do projeto, para comparar o estado antes e depois.
# Ficam de fora .git e o que o setup e o build geram (node_modules, .angular, dist).
# Uso: sh scripts/snapshot.sh [pasta]   (padrão: a raiz do projeto)
set -eu
cd "${1:-$(dirname "$0")/..}"
find . \( -path ./.git -o -path ./web/node_modules -o -path ./web/.angular -o -path ./web/dist \) -prune \
  -o -type f -print0 | sort -z | xargs -0 -r sha256sum
