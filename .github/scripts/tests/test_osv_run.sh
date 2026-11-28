#!/usr/bin/env bash
# Testes de osv-run.sh com o Docker falso. Não usa rede nem Docker.
set -uo pipefail
aqui=$(cd "$(dirname "$0")" && pwd)
script="$aqui/../osv-run.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/in"

export OSV_RUN_DOCKER="$aqui/fake-docker.sh" FAKE_ARGS="$tmp/args"
export OSV_SCANNER_IMAGE='exemplo.invalid/osv-scanner:v0@sha256:0000000000000000000000000000000000000000000000000000000000000000'
export FAKE_EP='["/osv-scanner"]'
unset GITHUB_STEP_SUMMARY FAKE_JSON FAKE_RC

VAZIO='{"results":[]}'
ACHADO='{"results":[{"source":{"path":"/in/web/package-lock.json"},"packages":[{"package":{"name":"pacote-ficticio","version":"1.0.0"},"vulnerabilities":[{"id":"GHSA-ficticio-0001"}]}]}]}'
# Textos que o executor do Actions leria como comando: "::" no começo (inclusive depois de
# espaços), "##[" em qualquer posição e quebra de linha seguida de "::". Cada um tem um marcador.
INJECAO='{"results":[{"source":{"path":"::error::injetado-origem"},"packages":['\
'{"package":{"name":"::error::injetado-nome","version":"  ::warning::injetado-versao"},"vulnerabilities":[{"id":"##[group]injetado-id"}]},'\
'{"package":{"name":"x##[error]injetado-meio","version":"1"},"vulnerabilities":[{"id":"ID-1"}]},'\
'{"package":{"name":"x\n::error::injetado-quebra","version":"1"},"vulnerabilities":[{"id":"ID-2"}]}]}]}'
# No stderr, o \r é removido; stderr2, stderr3 e stderr4 ficam na mesma linha.
STDERR_INJ=$'::error::injetado-stderr1\n   ::error::injetado-stderr2 ##[error]injetado-stderr3\r::error::injetado-stderr4'

falhas=0
ok() { echo "ok      $1"; }
falha() { echo "FALHOU  $1"; falhas=$((falhas + 1)); }

# caso <descrição> <código esperado> [VAR=valor ...] -- <argumentos do osv-run.sh>
caso() {
  local desc=$1 esperado=$2 vars=()
  shift 2
  while [ "$1" != -- ]; do vars+=("$1"); shift; done
  shift
  : > "$FAKE_ARGS"
  env "${vars[@]}" bash "$script" "$@" > "$tmp/saida" 2>&1
  local rc=$?
  if [ "$rc" -eq "$esperado" ]; then ok "$desc (código $rc)"; else
    falha "$desc: esperado $esperado, veio $rc"; sed 's/^/        /' "$tmp/saida"; fi
}
contem() { if grep -qF -- "$2" "$tmp/saida"; then ok "$1"; else falha "$1: falta '$2'"; fi; }
nao_contem() { if grep -qE -- "$2" "$tmp/saida"; then falha "$1: apareceu '$2'"; else ok "$1"; fi; }
# Confere que cada marcador "injetado-<nome>" aparece e que nenhuma linha com "injetado" tem
# "::" ou "##[" em qualquer posição. Antes da busca, só o prefixo exato do erro emitido pelo
# próprio script é retirado, e só no começo da linha; o resto da linha continua conferido.
PREFIXO_ERRO='::error::OSV-Scanner (teste): '
sem_comando() {  # <descrição> <arquivo> <marcador>...
  local desc=$1 arq=$2 m problema=0
  shift 2
  for m in "$@"; do
    if ! grep -qE -- "injetado-$m([^A-Za-z0-9]|\$)" "$arq"; then
      falha "$desc: falta o marcador injetado-$m"; problema=1
    fi
  done
  # A saída é capturada antes do grep -q: com pipefail, "produtor | grep -q" pode falhar
  # quando o grep encerra cedo e o produtor recebe SIGPIPE.
  local linhas
  linhas=$(grep -F injetado "$arq" | while IFS= read -r linha; do
             printf '%s\n' "${linha#"$PREFIXO_ERRO"}"
           done)
  if grep -qE -e '::' -e '##\[' <<< "$linhas"; then
    falha "$desc: comando do Actions no registro"; grep -F injetado "$arq" | sed 's/^/        /'
    problema=1
  fi
  [ "$problema" -eq 0 ] && ok "$desc"
}
arg_presente() { if grep -qzxF -- "$2" "$FAKE_ARGS"; then ok "$1"; else falha "$1: falta o argumento '$2'"; fi; }
arg_ausente() { if grep -qzE -- "$2" "$FAKE_ARGS"; then falha "$1: apareceu '$2'"; else ok "$1"; fi; }

SRC=(report teste "$tmp/in" "$tmp/out" scan source -L /in/web/package-lock.json)

caso "sem achado" 0 FAKE_RC=0 "FAKE_JSON=$VAZIO" -- "${SRC[@]}"
contem "mensagem sem achado" "nenhuma falha conhecida"
arg_presente "contêiner só leitura" --read-only
arg_presente "sem capacidades" ALL
arg_presente "no-new-privileges" no-new-privileges
arg_presente "entrada só leitura" "$tmp/in:/in:ro"
arg_ausente "sem modo privilegiado" '^--privileged'
arg_ausente "sem socket do Docker" 'docker\.sock'
argumentos=$(tr '\0' ' ' < "$FAKE_ARGS")
if grep -qF -- 'scan source --format json -L' <<< "$argumentos"; then ok "--format json logo depois do subcomando"
else falha "--format json fora do lugar"; fi

