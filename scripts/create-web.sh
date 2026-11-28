#!/bin/sh
# Rodado por uma pessoa, no computador com Docker e internet (não no contêiner dev).
# Sem argumento: mostra a versão atual do Angular CLI e do angular-eslint.
# Com a versão (ex.: 22.1.3): gera web/ e o package-lock.json numa construção descartável.
# Atenção: a construção e a consulta usam a rede do Docker, que NÃO passa pelo gateway.
set -eu
cd "$(dirname "$0")/.."

# Lido como texto, sem executar o arquivo.
node_image=$(sed -n 's/^NODE_IMAGE=//p' docker/versions.env)
case $node_image in
  *@sha256:*) ;;
  *) echo "NODE_IMAGE sem digest em docker/versions.env; rode scripts/pin-versions.sh." >&2; exit 1 ;;
esac

if [ $# -eq 0 ]; then
  docker run --rm "$node_image" npm view @angular/cli@latest version engines
  docker run --rm "$node_image" npm view angular-eslint@latest version
  exit 0
fi

[ $# -eq 1 ] || { echo "Uso: $0 [versão X.Y.Z]" >&2; exit 1; }
version=$1
printf '%s\n' "$version" | grep -Eqx '[0-9]+\.[0-9]+\.[0-9]+' \
  || { echo "Versão inválida: '$version' (use X.Y.Z)." >&2; exit 1; }
major=${version%%.*}

if [ -e web ] || [ -L web ]; then
  if [ -L web ] || [ ! -d web ] || [ -n "$(ls -A web)" ]; then
    echo "web/ já existe e não é uma pasta vazia; nada foi feito." >&2
    exit 1
  fi
fi

# npm_config_ignore_scripts=true: o npx, o "ng new" e o "ng add" não rodam scripts de instalação.
# Só o código gerado e o package-lock.json saem para web/ (sem node_modules).
docker build \
  --build-arg NODE_IMAGE="$node_image" \
  --build-arg NG="$version" \
  --build-arg MAJOR="$major" \
  --output type=local,dest=web - <<'EOF'
ARG NODE_IMAGE
FROM ${NODE_IMAGE} AS gen
ARG NG
ARG MAJOR
ENV NG_CLI_ANALYTICS=false npm_config_ignore_scripts=true
WORKDIR /out
RUN npx -y "@angular/cli@${NG}" new skillquest-web --directory . --defaults \
      --ai-config=none --skip-git --style=css --ssr=false \
 && npx ng add "angular-eslint@${MAJOR}" --skip-confirmation \
 && rm -rf node_modules .angular
FROM scratch
COPY --from=gen /out/ /
EOF

echo "web/ criada. Arquivos gerados (inclusive ocultos):"
find web -mindepth 1 -printf '%y %p\n' | sort -k2
