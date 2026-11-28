#!/usr/bin/env bash
# Gitleaks do CI. A análise do pedido de integração e o autoteste usam as mesmas funções.
#
#   gitleaks-selftest.sh scan <repositório>  arquivos de HEAD e histórico alcançável por HEAD
#   gitleaks-selftest.sh selftest            autoteste num repositório temporário
#   gitleaks-selftest.sh fake                imprime um segredo fictício (teste manual da T-03)
#
# Saída de "scan": 0 = nada encontrado; 1 = possível segredo; 3 = erro. 1 e 3 bloqueiam.
#
# Gitleaks v8.30.1 (conferido no código da tag): sem --log-opts, usa
# "--full-history --all --diff-filter=tuxdb", o que incluiria todos os branches do checkout.
# Por isso a análise roda num repositório isolado, com uma única ref, e com --log-opts
# limitado a ela. --exit-code 99 separa o achado dos erros (1, 126 e 2, este de panic).
#
# Registro: o executor do Actions lê como comando uma linha que, sem os espaços iniciais,
# começa com "::", e também "##[" em qualquer posição. Todo texto vindo da imagem, do
# Gitleaks ou do relatório passa por limpar() ou limpo(): sem caracteres de controle e com
# essas sequências quebradas. Só os comandos emitidos por este script ficam inteiros.
set -uo pipefail

docker_cmd=${GITLEAKS_RUN_DOCKER:-docker}   # trocado só nos testes
LOG_OPTS='--full-history --diff-filter=tuxdb scan'

# Texto de várias linhas (mantém quebra de linha e tabulação).
limpar() {
  LC_ALL=C tr -d '\000-\010\013-\037\177' | sed -e ':a' -e 's/::/: :/' -e 'ta' -e 's/##\[/# #[/g'
}
# Um valor numa linha só.
limpar_valor() { printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177' | limpar; }

gl_erro() { echo "::error::Gitleaks: $*" >&2; }

conferir_imagem() {
  local ep
  case ${GITLEAKS_IMAGE:-} in
    *@sha256:*) ;;
    *) gl_erro "GITLEAKS_IMAGE precisa estar fixada por digest"; return 3 ;;
  esac
  ep=$("$docker_cmd" image inspect --format '{{json .Config.Entrypoint}}' "$GITLEAKS_IMAGE" 2> /dev/null) \
    || { gl_erro "imagem não encontrada; rode docker pull antes"; return 3; }
  python3 -I -c '
import json, os, sys
try:
    ep = json.loads(sys.argv[1])
except ValueError:
    sys.exit(1)
ok = isinstance(ep, list) and len(ep) == 1 and os.path.basename(str(ep[0])) == "gitleaks"
sys.exit(0 if ok else 1)
' "$ep" || { gl_erro "ENTRYPOINT inesperado na imagem: $(limpar_valor "$ep")"; return 3; }
}

# Repositório novo, com uma única ref (refs/heads/scan) e só o que é alcançável pela ref
# pedida da origem. Outros branches da origem não entram.
isolar() {  # <origem> <ref> <destino>
  git init -q "$3" \
    && git -C "$3" fetch -q --no-tags "$1" "$2:refs/heads/scan" \
    && git -C "$3" symbolic-ref HEAD refs/heads/scan
}

# Extrai os arquivos da ref "scan" sem passar pelo git archive, que respeita export-ignore.
exportar() {  # <repositório isolado> <destino> <pasta temporária>
  GIT_INDEX_FILE="$3/index" git -C "$1" read-tree scan \
    && GIT_INDEX_FILE="$3/index" git -C "$1" checkout-index --all --force --prefix="$2/"
}

