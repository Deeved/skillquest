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
