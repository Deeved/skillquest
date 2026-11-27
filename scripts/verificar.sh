#!/bin/sh
# Chamado por "make verify". Falha se houver erro ou se não houver o que conferir.
set -eu
cd "$(dirname "$0")/.."

conferir_go() {
  echo "== Go: $1"
  (
    cd "$1"
    fora=$(gofmt -l .)
    [ -z "$fora" ] || { echo "Sem formatação: $fora"; exit 1; }
    go vet ./...
    go test -count=1 ./...
    CGO_ENABLED=0 go build ./...
  )
}

conferir_go docker/rede

produto=0
for pasta in api reviewer; do
  if [ -f "$pasta/go.mod" ]; then conferir_go "$pasta"; produto=1; fi
done
if [ -f web/package.json ]; then
  echo "== Web"
  # Sem --if-present: script ausente deve falhar.
  (cd web && npm run lint && npm test && npm run build)
  produto=1
fi

if [ "$produto" -eq 0 ]; then
  echo "FALHOU: ainda não há código do produto para conferir (T-02)." >&2
  exit 1
fi
echo "Passou. Ainda não são conferidos: contrato, migrações, telas e segurança."