# Mostra só regra, arquivo, linha e commit. Nunca Secret nem Match.
resumo_relatorio() {  # <relatório> <vazio|achados> <nome>
  python3 -I -c '
import json, re, sys
caminho, esperado, nome = sys.argv[1:4]
try:
    with open(caminho, encoding="utf-8") as f:
        dados = json.load(f)
except Exception as e:
    print("%s: relatório ausente ou ilegível (%s)" % (nome, type(e).__name__), file=sys.stderr)
    sys.exit(2)
if not isinstance(dados, list):
    print("%s: relatório sem a lista esperada" % nome, file=sys.stderr)
    sys.exit(2)
if esperado == "vazio" and dados:
    print("%s: código 0, mas o relatório tem achados" % nome, file=sys.stderr)
    sys.exit(2)
if esperado == "achados" and not dados:
    print("%s: código de achado, mas o relatório está vazio" % nome, file=sys.stderr)
    sys.exit(2)
def limpo(s):
    s = re.sub(r"[\x00-\x1f\x7f-\x9f]", "?", str(s))
    s = re.sub(r":(?=:)", ": ", s)
    return re.sub(r"#(?=#\[)", "# ", s)

for d in dados:
    d = d if isinstance(d, dict) else {}
    print("  regra=%s arquivo=%s linha=%s commit=%s" % (
        limpo(d.get("RuleID", "?")), limpo(d.get("File", "?")),
        limpo(d.get("StartLine", "?")), limpo(d.get("Commit") or "-")))
print("%s: %d achado(s)" % (nome, len(dados)))
' "$1" "$2" "$3"
}

gl_run() {  # <git|dir> <pasta montada em /src> <nome> <pasta de saída>
  local modo=$1 src=$2 nome=$3 saida=$4 tmp logs rc esperado
  local extra=()
  [ "$modo" = git ] && extra=("--log-opts=$LOG_OPTS")
  tmp=$(mktemp -d) || return 3
  # Saída do Gitleaks numa pasta não montada; vai para o registro só depois de limpa.
  logs=$(mktemp -d) || { rm -rf "$tmp"; return 3; }
  rm -f "$saida/$nome.json"
  # Sem rede, sem socket, sem privilégios e sem repassar variáveis GITLEAKS_CONFIG*.
  # O diretório de trabalho é uma pasta vazia, então não há .gitleaksignore nele.
  "$docker_cmd" run --rm --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --user "$(id -u):$(id -g)" \
    -e HOME=/tmp -w /tmp -v "$tmp:/tmp" -v "$src:/src:ro" -v "$saida:/out" \
    "$GITLEAKS_IMAGE" "$modo" --no-banner --redact --exit-code 99 --ignore-gitleaks-allow \
    --report-format json --report-path "/out/$nome.json" "${extra[@]}" /src \
    > "$logs/stdout" 2> "$logs/stderr"
  rc=$?
  limpar < "$logs/stdout"
  limpar < "$logs/stderr" >&2
  rm -rf "$tmp" "$logs"
  case $rc in
    0) esperado=vazio ;;
    99) esperado=achados ;;
    *) gl_erro "$nome: código $rc não é resultado de análise; tratado como erro"; return 3 ;;
  esac
  resumo_relatorio "$saida/$nome.json" "$esperado" "$nome" || { gl_erro "$nome: relatório inconsistente"; return 3; }
  [ "$rc" -eq 0 ]  && return 0
  return 1
}

analisar() {  # <repositório> <pasta de saída>; usa o HEAD do repositório
  local repo=$1 saida base rc_git rc_dir
  mkdir -p "$2" && saida=$(cd "$2" && pwd) || return 3
  base=$(mktemp -d) || return 3
  if ! isolar "$repo" HEAD "$base/repo"; then
    gl_erro "não foi possível isolar o histórico de HEAD"; rm -rf "$base"; return 3
  fi
  mkdir "$base/arquivos"
  if ! exportar "$base/repo" "$base/arquivos" "$base"; then
    gl_erro "não foi possível extrair os arquivos de HEAD"; rm -rf "$base"; return 3
  fi
  echo "== Gitleaks: histórico alcançável por HEAD"
  gl_run git "$base/repo" historico "$saida"; rc_git=$?
  echo "== Gitleaks: arquivos de HEAD"
  gl_run dir "$base/arquivos" arquivos "$saida"; rc_dir=$?
  rm -rf "$base"
  if [ "$rc_git" -eq 3 ] || [ "$rc_dir" -eq 3 ]; then return 3; fi
  if [ "$rc_git" -eq 1 ] || [ "$rc_dir" -eq 1 ]; then return 1; fi
  return 0
}

marca_aleatoria() { od -An -N16 -tx1 /dev/urandom | tr -d ' \n'; }

