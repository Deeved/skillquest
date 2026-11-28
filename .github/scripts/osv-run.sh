#!/usr/bin/env bash
# Roda o OSV-Scanner fixado (OSV_SCANNER_IMAGE) num contêiner sem o socket do Docker e sem
# privilégios, e separa "achado" de "erro do scanner".
#
# Uso: osv-run.sh <report|block> <nome> <pasta-de-entrada> <pasta-de-saída> scan <source|image> [opções...]
#   A pasta de entrada é montada só para leitura em /in. O JSON fica em <pasta-de-saída>/<nome>.json.
#
# Códigos do OSV-Scanner v2.7.1 (conferidos no código da tag): 0 sem achado, 1 achado,
# 127 erro geral, 128 nenhum pacote, 129 falha na API, 130 configuração inválida.
# Só 0 e 1 são resultado; qualquer outro código é erro.
#
# Saída deste script: 0 = sem achado, ou achado no modo report
#                     1 = achado no modo block
#                     3 = erro do scanner ou deste script (sempre bloqueia)
#
# Registro: o executor do Actions lê como comando uma linha que, sem os espaços iniciais,
# começa com "::", e também "##[" em qualquer posição. Todo texto vindo da imagem, do
# scanner ou do relatório passa por limpar(): sem caracteres de controle e com essas
# sequências quebradas. Só os comandos emitidos por este script ficam inteiros.
set -uo pipefail

docker_cmd=${OSV_RUN_DOCKER:-docker}   # trocado só nos testes
nome=?

# Texto de várias linhas (mantém quebra de linha e tabulação).
limpar() {
  LC_ALL=C tr -d '\000-\010\013-\037\177' | sed -e ':a' -e 's/::/: :/' -e 'ta' -e 's/##\[/# #[/g'
}
# Um valor numa linha só.
limpar_valor() { printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177' | limpar; }

erro() { echo "::error::OSV-Scanner ($nome): $*" >&2; exit 3; }

[ $# -ge 6 ] || erro "uso: osv-run.sh <report|block> <nome> <entrada> <saída> scan <source|image> [opções...]"
modo=$1 nome=$2 entrada=$3 saida=$4
shift 4
case $nome in '' | *[!A-Za-z0-9_-]*) nome=?; erro "nome inválido" ;; esac
case $modo in report | block) ;; *) erro "modo inválido (use report ou block)" ;; esac
[ "$1" = scan ] || erro "subcomando inesperado (use scan)"
case $2 in source | image) ;; *) erro "tipo de análise inesperado (use source ou image)" ;; esac
sub1=$1 sub2=$2
shift 2

image=${OSV_SCANNER_IMAGE:-}
case $image in *@sha256:*) ;; *) erro "OSV_SCANNER_IMAGE precisa estar fixada por digest" ;; esac
[ -d "$entrada" ] || erro "pasta de entrada inexistente"
entrada=$(cd "$entrada" && pwd) || erro "pasta de entrada ilegível"
mkdir -p "$saida" && saida=$(cd "$saida" && pwd) || erro "não foi possível criar a pasta de saída"

# Não supõe o ENTRYPOINT: confere na imagem baixada (docker pull antes).
ep=$("$docker_cmd" image inspect --format '{{json .Config.Entrypoint}}' "$image" 2> /dev/null) \
  || erro "imagem não encontrada; rode docker pull antes"
python3 -I -c '
import json, os, sys
try:
    ep = json.loads(sys.argv[1])
except ValueError:
    sys.exit(1)
ok = isinstance(ep, list) and len(ep) == 1 and os.path.basename(str(ep[0])) == "osv-scanner"
sys.exit(0 if ok else 1)
' "$ep" || erro "ENTRYPOINT inesperado na imagem: $(limpar_valor "$ep") (conferir antes de usar)"

# tmp é montado como /tmp do contêiner. O stderr fica em outra pasta, não montada.
tmp=$(mktemp -d) || erro "mktemp falhou"
logs=$(mktemp -d) || erro "mktemp falhou"
trap 'rm -rf "$tmp" "$logs"' EXIT
relatorio="$saida/$nome.json"
rm -f "$relatorio"

# /tmp do contêiner é uma pasta do executor, para não limitar o espaço ao extrair imagens.
# Saída JSON vai para o stdout; os registros do scanner, para o stderr.
"$docker_cmd" run --rm --read-only --cap-drop ALL --security-opt no-new-privileges \
  --user "$(id -u):$(id -g)" -e HOME=/tmp -e TMPDIR=/tmp -w /tmp \
  -v "$tmp:/tmp" -v "$entrada:/in:ro" \
  "$image" "$sub1" "$sub2" --format json "$@" > "$relatorio" 2> "$logs/stderr"
rc=$?
limpar < "$logs/stderr" >&2

case $rc in
  0 | 1) ;;
  127) erro "erro geral do scanner (código 127)" ;;
  128) erro "nenhum pacote encontrado (código 128): nada foi analisado" ;;
  129) erro "falha na API do OSV (código 129)" ;;
  130) erro "configuração inválida (código 130)" ;;
  *) erro "código $rc não é resultado de análise; tratado como erro" ;;
esac

# Resumo com pacote e ID, já limpo (ver "Registro" no início).
resumo=$(python3 -I -c '
import json, re, sys

def limpo(s):
    s = re.sub(r"[\x00-\x1f\x7f-\x9f]", "?", str(s))
    s = re.sub(r":(?=:)", ": ", s)
    return re.sub(r"#(?=#\[)", "# ", s)

try:
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print("JSON ilegível: %s" % type(e).__name__, file=sys.stderr)
    sys.exit(2)
if not isinstance(data, dict):
    print("JSON sem o objeto esperado", file=sys.stderr)
    sys.exit(2)
results = data.get("results") or []
if not isinstance(results, list):
    print("JSON com \"results\" inválido", file=sys.stderr)
    sys.exit(2)
linhas = []
for r in results:
    r = r if isinstance(r, dict) else {}
    origem = (r.get("source") or {}).get("path", "?")
    for p in r.get("packages") or []:
        pkg = p.get("package") or {}
        ids = sorted({str(v.get("id", "?")) for v in p.get("vulnerabilities") or []})
        if ids:
            linhas.append("  %s@%s (%s): %s" % (limpo(pkg.get("name", "?")),
                          limpo(pkg.get("version", "?")), limpo(origem), limpo(", ".join(ids))))
print(len(linhas))
print("\n".join(linhas))
' "$relatorio") || erro "relatório ausente ou ilegível; nada foi conferido"

pacotes=$(printf '%s\n' "$resumo" | head -n 1)
lista=$(printf '%s\n' "$resumo" | tail -n +2)

if [ "$rc" -eq 0 ]; then
  echo "OSV-Scanner ($nome): nenhuma falha conhecida."
  exit 0
fi

echo "OSV-Scanner ($nome): falhas conhecidas em $pacotes pacote(s):"
[ -n "$lista" ] && printf '%s\n' "$lista"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### OSV-Scanner: $nome ($modo)"
    echo '```'
    printf '%s\n' "$lista"
    echo '```'
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$modo" = block ]; then
  echo "::error::OSV-Scanner ($nome): falhas conhecidas encontradas; o modo block impede a integração."
  exit 1
fi
echo "::warning::OSV-Scanner ($nome): falhas conhecidas encontradas (modo report, não bloqueia)."
exit 0
