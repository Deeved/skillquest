#!/usr/bin/env bash
# Testes das funções de gitleaks-selftest.sh com o Docker falso. Não usa rede nem Docker.
# Conferem a classificação dos códigos, o resumo sem o valor, as opções passadas ao
# contêiner e o isolamento do histórico. A detecção real fica com o autoteste no CI.
set -uo pipefail
aqui=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../gitleaks-selftest.sh
. "$aqui/../gitleaks-selftest.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GITLEAKS_RUN_DOCKER="$aqui/fake-docker.sh" FAKE_ARGS="$tmp/args"
docker_cmd=$GITLEAKS_RUN_DOCKER
export GITLEAKS_IMAGE='exemplo.invalid/gitleaks:v0@sha256:0000000000000000000000000000000000000000000000000000000000000000'
export FAKE_EP='["gitleaks"]'
unset FAKE_RC_GIT FAKE_RC_DIR FAKE_REPORT_GIT FAKE_REPORT_DIR FAKE_NO_REPORT FAKE_SNAP

# Valor de teste que não pode aparecer no registro. Não tem formato de credencial.
OCULTO='VALOR-QUE-NAO-PODE-APARECER'
ACHADO='[{"RuleID":"regra-ficticia","File":"a.txt","StartLine":3,"Commit":"abc123","Secret":"'$OCULTO'","Match":"'$OCULTO'"}]'

falhas=0
ok() { echo "ok      $1"; }
falha() { echo "FALHOU  $1"; falhas=$((falhas + 1)); }
espera() {  # <descrição> <esperado> <obtido>
  if [ "$2" = "$3" ]; then ok "$1 (código $3)"; else falha "$1: esperado $2, veio $3"; sed 's/^/        /' "$tmp/saida"; fi
}
mkdir "$tmp/src" "$tmp/out"

run_gl() {  # <git|dir> [VAR=valor ...]
  local modo=$1
  shift
  : > "$FAKE_ARGS"
  (export "$@"; gl_run "$modo" "$tmp/src" relatorio "$tmp/out") > "$tmp/saida" 2>&1
}

# Imagem
(GITLEAKS_IMAGE=exemplo.invalid/gitleaks:v0 conferir_imagem) > "$tmp/saida" 2>&1; espera "imagem sem digest é erro" 3 $?
(FAKE_EP='["/bin/sh"]' conferir_imagem) > "$tmp/saida" 2>&1; espera "ENTRYPOINT diferente é erro" 3 $?
(FAKE_INSPECT_RC=1 conferir_imagem) > "$tmp/saida" 2>&1; espera "imagem não baixada é erro" 3 $?
(conferir_imagem) > "$tmp/saida" 2>&1; espera "ENTRYPOINT gitleaks aceito" 0 $?
(FAKE_EP='["/usr/bin/gitleaks"]' conferir_imagem) > "$tmp/saida" 2>&1; espera "ENTRYPOINT com caminho aceito" 0 $?

# Códigos
run_gl git FAKE_RC_GIT=0 'FAKE_REPORT_GIT=[]'; espera "0 com relatório vazio" 0 $?
run_gl git FAKE_RC_GIT=99 "FAKE_REPORT_GIT=$ACHADO"; espera "99 é achado" 1 $?
if grep -qF 'regra=regra-ficticia arquivo=a.txt linha=3 commit=abc123' "$tmp/saida"; then ok "resumo com regra, arquivo, linha e commit"
else falha "resumo incompleto"; fi
if grep -qF "$OCULTO" "$tmp/saida"; then falha "Secret ou Match apareceu no registro"; else ok "Secret e Match fora do registro"; fi
for rc in 1 2 126 137; do
  run_gl git "FAKE_RC_GIT=$rc" 'FAKE_REPORT_GIT=[]'; espera "código $rc é erro" 3 $?