# Bloco no formato de chave privada (regra private-key da configuração padrão), montado em
# partes para este arquivo não conter o padrão. O corpo é claramente fictício.
# O comentário de permissão confere que --ignore-gitleaks-allow continua valendo.
conteudo_ficticio() {  # <marca>
  local ini='-----BEG' meio=' PRIV' fim='ATE KEY-----' permitir='gitleaks'':allow'
  printf '# VALOR FICTICIO PARA TESTE DO CI DO SKILLQUEST. NAO E CREDENCIAL.\n'
  printf '%sIN%s%s # %s\n' "$ini" "$meio" "$fim" "$permitir"
  printf 'VALORFICTICIOPARATESTEDOCI%s\n' "$1"
  printf 'NAOECREDENCIALNAOUSE%sFICTICIO\n' "$1"
  printf -- '-----END%s%s\n' "$meio" "$fim"
}

# Confere se cada relatório tem achado no arquivo do segredo fictício.
achou_no_ficticio() {  # <relatório>...
  python3 -I -c '
import json, os, sys
for caminho in sys.argv[1:]:
    with open(caminho, encoding="utf-8") as f:
        dados = json.load(f)
    if not any(os.path.basename(str(d.get("File", ""))) == "segredo-ficticio.txt" for d in dados):
        sys.exit(1)
' "$@"
}

autoteste() {
  local base orig marca rc falhas=0
  conferir_imagem || return 1
  base=$(mktemp -d) || return 1
  orig="$base/origem"
  g() { git -C "$orig" -c user.name=autoteste -c user.email=autoteste@example.invalid \
          -c commit.gpgsign=false "$@"; }

  git init -q -b main "$orig" || return 1
  printf 'Arquivo limpo do autoteste do CI.\n' > "$orig/LEIA.txt"
  g add LEIA.txt && g commit -q -m 'limpo' || return 1
  g switch -q -c outro || return 1
  marca=$(marca_aleatoria)
  conteudo_ficticio "$marca" > "$orig/segredo-ficticio.txt"
  g add segredo-ficticio.txt && g commit -q -m 'segredo ficticio' || return 1
  g switch -q main || return 1

  echo "== Autoteste 1: HEAD limpo; o branch 'outro', com segredo fictício, existe na origem"
  g rev-parse -q --verify refs/heads/outro > /dev/null || { echo "FALHOU: branch outro ausente"; return 1; }
  analisar "$orig" "$base/saida1" > "$base/log1" 2>&1; rc=$?
  cat "$base/log1"
  if [ "$rc" -eq 0 ]; then echo "ok: o outro branch não afetou a análise"
  else echo "::error::Autoteste 1: esperado 0, veio $rc"; falhas=1; fi

  echo "== Autoteste 2: controle positivo, HEAD no branch com o segredo fictício"
  g switch -q outro || return 1
  analisar "$orig" "$base/saida2" > "$base/log2" 2>&1; rc=$?
  cat "$base/log2"
  if [ "$rc" -eq 1 ] && achou_no_ficticio "$base/saida2/historico.json" "$base/saida2/arquivos.json"; then
    echo "ok: o segredo fictício foi apontado no histórico e nos arquivos"
  else
    echo "::error::Autoteste 2: esperado achado no histórico e nos arquivos (código $rc)"; falhas=1
  fi

  echo "== Autoteste 3: o valor não aparece no registro nem nos relatórios"
  if grep -rqF -- "$marca" "$base/log1" "$base/log2" "$base/saida1" "$base/saida2"; then
    echo "::error::Autoteste 3: o valor fictício apareceu sem redação"; falhas=1
  else
    echo "ok: valor redigido"
  fi

  rm -rf "$base"
  return "$falhas"
}

uso() { echo "uso: gitleaks-selftest.sh scan <repositório> | selftest | fake" >&2; }

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case ${1:-} in
    scan)
      [ $# -eq 2 ] || { uso; exit 3; }
      conferir_imagem || exit 3
      saida=$(mktemp -d) || exit 3
      analisar "$2" "$saida"; rc=$?
      case $rc in
        0) echo "Gitleaks: nenhum segredo encontrado." ;;
        1) echo "::error::Gitleaks encontrou possível segredo. Se for real, revogue-o: o commit continua público." ;;
        *) gl_erro "a análise não terminou; nada foi conferido" ;;
      esac
      rm -rf "$saida"
      exit "$rc"
      ;;
    selftest) autoteste; exit $? ;;
    fake) conteudo_ficticio "$(marca_aleatoria)"; exit 0 ;;
    *) uso; exit 3 ;;
  esac
fi
