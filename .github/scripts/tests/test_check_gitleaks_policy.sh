#!/usr/bin/env bash
# Testes de check-gitleaks-policy.sh. Não usa rede nem Docker.
set -uo pipefail
aqui=$(cd "$(dirname "$0")" && pwd)
script="$aqui/../check-gitleaks-policy.sh"
falhas=0

caso() {  # <descrição> <código esperado> <caminhos...>
  local desc=$1 esperado=$2 rc
  shift 2
  if [ $# -gt 0 ]; then printf '%s\0' "$@"; fi | bash "$script" > /dev/null 2>&1
  rc=$?
  if [ "$rc" -eq "$esperado" ]; then echo "ok      $desc"
  else echo "FALHOU  $desc: esperado $esperado, veio $rc"; falhas=$((falhas + 1)); fi
}

caso "lista vazia" 0
caso "arquivos comuns" 0 README.md web/package.json "pasta com espaço/arquivo.txt"
caso "nomes parecidos são permitidos" 0 .gitleaks.toml.exemplo docs/gitleaksignore.md
caso ".gitleaks.toml na raiz" 1 README.md .gitleaks.toml
caso ".gitleaks.toml em subpasta" 1 web/src/.gitleaks.toml
caso ".gitleaksignore na raiz" 1 .gitleaksignore
caso ".gitleaksignore em subpasta" 1 api/internal/.gitleaksignore

saida=$(printf '%s\0' $'x/\n::error::injetado/.gitleaksignore' | bash "$script" 2>&1)
if grep -q '^::error::injetado' <<< "$saida"; then
  echo "FALHOU  caminho com quebra de linha virou comando do Actions"; falhas=$((falhas + 1))
else echo "ok      caminho com quebra de linha não vira comando do Actions"; fi

# Caminhos que o executor do Actions leria como comando: "::" no começo, "##[" no meio e
# quebra de linha seguida de "::". Cada marcador precisa aparecer, e nenhuma linha com
# "injetado" pode ter "::" ou "##[" em qualquer posição. Antes da busca, só o prefixo exato
# do erro emitido pelo próprio script é retirado, e só no começo da linha.
PREFIXO_ERRO='::error::Arquivo proibido: '
saida=$(printf '%s\0' '::error::injetado-inicio/.gitleaksignore' 'a##[error]injetado-meio/.gitleaks.toml' \
  $'x/\n::error::injetado-quebra/.gitleaksignore' | bash "$script" 2>&1)
rc=$?
if [ "$rc" -eq 1 ]; then echo "ok      caminhos com comando do Actions continuam proibidos"
else echo "FALHOU  caminhos com comando do Actions: esperado 1, veio $rc"; falhas=$((falhas + 1)); fi
for m in inicio meio quebra; do
  if grep -qE -- "injetado-$m([^A-Za-z0-9]|\$)" <<< "$saida"; then echo "ok      marcador injetado-$m no registro"
  else echo "FALHOU  falta o marcador injetado-$m"; falhas=$((falhas + 1)); fi
done
linhas=$(grep -F injetado <<< "$saida" | while IFS= read -r linha; do
           printf '%s\n' "${linha#"$PREFIXO_ERRO"}"
         done)
if grep -qE -e '::' -e '##\[' <<< "$linhas"; then
  echo "FALHOU  caminho virou comando do Actions:"; sed 's/^/        /' <<< "$saida"; falhas=$((falhas + 1))
else echo "ok      caminhos não viram comando do Actions"; fi
if grep -qF -- "$PREFIXO_ERRO" <<< "$saida"; then echo "ok      o erro do próprio script continua inteiro"
else echo "FALHOU  o erro do próprio script sumiu"; falhas=$((falhas + 1)); fi

echo
if [ "$falhas" -eq 0 ]; then echo "test_check_gitleaks_policy: todos passaram"; exit 0; fi
echo "test_check_gitleaks_policy: $falhas falha(s)"
exit 1
