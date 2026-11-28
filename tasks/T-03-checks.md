# T-03: comandos de conferência (rodados por uma pessoa)

Rode na pasta do projeto, com o seu usuário (sem sudo), em bash. Os passos no GitHub são feitos na página do
repositório; nenhum passo depende do `gh`. Anexe ao pedido de integração da T-03 a saída de cada bloco e o
endereço de cada execução do CI citada.

Regras deste roteiro:
- Nenhum comando monta a pasta do projeto num scanner, para não expor o `.env`. Os scanners só recebem pastas
  temporárias criadas aqui.
- Os pedidos de teste têm "NÃO INTEGRAR" no título, apontam para o `main`, só são abertos **depois** de as
  verificações serem obrigatórias (bloco 4) e **nunca** são integrados.
- Os pedidos dos blocos 5 e 6 são abertos como pedidos normais (**Create pull request**), **não** como rascunho:
  neles é preciso provar que as verificações obrigatórias bloqueiam o merge, e um rascunho já fica bloqueado por
  ser rascunho. Os pedidos dos blocos 7 e 8 são abertos como rascunho (**Create draft pull request**).
- O segredo fictício nunca é commitado no `t-03-ci`.
- Depois de cada envio, espere a execução do CI terminar antes do próximo envio no mesmo pedido: uma execução
  nova cancela a anterior.
- Os blocos 5, 6, 7, 8a, 8b, 8c e 8d rodam num subshell, entre `(` e `)`, com `set -eu`: param no primeiro erro
  sem fechar o terminal. Antes de qualquer alteração, conferem o ramo atual (e, nos blocos 5, 6, 7 e 8a, que
  `git status --porcelain` está vazio) e param com uma mensagem "PARE: …" se algo não bater.
- **Se um bloco parar no meio, não o repita nem siga para o próximo.** Primeiro confira o ramo atual
  (`git branch --show-current`) e o `git status`, veja até onde o bloco chegou e, na dúvida, pare e pergunte.
- O pedido da T-03 (bloco 3) só pode ser integrado depois de concluídos os blocos 4 a 9, com as saídas anexadas,
  e da revisão humana.
