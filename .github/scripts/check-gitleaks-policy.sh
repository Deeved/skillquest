#!/usr/bin/env bash
# Recusa arquivos que mudariam a configuração ou a lista de ignorados do Gitleaks.
# Lê do stdin os caminhos versionados, separados por NUL (git ls-files -z).
# Saída: 0 = nada proibido; 1 = arquivo proibido encontrado.
#
# Os comentários gitleaks:allow não são proibidos aqui: o Gitleaks roda com
# --ignore-gitleaks-allow. As variáveis GITLEAKS_CONFIG* não são repassadas ao contêiner.
#
# Registro: o executor do Actions lê como comando uma linha que, sem os espaços iniciais,
# começa com "::", e também "##[" em qualquer posição. O caminho vem do repositório, então
# perde os caracteres de controle e tem essas sequências quebradas antes de ir para o
# registro. Só o comando emitido por este script fica inteiro.
set -uo pipefail

limpar_valor() {
  printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177' \
    | sed -e ':a' -e 's/::/: :/' -e 'ta' -e 's/##\[/# #[/g'
}

achou=0
while IFS= read -r -d '' caminho; do
  case ${caminho##*/} in
    .gitleaks.toml | .gitleaksignore)
      echo "::error::Arquivo proibido: $(limpar_valor "$caminho") (mudaria as regras ou os ignorados do Gitleaks)"
      achou=1
      ;;
  esac
done

if [ "$achou" -eq 0 ]; then
  echo "Nenhum .gitleaks.toml ou .gitleaksignore versionado."
fi
exit "$achou"