done
run_gl git FAKE_RC_GIT=0 FAKE_NO_REPORT=1; espera "0 sem relatório é erro" 3 $?
run_gl git FAKE_RC_GIT=0 "FAKE_REPORT_GIT=$ACHADO"; espera "0 com achados no relatório é erro" 3 $?
run_gl git FAKE_RC_GIT=99 'FAKE_REPORT_GIT=[]'; espera "99 com relatório vazio é erro" 3 $?
run_gl git FAKE_RC_GIT=99 'FAKE_REPORT_GIT=nao e json'; espera "99 com relatório ilegível é erro" 3 $?
run_gl git FAKE_RC_GIT=99 'FAKE_REPORT_GIT={}'; espera "relatório que não é lista é erro" 3 $?
run_gl git FAKE_RC_GIT=99 'FAKE_REPORT_GIT=[{"RuleID":"r","File":"x\n::error::injetado","StartLine":1}]'; espera "arquivo com quebra de linha" 1 $?
if grep -q '^::error::injetado' "$tmp/saida"; then falha "nome de arquivo virou comando do Actions"; else ok "nome de arquivo não vira comando do Actions"; fi

# Textos que o executor do Actions leria como comando, com um marcador em cada um. Todo marcador
# precisa aparecer, e nenhuma linha com "injetado" pode ter "::" ou "##[" em qualquer posição.
# Antes da busca, só o prefixo exato do erro emitido pelo próprio script é retirado, e só no
# começo da linha.
PREFIXO_ERRO='::error::Gitleaks: '
sem_comando() {  # <descrição> <marcador>...
  local desc=$1 m linhas problema=0
  shift
  for m in "$@"; do
    if ! grep -qE -- "injetado-$m([^A-Za-z0-9]|\$)" "$tmp/saida"; then
      falha "$desc: falta o marcador injetado-$m"; problema=1
    fi
  done
  linhas=$(grep -F injetado "$tmp/saida" | while IFS= read -r linha; do
             printf '%s\n' "${linha#"$PREFIXO_ERRO"}"
           done)
  if grep -qE -e '::' -e '##\[' <<< "$linhas"; then
    falha "$desc: comando do Actions no registro"; sed 's/^/        /' "$tmp/saida"; problema=1
  fi
  [ "$problema" -eq 0 ] && ok "$desc"
}
INJ='[{"RuleID":"x##[error]injetado-regra","File":"::error::injetado-arquivo","StartLine":"  ::warning::injetado-linha","Commit":"a\n::error::injetado-commit"}]'
STDERR_INJ=$'::error::injetado-stderr1\n   ::error::injetado-stderr2 ##[error]injetado-stderr3'
run_gl git FAKE_RC_GIT=99 "FAKE_REPORT_GIT=$INJ" "FAKE_STDERR=$STDERR_INJ"; espera "relatório e stderr com comando do Actions" 1 $?
sem_comando "relatório e stderr do Gitleaks não viram comando do Actions" regra arquivo linha commit stderr1 stderr2 stderr3
(FAKE_EP='["::error::injetado-ep ##[error]injetado-ep2"]' conferir_imagem) > "$tmp/saida" 2>&1
espera "ENTRYPOINT com comando do Actions é erro" 3 $?
if grep -qF -- "${PREFIXO_ERRO}ENTRYPOINT inesperado" "$tmp/saida"; then ok "o erro do próprio script continua inteiro"
else falha "o erro do próprio script sumiu"; fi
sem_comando "ENTRYPOINT não vira comando do Actions" ep ep2

# Opções passadas ao contêiner
run_gl git FAKE_RC_GIT=0 'FAKE_REPORT_GIT=[]'
for a in --network none --read-only ALL no-new-privileges --no-banner --redact --exit-code 99 \
  --ignore-gitleaks-allow "$tmp/src:/src:ro" '--log-opts=--full-history --diff-filter=tuxdb scan' /tmp; do
  if grep -qzxF -- "$a" "$FAKE_ARGS"; then ok "git: argumento '$a'"; else falha "git: falta o argumento '$a'"; fi
