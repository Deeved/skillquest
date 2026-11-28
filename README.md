# SkillQuest: ambiente de desenvolvimento (Linux)

Ambiente em Docker para desenvolver a API e o revisor (Go) e a web (Angular), com PostgreSQL.
Testado em **Ubuntu no WSL2, com Docker Engine 29.10.1** (veja [O que foi testado](#o-que-foi-testado)).

## O que você precisa
- Docker Engine com os plugins Compose e Buildx. Não é preciso o Docker Desktop.
- Internet para baixar as imagens e as ferramentas.

Atenção: quem está no grupo `docker` tem [privilégios equivalentes aos de root](https://docs.docker.com/engine/install/linux-postinstall/). Se isso não for aceitável, avalie o [modo sem root](https://docs.docker.com/engine/security/rootless/). Este kit não foi testado nesse modo, em que o mapeamento de usuários dos arquivos muda.

## Atalho `dc`
Os exemplos usam a função `dc`. Defina-a em cada terminal novo, em bash. A primeira linha remove um alias
`dc` antigo, que impediria a definição da função:
```sh
unalias dc 2>/dev/null
dc() { docker compose --env-file docker/versions.env --env-file .env "$@"; }
```

## Primeira vez (uma pessoa, na pasta do projeto)
```sh
sh scripts/pin-versions.sh     # grava digests e a versão do Claude Code em docker/versions.env
sh scripts/prepare-env.sh      # cria o .env (UID, GID e senha do banco descartável)
unalias dc 2>/dev/null
dc() { docker compose --env-file docker/versions.env --env-file .env "$@"; }
dc build
dc up -d dev
```
Revise e envie a mudança em `docker/versions.env` por pedido de integração.

## Trabalhar com o agente
Rode o agente **somente dentro do contêiner**, no modo manual (cada ação pede a sua aprovação):
```sh
dc exec dev claude --permission-mode manual
```
Na primeira vez, o Claude Code pede login. Abra o endereço no navegador do computador e cole o código no terminal.
O login e as conversas ficam no volume `claude`.

Recriar o `dev` (por exemplo, depois de `dc build dev && dc up -d dev`) encerra a sessão. Para retomar a última conversa:
```sh
dc exec dev claude --continue --permission-mode manual
```

No computador, o agente teria o mesmo acesso que o seu usuário, inclusive ao Docker.

## Comandos dentro do contêiner
Rode com `dc exec dev make <alvo>`, ou de dentro do contêiner:
- `make setup`: copia para `web/node_modules` as dependências instaladas na imagem. Não usa a rede.
- `make dev`: roda o setup e sobe a API em http://127.0.0.1:8080 e a web em http://127.0.0.1:4200.
  Ctrl+C encerra os dois. Se um deles parar, o outro é encerrado e o `make dev` termina com erro.
- `make verify`: formatação, análise, testes e build do gateway, da API, do revisor e da web.

## Verificar sem internet
```sh
dc run --rm verify
```
Roda o `make verify` numa rede sem internet e sem o proxy. Deve terminar com "Passou." e saída 0.

## Dependências da web
O `dev` não acessa o registro do npm. As dependências são instaladas na construção da imagem, a partir de
`web/package.json` e `web/package-lock.json`, sem scripts de instalação (`npm ci --ignore-scripts`).

- Qualquer mudança nesses dois arquivos, mesmo só num script do `package.json`, exige reconstruir a imagem:
  `dc build dev && dc up -d dev`. Até lá, `make setup` e `make verify` recusam.
- Dependências novas precisam de aprovação.
- O `web/` foi gerado uma vez, no computador, com `scripts/create-web.sh`. Sem argumento, ele mostra a versão
  atual do Angular CLI. Com a versão (`sh scripts/create-web.sh 22.3.0`), gera `web/` numa construção descartável
  e recusa se `web/` já tiver conteúdo. Não é preciso rodá-lo de novo.

## Encerrar
`dc down` mantém o banco e o login. `dc down -v` apaga os dois.

## Rede
O `dev` não tem rota direta para a internet. O serviço `gateway` abre túneis na porta 443 apenas para os endereços de `ALLOWED_HOSTS` e recusa nomes que resolvam para endereços internos. Os endereços vêm dos [requisitos de rede do Claude Code](https://code.claude.com/docs/en/network-config.md); outros recursos dele podem ficar indisponíveis. O envio ao Git é feito por uma pessoa.

Limites:
- O agente ainda alcança os endereços liberados e pode enviar a eles o que ler no contêiner.
- O proxy confere o endereço do pedido, não o conteúdo do túnel.
- O contêiner lê toda a pasta do projeto, inclusive o `.env` do banco descartável.
- O login do agente fica acessível dentro do `dev`. Veja o aviso da [documentação sobre contêineres de desenvolvimento](https://code.claude.com/docs/en/devcontainer).
- As redes internas usam o [modo `isolated`](https://docs.docker.com/engine/network/port-publishing/). Sem ele, o contêiner alcança serviços abertos no computador pelo endereço da rede. Não remova a opção. Se a sua versão do Docker a recusar, atualize o Docker.
- `dc build`, `scripts/pin-versions.sh` e `scripts/create-web.sh` usam a rede do Docker, que **não passa pelo gateway** nem pela lista de endereços.
- O isolamento de código de participante é outro trabalho, em outra máquina.

## CI (GitHub Actions)
O workflow fica em [.github/workflows/ci.yml](.github/workflows/ci.yml). Ele roda em todo pedido de integração
(`pull_request`) e a cada envio ao `main`. Não usa segredos, e cada job só tem permissão de ler o conteúdo.
Os comandos de conferência da T-03 estão em [tasks/T-03-checks.md](tasks/T-03-checks.md).

| Verificação | O que faz | Bloqueia |
|---|---|---|
| `verify` | Constrói as imagens do zero, gera um `.env` fictício (`scripts/prepare-env.sh`, com o UID e o GID do executor) e roda `make verify` sem internet. Depois analisa as imagens `dev`, `gateway` e `postgres` com o OSV-Scanner. | teste, build ou análise que falhe; erro do scanner. Falha conhecida nas imagens só gera aviso. |
| `secrets` | Procura segredos com o Gitleaks nos arquivos de HEAD e no histórico alcançável por HEAD. Recusa `.gitleaks.toml` e `.gitleaksignore`. | qualquer achado e qualquer erro |
| `deps` | Confere as exceções em `osv-scanner.toml` e analisa os `go.mod` e os `package-lock.json` com o OSV-Scanner. | erro do scanner e exceção inválida. Por enquanto, falha conhecida só gera aviso (`DEPS_MODE: report`). |

As ferramentas rodam em contêineres fixados por versão e digest, sem o socket do Docker, sem modo privilegiado,
com o sistema de arquivos só para leitura e as entradas montadas só para leitura. O Gitleaks roda sem rede.
O OSV-Scanner precisa de rede para consultar a base de falhas.

### Exceções de dependências
Uma falha conhecida só deixa de bloquear com uma exceção em `osv-scanner.toml`, aprovada por uma pessoa num pedido
de integração. Cada exceção tem `id`, `reason` e `effectiveUntil`, com prazo de no máximo 90 dias. Outras chaves e
seções são recusadas, entre elas `ignoreUntil` (obsoleta), `PackageOverrides`, `GoVersionOverride` e `ScanGoModVersion`.
Depois do prazo, o scanner volta a apontar a falha. Só existe o `osv-scanner.toml` da raiz.

### Limites
- Um pedido de integração roda a versão do workflow e dos scripts que ele mesmo traz. Ele pode desligar uma
  verificação e ficar verde. Mudanças em `.github/`, `osv-scanner.toml`, `.dockerignore`, `Makefile`,
  `compose.yaml`, `docker/` e `scripts/` também podem enfraquecer o CI e exigem revisão humana.
- A configuração padrão do Gitleaks ignora alguns caminhos, entre eles `go.mod`, `go.sum`, `package-lock.json` e
  imagens. Um segredo nesses arquivos não é apontado.
- Um segredo enviado ao GitHub continua público, mesmo apagado depois. Se for real, revogue-o.
- O `deps` não cobre a biblioteca padrão do Go: o OSV-Scanner descarta a versão tirada do `go.mod`.
  A análise das imagens detectou a biblioteca padrão num binário compilado (o `gosu`, na imagem `postgres`), mas
  isso não comprova a cobertura da API e do revisor, que ainda não têm imagens finais.
- A análise das imagens só gera relatório, sem triagem de impacto.
- O alerta conhecido do minimatch não foi corrigido. Por isso o `deps` continua com `DEPS_MODE: report`.
- A limpeza dos registros não cobre as mensagens de erro do git no `gitleaks-selftest.sh` nem a saída de build e
  testes do `make verify`.
- Os autotestes com erro proposital deixam duas anotações vermelhas na execução.
- A proteção do `main` não exige aprovação de pedidos de integração.
- O executor é descartado no fim; o CI não roda `docker compose down`.

## O que foi testado
Por uma pessoa, em Ubuntu no WSL2, Docker Engine 29.10.1, em dois momentos:
- **Antes das mudanças da T-02 na imagem:** construção inicial de todas as imagens e conferência dos critérios
  de ambiente, com comandos fora de [tasks/T-02-checks.md](tasks/T-02-checks.md).
- **Depois das mudanças:** só a imagem do `dev` foi reconstruída (`dc build --no-cache dev`), reaproveitando as
  imagens base locais com os mesmos digests. O `gateway` não foi reconstruído; `compose.yaml` e `docker/gateway/`
  não mudaram. Os critérios 5 e 6 foram conferidos com os blocos 4 a 9 de [tasks/T-02-checks.md](tasks/T-02-checks.md).

| Critério | Quando | Resultado |
|---|---|---|
| Imagens construídas do zero, com digests fixos | todas antes; depois, só o `dev` com `--no-cache` | passou |
| Usuário não root (uid 1000) | antes e de novo depois | passou |
| Arquivos criados com o dono de quem desenvolve | antes e de novo depois (nenhum arquivo de outro dono fora de `.git`) | passou |
| Sem acesso direto à internet por nome (`curl --noproxy "*"`: o nome não é resolvido) | antes e de novo depois | passou |
| Tabela de rotas do contêiner sem rota padrão (só a rede interna) | antes, não repetido | passou (só IPv4) |
| Sem conexão direta por IP a um endereço público (`curl --noproxy "*" https://1.1.1.1`) | depois | passou (só IPv4) |
| Pelo proxy, só os endereços da lista | antes e de novo depois (um endereço fora da lista recusado com 403; `api.anthropic.com` respondeu) | passou |
| Sem `/var/run/docker.sock` | antes e de novo depois | passou |
| Serviço aberto no computador não alcançado | antes, não repetido | passou (só IPv4) |
| `dc run --rm verify` sem internet passa; falha com teste quebrado de propósito, em Go e na web | depois (blocos 4 a 6) | passou |
| API e web em 127.0.0.1:8080 e 127.0.0.1:4200; portas só em 127.0.0.1 | depois (bloco 7) | passou: a API devolveu o texto de exemplo, a página abriu no navegador do Windows e o `ss` mostrou as portas só em 127.0.0.1 (a saída registrada não deixa claro o status HTTP de cada `curl`) |
| Ctrl+C no `make dev` não deixa processos e ele sobe de novo | depois (bloco 8) | passou (conferido pela pessoa; a saída não foi registrada) |
| Queda da API no `make dev` encerra a web e o make termina com erro | depois (bloco 9) | passou |
| Login do agente continua depois de recriar o contêiner | antes e de novo depois (sem novo pedido de login) | passou |

Não testado:
- `dc down` e `dc down -v` (seção [Encerrar](#encerrar)).
- Construção do `gateway` a partir do zero depois das mudanças (ele não mudou).
- IPv6 (rede e acesso a serviços do computador).
- Outras distribuições, Linux sem WSL2, Docker Desktop e o modo sem root.
- Recarga automática da página (HMR) do `ng serve` pelo repasse do gateway.
- Falha do `make setup` no meio da cópia de `node_modules`.

### CI (T-03)
Versão testada: commit `f67f355`, em 27 e 28/11/2026 (horário de São Paulo). As saídas e os desvios estão no
[comentário do pedido de integração #4](https://github.com/Deeved/skillquest/pull/4#issuecomment-7232886657).
Os blocos citados são os de [tasks/T-03-checks.md](tasks/T-03-checks.md).

#### No contêiner `dev`, pelo agente
Executado em 27/11/2026. Os testes dos scripts não usam rede nem o Docker de verdade.
- Testes em `.github/scripts/tests/`, depois da limpeza do registro. Todos passaram, com saída 0:
  - `test_osv_run.sh` e `test_gitleaks_selftest.sh`, com um Docker falso: códigos de saída, resumo sem o valor
    do segredo, opções passadas aos contêineres, isolamento do histórico e textos que o executor leria como
    comando ("::" e "##[");
  - `test_check_osv_config.py` (32 testes) e `test_check_gitleaks_policy.sh`, sem Docker: validação de
    `osv-scanner.toml`, recusa de `.gitleaks.toml` e `.gitleaksignore` e os mesmos textos de comando.
- Prova de que o teste de injeção do `osv-run.sh` detecta a falha. Numa cópia temporária de `.github/scripts`,
  com a limpeza desligada só na cópia, as três verificações de injeção falharam nas 50 rodadas. O teste original
  passou. A mesma prova não foi feita para os outros três scripts.
- Reprodução parcial de passos do workflow que não usam Docker, feita antes da limpeza do registro e não repetida
  depois. Os arquivos novos ainda não estavam no índice do Git:
  - a cópia sem `.git` foi criada sem `.git` (64 arquivos, sem os arquivos novos);
  - a conferência de `osv-scanner.toml` mostrou "0 exceção(ões)". `osv-scanner.toml` e dois arquivos novos foram
    acrescentados à mão à lista de arquivos versionados;
  - a separação copiou os quatro arquivos de dependências versionados. `osv-scanner.toml` foi copiado à mão;
  - no repositório real, a política do Gitleaks mostrou "Nenhum .gitleaks.toml ou .gitleaksignore versionado.".
- `make verify` dentro do `dev`, duas vezes: antes e depois da limpeza do registro. Passou nas duas (saída 0).

#### No computador, por uma pessoa
- Blocos 0 a 2: autoteste real do Gitleaks com as três linhas "ok" e saída 0; o segredo fictício foi apontado
  ("leaks found: 1", saída 99).
- Envio direto ao `main` recusado pelo GitHub (GH006, com as 3 verificações obrigatórias).
- Bloco 9: os quatro ramos locais de teste foram apagados.

#### Configurações do repositório
- Conferido pela API na sessão de revisão: `verify`, `secrets` e `deps` obrigatórias no `main`, para todos.
- Informado pela pessoa, não consultado pela API: ações permitidas restritas; aprovação para executar o CI de
  colaboradores externos; token do workflow somente leitura; Actions sem permissão de criar nem aprovar pedidos de
  integração; ramo atualizado obrigatório antes do merge; nenhum segredo nem variável no Actions.

#### No GitHub Actions, conferido na sessão de revisão
| Critério ou bloco | Pedido | Resultado |
|---|---|---|
| Bloco 3: primeira execução | #4 | os três jobs passaram. Executor com UID 1001, Docker Engine 28.0.4 e Compose v2.38.2. Imagens construídas, rede isolada criada e `make verify` com "Passou.". Token com `Contents: read` e `Metadata: read`. Do `.env`, o registro mostrou só os nomes `LOCAL_UID`, `LOCAL_GID` e `DB_PASSWORD`. Autoteste real do Gitleaks com três "ok" e nenhum achado no histórico alcançável por HEAD. OSV-Scanner real: no `deps`, só `minimatch@10.2.6` (GHSA-g3hv-75wg-m249) |
| Critério 1: teste quebrado (bloco 5) | #5 | `verify` falhou; merge bloqueado |
| Critério 2: segredo fictício (bloco 6) | #6 | segredo apontado; os marcadores do valor não apareceram nos registros dos três jobs; merge bloqueado. O GitHub não recusou o envio |
| Bloco 7: pedido limpo com o ramo do segredo trazido pelo checkout | #7 | nenhum achado |
| Bloco 8a: `deps` em `block`, sem exceção | #8 | falhou |
| Bloco 8b: exceção válida | #8 | exceção aplicada; os três jobs passaram |
| Bloco 8c: exceção vencida | #8 | voltou a bloquear |
| Bloco 8d: `ignoreUntil` | #8 | recusado antes da análise |
| Bloco 9: encerramento | #5 a #8 | fechados sem merge; os quatro ramos de teste removidos do GitHub |

Critérios 3 e 4, além do registro: a busca por "secrets." no `ci.yml` não teve achados e o `.env` não está
versionado. Isso foi conferido na sessão de revisão, numa cópia do repositório na nuvem, não no computador da pessoa.

Análise das imagens no `verify` (só informa, sem triagem do impacto nem de se há correção disponível):
- `dev`: minimatch;
- `postgres`: vários IDs na biblioteca padrão do Go 1.24.6 usada pelo `gosu` e um achado em `golang.org/x/sys@0.1.0`;
- `gateway`: nenhuma falha conhecida apontada.

O workflow rodou no GitHub nos pedidos #4 a #8.

#### Desvios do roteiro
- Os blocos 0 a 2 foram rodados num único comando.
- As conferências locais do bloco 3 (critérios 3 e 4) foram feitas na cópia da nuvem, não no computador.
- O pedido #7 foi aberto sem ser rascunho e fechado depois da execução.
- O pedido #8 foi aberto sem ser rascunho e convertido em rascunho antes do 8b.

#### Pendente
- Bloco 10: limpeza de `/tmp/t03`.
- Revisão humana e integração do pedido da T-03.
