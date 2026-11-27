#!/bin/sh
# Chamado por "make verify". Falha se houver erro ou se não houver o que conferir.
set -eu
cd "$(dirname "$0")/.."

check_go() {
  echo "== Go: $1"
  (
    cd "$1"
    unformatted=$(gofmt -l .)
    [ -z "$unformatted" ] || { echo "Sem formatação: $unformatted"; exit 1; }
    go vet ./...
    go test -count=1 ./...
    CGO_ENABLED=0 go build ./...
  )
}

check_go docker/gateway

has_product=0
for dir in api reviewer; do
  if [ -f "$dir/go.mod" ]; then check_go "$dir"; has_product=1; fi
done
if [ -f web/package.json ]; then
  echo "== Web"
  # Sem --if-present: script ausente deve falhar.
  (cd web && npm run lint && npm test && npm run build)
  has_product=1
fi

if [ "$has_product" -eq 0 ]; then
  echo "FALHOU: ainda não há código do produto para conferir (T-02)." >&2
  exit 1
fi
echo "Passou. Ainda não são conferidos: contrato, migrações, telas e segurança."