caso "achado no modo report não bloqueia" 0 FAKE_RC=1 "FAKE_JSON=$ACHADO" -- "${SRC[@]}"
contem "aviso no modo report" "::warning::"
contem "pacote e ID no resumo" "pacote-ficticio@1.0.0 (/in/web/package-lock.json): GHSA-ficticio-0001"

caso "achado no modo block bloqueia" 1 FAKE_RC=1 "FAKE_JSON=$ACHADO" -- block teste "$tmp/in" "$tmp/out" scan source -L /in/x
contem "erro no modo block" "::error::"

: > "$tmp/resumo"
caso "resumo no GITHUB_STEP_SUMMARY" 0 FAKE_RC=1 "FAKE_JSON=$ACHADO" "GITHUB_STEP_SUMMARY=$tmp/resumo" -- "${SRC[@]}"
if grep -qF GHSA-ficticio-0001 "$tmp/resumo"; then ok "resumo gravado"; else falha "resumo não gravado"; fi

for rc in 2 99 126 127 128 129 130 255; do
  caso "código $rc é erro no modo report" 3 "FAKE_RC=$rc" "FAKE_JSON=$VAZIO" -- "${SRC[@]}"
  contem "mensagem do código $rc" "código $rc"
  caso "código $rc é erro no modo block" 3 "FAKE_RC=$rc" "FAKE_JSON=$VAZIO" -- block teste "$tmp/in" "$tmp/out" scan image --archive /in/x.tar
  contem "mensagem do código $rc (block)" "código $rc"
done

caso "código 0 com JSON ilegível é erro" 3 FAKE_RC=0 "FAKE_JSON=isto nao e json" -- "${SRC[@]}"
contem "mensagem de JSON ilegível" "JSON ilegível"
caso "código 0 sem saída é erro" 3 FAKE_RC=0 FAKE_JSON= -- "${SRC[@]}"
contem "mensagem de relatório ausente" "relatório ausente ou ilegível"
caso "código 1 com JSON sem objeto é erro" 3 FAKE_RC=1 'FAKE_JSON=[]' -- "${SRC[@]}"
contem "mensagem de JSON sem objeto" "JSON sem o objeto esperado"
caso "results inválido é erro" 3 FAKE_RC=0 'FAKE_JSON={"results":"x"}' -- "${SRC[@]}"
contem "mensagem de results inválido" "results"

: > "$tmp/resumo-inj"
caso "textos do relatório e do stderr" 0 FAKE_RC=1 "FAKE_JSON=$INJECAO" "FAKE_STDERR=$STDERR_INJ" \
  "GITHUB_STEP_SUMMARY=$tmp/resumo-inj" -- "${SRC[@]}"
contem "o aviso do próprio script continua inteiro" "::warning::OSV-Scanner (teste): falhas conhecidas"
sem_comando "relatório e stderr não viram comando do Actions" "$tmp/saida" \
  origem nome versao id meio quebra stderr1 stderr2 stderr3 stderr4
sem_comando "resumo do job sem comando do Actions" "$tmp/resumo-inj" \
  origem nome versao id meio quebra

caso "ENTRYPOINT com comando do Actions é erro" 3 'FAKE_EP=["::error::injetado-ep ##[error]injetado-ep2"]' -- "${SRC[@]}"
contem "o erro do próprio script continua inteiro" "::error::OSV-Scanner (teste): ENTRYPOINT inesperado"
sem_comando "ENTRYPOINT não vira comando do Actions" "$tmp/saida" ep ep2

caso "ENTRYPOINT diferente é erro" 3 'FAKE_EP=["/bin/sh"]' FAKE_RC=0 "FAKE_JSON=$VAZIO" -- "${SRC[@]}"
contem "mensagem de ENTRYPOINT" "ENTRYPOINT inesperado"
caso "ENTRYPOINT vazio é erro" 3 'FAKE_EP=null' FAKE_RC=0 "FAKE_JSON=$VAZIO" -- "${SRC[@]}"
caso "ENTRYPOINT com argumentos é erro" 3 'FAKE_EP=["/osv-scanner","scan"]' FAKE_RC=0 "FAKE_JSON=$VAZIO" -- "${SRC[@]}"
caso "imagem não baixada é erro" 3 FAKE_INSPECT_RC=1 -- "${SRC[@]}"
caso "imagem sem digest é erro" 3 'OSV_SCANNER_IMAGE=exemplo.invalid/osv-scanner:v0' -- "${SRC[@]}"
caso "modo inválido é erro" 3 -- relatorio teste "$tmp/in" "$tmp/out" scan source -L /in/x
caso "nome inválido é erro" 3 -- report 'a/b' "$tmp/in" "$tmp/out" scan source -L /in/x
caso "subcomando diferente de scan é erro" 3 -- report teste "$tmp/in" "$tmp/out" fix source -L /in/x
caso "tipo de análise desconhecido é erro" 3 -- report teste "$tmp/in" "$tmp/out" scan outra -L /in/x
caso "pasta de entrada inexistente é erro" 3 -- report teste "$tmp/nao-existe" "$tmp/out" scan source -L /in/x
caso "argumentos faltando é erro" 3 -- report teste

echo
if [ "$falhas" -eq 0 ]; then echo "test_osv_run: todos passaram"; exit 0; fi
echo "test_osv_run: $falhas falha(s)"
exit 1