done
if grep -qzE -- '^(--privileged|.*docker\.sock.*|.*GITLEAKS_CONFIG.*)$' "$FAKE_ARGS"; then falha "argumento proibido"; else ok "sem --privileged, socket ou GITLEAKS_CONFIG"; fi
run_gl dir FAKE_RC_DIR=0 'FAKE_REPORT_DIR=[]'
if grep -qzE -- '^--log-opts' "$FAKE_ARGS"; then falha "dir não deveria ter --log-opts"; else ok "dir sem --log-opts"; fi

# Isolamento: a origem tem o branch "outro"; a análise só vê o HEAD.
orig="$tmp/origem"
g() { git -C "$orig" -c user.name=teste -c user.email=teste@example.invalid -c commit.gpgsign=false "$@"; }
git init -q -b main "$orig"
printf 'limpo\n' > "$orig/LEIA.txt"
printf 'LEIA.txt export-ignore\n' > "$orig/.gitattributes"
g add LEIA.txt .gitattributes && g commit -q -m 'commit-do-main'
g switch -q -c outro
printf 'conteudo do outro branch\n' > "$orig/arquivo-do-outro.txt"
g add arquivo-do-outro.txt && g commit -q -m 'commit-do-outro'
g switch -q main

snap() { rm -rf "$tmp/snap"; (export FAKE_SNAP="$tmp/snap"; analisar "$orig" "$tmp/out-analise") > "$tmp/saida" 2>&1; }
snap; espera "análise com HEAD em main" 0 $?
if [ "$(cat "$tmp/snap/refs.txt")" = refs/heads/scan ]; then ok "repositório isolado só com refs/heads/scan"
else falha "refs no repositório isolado: $(tr '\n' ' ' < "$tmp/snap/refs.txt")"; fi
if grep -qx commit-do-outro "$tmp/snap/log.txt"; then falha "o commit do outro branch entrou no histórico"
else ok "o commit do outro branch não entrou, nem com --all"; fi
if grep -qx commit-do-main "$tmp/snap/log.txt"; then ok "o commit de HEAD entrou"; else falha "o commit de HEAD não entrou"; fi
if grep -qx ./LEIA.txt "$tmp/snap/dir.txt"; then ok "export-ignore não esconde arquivo"; else falha "LEIA.txt sumiu da extração"; fi
if grep -qE '^\./\.git(/|$)' "$tmp/snap/dir.txt"; then falha ".git na extração"; else ok "extração sem .git"; fi
if grep -qx ./arquivo-do-outro.txt "$tmp/snap/dir.txt"; then falha "arquivo do outro branch na extração"; else ok "arquivo do outro branch fora da extração"; fi

g switch -q outro
snap; espera "análise com HEAD em outro" 0 $?
if grep -qx commit-do-outro "$tmp/snap/log.txt" && grep -qx ./arquivo-do-outro.txt "$tmp/snap/dir.txt"; then
  ok "controle: com HEAD em outro, o commit e o arquivo entram"
else falha "controle: o commit ou o arquivo do HEAD não entraram"; fi

# Segredo fictício: este script não contém o padrão; o conteúdo gerado contém.
padrao='-----BEGIN[ A-Z0-9_-]{0,100}PRIVATE KEY'
if grep -qE -- "$padrao" "$aqui/../gitleaks-selftest.sh"; then falha "o script contém o padrão do segredo"
else ok "o script não contém o padrão do segredo"; fi
conteudo_ficticio TESTE > "$tmp/ficticio.txt"
if grep -qE -- "$padrao" "$tmp/ficticio.txt" && grep -q FICTICIO "$tmp/ficticio.txt"; then
  ok "conteúdo gerado tem o formato e a marca de fictício"
else falha "conteúdo gerado sem o formato ou sem a marca"; fi

echo
if [ "$falhas" -eq 0 ]; then echo "test_gitleaks_selftest: todos passaram"; exit 0; fi
echo "test_gitleaks_selftest: $falhas falha(s)"
exit 1
