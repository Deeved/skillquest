#!/bin/bash
# Chamado por "make dev", dentro do contêiner. Sobe a API (8080) e a web (4200).
# Ctrl+C encerra os dois. Se um deles parar, o outro é encerrado e o script falha.
set -u
cd "$(dirname "$0")/.."

set -m   # cada servidor no seu próprio grupo de processos
(cd api && ADDR=0.0.0.0:8080 exec go run ./cmd/api) </dev/null &
api=$!
(cd web && exec npm start -- --host 0.0.0.0 --port 4200) </dev/null &
web=$!

stop() {
  trap - INT TERM
  # O sinal vai para o grupo inteiro: pega o binário do "go run" e os filhos do npm.
  kill -TERM -- -"$api" -"$web" 2>/dev/null
  wait
}
trap 'stop; exit 130' INT TERM

wait -n
status=$?
echo "Um dos servidores parou (saída $status). Encerrando o outro." >&2
stop
[ "$status" -ne 0 ] || status=1
exit "$status"
