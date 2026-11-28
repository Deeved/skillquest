#!/usr/bin/env bash
# Docker falso para os testes dos scripts do CI. Não usa rede nem o Docker de verdade.
#
#   FAKE_ARGS       arquivo onde cada chamada é gravada (argumentos separados por NUL)
#   FAKE_EP         resposta de "image inspect" (padrão: ["/fake"]); FAKE_INSPECT_RC, o código
#   FAKE_STDERR     texto que "run" escreve no stderr
#   OSV-Scanner:    FAKE_JSON (stdout) e FAKE_RC
#   Gitleaks:       FAKE_RC_GIT / FAKE_RC_DIR, FAKE_REPORT_GIT / FAKE_REPORT_DIR
#                   (FAKE_NO_REPORT=1 não grava relatório) e FAKE_SNAP (pasta onde grava o que viu em /src)
set -uo pipefail

: "${FAKE_ARGS:?}"
printf '%s\0' "$@" >> "$FAKE_ARGS"
printf '\0' >> "$FAKE_ARGS"

case ${1:-} in
  image)
    printf '%s\n' "${FAKE_EP-[\"/fake\"]}"
    exit "${FAKE_INSPECT_RC:-0}"
    ;;
  run) shift ;;
  *) exit 90 ;;
esac

[ -n "${FAKE_STDERR:-}" ] && printf '%s\n' "$FAKE_STDERR" >&2

args=("$@")
out_host='' src_host='' report='' modo=''
for ((i = 0; i < ${#args[@]}; i++)); do
  a=${args[i]}
  case $a in
    -v)
      m=${args[i + 1]}
      case $m in
        *:/out) out_host=${m%:/out} ;;
        *:/src:ro) src_host=${m%:/src:ro} ;;
      esac
      ;;
    --report-path) report=${args[i + 1]} ;;
    *@sha256:*) [ -z "$modo" ] && modo=${args[i + 1]:-} ;;
  esac
done

if [ -z "$report" ]; then
  # OSV-Scanner: o JSON vai para o stdout.
  printf '%s' "${FAKE_JSON-}"
  exit "${FAKE_RC:-0}"
fi

# Gitleaks.
if [ -n "${FAKE_SNAP:-}" ] && [ -n "$src_host" ]; then
  mkdir -p "$FAKE_SNAP"
  if [ "$modo" = git ]; then
    git -C "$src_host" for-each-ref --format='%(refname)' > "$FAKE_SNAP/refs.txt"
    git -C "$src_host" log --all --format=%s > "$FAKE_SNAP/log.txt"
  else
    (cd "$src_host" && find . -mindepth 1 | sort) > "$FAKE_SNAP/dir.txt"
  fi
fi
if [ "${FAKE_NO_REPORT:-0}" != 1 ]; then
  if [ "$modo" = git ]; then conteudo=${FAKE_REPORT_GIT-[]}; else conteudo=${FAKE_REPORT_DIR-[]}; fi
  printf '%s' "$conteudo" > "$out_host/${report#/out/}"
fi
if [ "$modo" = git ]; then exit "${FAKE_RC_GIT:-0}"; fi
exit "${FAKE_RC_DIR:-0}"