- Os blocos 0 a 9 foram executados em 27 e 28/11/2026. Os desvios e os resultados estão no
  [comentário do pedido de integração #4](https://github.com/Deeved/skillquest/pull/4#issuecomment-7232886657).
  O bloco 10 está pendente.
  Atualização em 28/11/2026: segundo a pessoa, `/tmp/t03` não existe mais; a saída não foi registrada.

## 0. Preparação
Cria a pasta dos arquivos temporários. Falha se ela já existir, para não sobrescrever nada.
```sh
mkdir /tmp/t03
```

## 1. Autoteste real do Gitleaks, antes do envio
Usa a imagem fixada em `GITLEAKS_IMAGE`, no `.github/workflows/ci.yml`. O autoteste cria um repositório temporário
próprio. Ele não monta a pasta do projeto.

Espera:
- a imagem `ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f`;
- as três linhas "ok" (outro branch não afetou, segredo apontado, valor redigido);
- "saída: 0".
```sh
GITLEAKS_IMAGE=$(sed -n 's/^  GITLEAKS_IMAGE: //p' .github/workflows/ci.yml); export GITLEAKS_IMAGE
echo "imagem: $GITLEAKS_IMAGE"
docker pull "$GITLEAKS_IMAGE"
bash .github/scripts/gitleaks-selftest.sh selftest; echo "saída: $?"
```

## 2. Segredo fictício, conferido localmente
O conteúdo vem de `gitleaks-selftest.sh fake`: um bloco no formato de chave privada, com o corpo marcado como
fictício. A pasta é nova e só tem esse arquivo, e o Gitleaks roda sem rede.

Espera "leaks found: 1", ou equivalente, e "saída: 99". O valor não deve aparecer.
```sh
GITLEAKS_IMAGE=$(sed -n 's/^  GITLEAKS_IMAGE: //p' .github/workflows/ci.yml)
mkdir /tmp/t03/segredo
bash .github/scripts/gitleaks-selftest.sh fake > /tmp/t03/segredo/ci-teste-segredo-ficticio.txt
ls -A /tmp/t03/segredo
docker run --rm --network none --read-only --cap-drop ALL --security-opt no-new-privileges \
  --user "$(id -u):$(id -g)" --tmpfs /tmp -e HOME=/tmp -w /tmp \
  -v /tmp/t03/segredo:/src:ro "$GITLEAKS_IMAGE" \
  dir --no-banner --redact --exit-code 99 --ignore-gitleaks-allow /src; echo "saída: $? (99 = apontou)"
```
Se a saída não for 99, pare: o bloco 6 não pode ser feito com esse conteúdo.

## 3. Pedido de integração da T-03 e primeira execução
Envie o `t-03-ci` depois do commit, feito por você:
```sh
git push -u origin t-03-ci
```
Na página do repositório, abra o pedido do `t-03-ci` para o `main`, com o título da T-03, **sem** "NÃO INTEGRAR".
Não o integre agora: ele só pode ser integrado depois dos blocos 4 a 9 e da revisão humana.
Na aba **Checks**, abra a execução e confira:

| Onde | O que conferir |
|---|---|
| `verify` > "Executor" | UID e GID (`id`); versões do Docker Engine e do Compose |
| `verify` > "Construir as imagens do zero" e "make verify" | as imagens são construídas; a rede com `gateway_mode_ipv4: isolated` é aceita; "Passou." |
| `verify` > "Gerar o .env fictício" | ".env criado." e só as chaves `LOCAL_UID`, `LOCAL_GID` e `DB_PASSWORD`, sem valores (critério 4) |
| `verify` > autoteste e análise das imagens | o autoteste trata o `.tar` corrompido como erro; o resultado das três imagens, inclusive se aparece a biblioteca padrão do Go |
| `secrets` | testes dos scripts, autoteste (três "ok") e "nenhum segredo encontrado" no histórico atual |
| `deps` | testes dos scripts, autoteste, os IDs apontados para o minimatch (anote-os para o bloco 8) e se aparece a biblioteca padrão do Go |
| "Set up job" de cada job | "GITHUB_TOKEN Permissions" com `Contents: read` e `Metadata: read`, sem nenhuma permissão de escrita (critério 3) |

Pare e pergunte se:
- o executor recusar o modo `isolated`;
- o histórico atual tiver algum achado do Gitleaks;
- o `deps` mostrar a biblioteca padrão do Go;
- o ENTRYPOINT de uma imagem não for o esperado;
- alguma opção não existir.

Critério 3, também no computador. Espera "achados: 1 (1 = nenhum)":
```sh
grep -n 'secrets\.' .github/workflows/ci.yml; echo "achados: $? (1 = nenhum)"
```
Em **Settings > Secrets and variables > Actions**, confira que não há segredos nem variáveis.

Critério 4, no computador. Espera nenhuma linha antes de "fim":
```sh
git ls-files .env; echo "fim"
```

## 4. Configurações e verificações obrigatórias
Siga a seção "GitHub Actions (T-03)" e a seção "Proteção do ramo main" de
[docs/repository-setup.md](../docs/repository-setup.md). Marque as verificações `verify`, `secrets` e `deps` como
obrigatórias e faça o teste de proteção que está lá. Só depois siga para o bloco 5.

## 5. Critério 1: teste quebrado (NÃO INTEGRAR)
Espera a diferença mostrada, com `want := http.StatusOK` trocado por `want := http.StatusTeapot`, o envio aceito e
a volta ao `t-03-ci`. Se aparecer "PARE: …", nada foi alterado depois da mensagem; veja as regras no início.
```sh
(
  set -eu
  ramo=$(git branch --show-current)
  if [ "$ramo" != "t-03-ci" ]; then
    echo "PARE: o ramo atual é '$ramo', não t-03-ci." >&2; exit 1
  fi
  estado=$(git status --porcelain)
  if [ -n "$estado" ]; then
    echo "PARE: há mudanças sem commit (git status --porcelain não está vazio)." >&2; exit 1
  fi
  git fetch origin
  git switch --no-track -c t-03-nao-integrar-teste-quebrado origin/t-03-ci
  sed -i 's/want := http.StatusOK/want := http.StatusTeapot/' api/internal/httpapi/handler_test.go
  if git diff --quiet; then
    echo "PARE: o sed não mudou nada em handler_test.go." >&2; exit 1
  fi
  git diff
  git commit -am "NÃO INTEGRAR: teste quebrado de propósito (T-03)"
  git push -u origin t-03-nao-integrar-teste-quebrado
  git switch t-03-ci
)
```
Na página, abra o pedido para o `main` com o título "NÃO INTEGRAR: teste quebrado (T-03)", como pedido normal
(**não** rascunho). Espera:
- `verify` vermelho, com `--- FAIL: TestRootReturnsOK`;
- `secrets` e `deps` verdes;
- o botão de merge bloqueado.

## 6. Critério 2: segredo fictício (NÃO INTEGRAR)
O arquivo é o do bloco 2. O GitHub pode ter uma proteção de envio que reaja a segredos. Não está confirmado se
ela reage ao formato de chave privada. **Se o envio for recusado, pare e informe. Não use o link de liberação nem
outra forma de contornar.**

Espera o envio aceito, a volta ao `t-03-ci` e, no fim, "no t-03-ci: 0 commits".
```sh
(
  set -eu
  ramo=$(git branch --show-current)
  if [ "$ramo" != "t-03-ci" ]; then
    echo "PARE: o ramo atual é '$ramo', não t-03-ci." >&2; exit 1
  fi
  estado=$(git status --porcelain)
  if [ -n "$estado" ]; then
    echo "PARE: há mudanças sem commit (git status --porcelain não está vazio)." >&2; exit 1
  fi
  git fetch origin
  git switch --no-track -c t-03-nao-integrar-segredo origin/t-03-ci
  cp /tmp/t03/segredo/ci-teste-segredo-ficticio.txt .
  git add ci-teste-segredo-ficticio.txt
  git commit -m "NÃO INTEGRAR: segredo fictício de propósito (T-03)"
  git push -u origin t-03-nao-integrar-segredo
  git switch t-03-ci
  echo "no t-03-ci: $(git rev-list --count t-03-ci -- ci-teste-segredo-ficticio.txt) commits"
)
```
Na página, abra o pedido para o `main` com o título "NÃO INTEGRAR: segredo fictício (T-03)", como pedido normal
(**não** rascunho). Espera:
- `secrets` vermelho, com linhas `regra=… arquivo=ci-teste-segredo-ficticio.txt linha=… commit=…` no histórico e
  nos arquivos;
- no registro, a busca por "VALORFICTICIO" não encontra nada;
- `verify` e `deps` verdes;
- o merge bloqueado.

Não feche este pedido antes do bloco 7.

## 7. Segundo pedido limpo, com o branch do segredo ainda no GitHub (NÃO INTEGRAR)
Confira na página **Branches** que `t-03-nao-integrar-segredo` ainda existe. Espera o envio aceito e a volta ao
`t-03-ci`.
```sh
(
  set -eu
  ramo=$(git branch --show-current)
  if [ "$ramo" != "t-03-ci" ]; then
    echo "PARE: o ramo atual é '$ramo', não t-03-ci." >&2; exit 1
  fi
  estado=$(git status --porcelain)
  if [ -n "$estado" ]; then
    echo "PARE: há mudanças sem commit (git status --porcelain não está vazio)." >&2; exit 1
  fi
  git fetch origin
  git switch --no-track -c t-03-nao-integrar-limpo origin/t-03-ci
  git commit --allow-empty -m "NÃO INTEGRAR: pedido limpo, sem mudanças (T-03)"
  git push -u origin t-03-nao-integrar-limpo
  git switch t-03-ci
)
```
Na página, abra o pedido para o `main` com o título "NÃO INTEGRAR: pedido limpo (T-03)", como rascunho
(**Create draft pull request**). Espera `secrets` verde: o branch do segredo, trazido pelo checkout, não afeta a
análise.

## 8. Exceção válida e vencida, com o scanner real (NÃO INTEGRAR)
Usa os IDs do minimatch anotados no bloco 3. Só neste pedido, o `deps` passa a `block`. Faça um envio por vez e
espere o CI terminar antes do seguinte. Os blocos 8b, 8c e 8d rodam no ramo `t-03-nao-integrar-excecao`, criado
no 8a; o 8a não volta ao `t-03-ci`.

8a. `deps` em block, sem exceção. Espera a linha `DEPS_MODE: block` e o envio aceito.
```sh
(
  set -eu
  ramo=$(git branch --show-current)
  if [ "$ramo" != "t-03-ci" ]; then
    echo "PARE: o ramo atual é '$ramo', não t-03-ci." >&2; exit 1
  fi
  estado=$(git status --porcelain)
  if [ -n "$estado" ]; then
    echo "PARE: há mudanças sem commit (git status --porcelain não está vazio)." >&2; exit 1
  fi
  git fetch origin
  git switch --no-track -c t-03-nao-integrar-excecao origin/t-03-ci
  sed -i 's/^  DEPS_MODE: report$/  DEPS_MODE: block/' .github/workflows/ci.yml
  grep -n 'DEPS_MODE:' .github/workflows/ci.yml
  git commit -am "NÃO INTEGRAR: deps em block, sem exceção (T-03)"
  git push -u origin t-03-nao-integrar-excecao
)
```
Na página, abra o pedido para o `main` com o título "NÃO INTEGRAR: exceção válida e vencida (T-03)", como
rascunho (**Create draft pull request**). Espera `deps` vermelho, com os IDs do minimatch.

8b. Exceção válida, com prazo de 30 dias. Preencha `IDS=""` com os IDs anotados no bloco 3, separados por espaço.
O bloco para antes de alterar arquivos se `IDS` estiver vazio ou ainda contiver `ID1` ou `ID2`. Espera as
exceções impressas e o envio aceito.
```sh
(
  set -eu
  IDS=""
  ramo=$(git branch --show-current)
  if [ "$ramo" != "t-03-nao-integrar-excecao" ]; then
    echo "PARE: o ramo atual é '$ramo', não t-03-nao-integrar-excecao." >&2; exit 1
  fi
  if [ -z "${IDS//[[:space:]]/}" ]; then
    echo "PARE: preencha IDS com os IDs anotados no bloco 3." >&2; exit 1
  fi
  case "$IDS" in
    *ID1*|*ID2*) echo "PARE: IDS ainda contém ID1 ou ID2; troque pelos IDs anotados." >&2; exit 1 ;;
  esac
  prazo=$(date -u -d '+30 days' +%F)
  for id in $IDS; do
    printf '\n[[IgnoredVulns]]\nid = "%s"\neffectiveUntil = %s\nreason = "NÃO INTEGRAR: teste da T-03."\n' \
      "$id" "$prazo" >> osv-scanner.toml
  done
  grep -A3 '^\[\[IgnoredVulns\]\]' osv-scanner.toml
  git commit -am "NÃO INTEGRAR: exceção válida (T-03)"
  git push origin t-03-nao-integrar-excecao
)
```
Espera `deps` verde, se o minimatch for o único achado. Se aparecer outro achado, anote e informe.

8c. A mesma exceção, vencida ontem. Espera as datas trocadas e o envio aceito.
```sh
(
  set -eu
  ramo=$(git branch --show-current)
  if [ "$ramo" != "t-03-nao-integrar-excecao" ]; then
    echo "PARE: o ramo atual é '$ramo', não t-03-nao-integrar-excecao." >&2; exit 1
  fi
  sed -i "s/^effectiveUntil = .*/effectiveUntil = $(date -u -d '-1 day' +%F)/" osv-scanner.toml
  grep -n '^effectiveUntil' osv-scanner.toml
  git commit -am "NÃO INTEGRAR: exceção vencida (T-03)"
  git push origin t-03-nao-integrar-excecao
)
```
Espera `deps` vermelho, com o aviso "vencida" do validador e os mesmos IDs apontados pelo scanner.

8d. Chave obsoleta, recusada pelo validador. Espera as linhas com `ignoreUntil`, o envio aceito e a volta ao
`t-03-ci`.
```sh
(
  set -eu
  ramo=$(git branch --show-current)
  if [ "$ramo" != "t-03-nao-integrar-excecao" ]; then
    echo "PARE: o ramo atual é '$ramo', não t-03-nao-integrar-excecao." >&2; exit 1
  fi
  sed -i 's/^effectiveUntil = /ignoreUntil = /' osv-scanner.toml
  grep -n '^ignoreUntil' osv-scanner.toml
  git commit -am "NÃO INTEGRAR: chave obsoleta (T-03)"
  git push origin t-03-nao-integrar-excecao
  git switch t-03-ci
)
```
Espera `deps` vermelho, com "ignoreUntil está obsoleto", antes da análise.

## 9. Encerrar os pedidos de teste
Para cada pedido "NÃO INTEGRAR", na página: **Close pull request**, sem merge, e depois **Delete branch**.
No computador, espera "Deleted branch" para os quatro:
```sh
git branch -D t-03-nao-integrar-teste-quebrado t-03-nao-integrar-segredo \
  t-03-nao-integrar-limpo t-03-nao-integrar-excecao
```
Os commits desses pedidos continuam acessíveis no GitHub pelas referências dos pedidos. Por isso o segredo é
fictício.

Concluídos os blocos 4 a 9, com as saídas anexadas, o pedido da T-03 segue para a revisão humana. Só depois dela
ele pode ser integrado.

## 10. Limpeza
Só depois de conferir e anexar as saídas.
```sh
rm -r /tmp/t03
```
