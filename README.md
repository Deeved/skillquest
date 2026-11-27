# SkillQuest: kit da fase 0 (Linux)

Rascunho para revisão. As imagens deste kit **ainda não foram construídas** com as imagens oficiais. A T-02 faz isso e corrige o que falhar.

## O que você precisa
- Docker Engine com os plugins Compose e Buildx. Não é preciso o Docker Desktop.
- Internet para baixar as imagens e as ferramentas.

Atenção: quem está no grupo `docker` tem [privilégios equivalentes aos de root](https://docs.docker.com/engine/install/linux-postinstall/). Se isso não for aceitável, avalie o [modo sem root](https://docs.docker.com/engine/security/rootless/). Este kit não foi testado nesse modo, em que o mapeamento de usuários dos arquivos muda.

## Primeira vez (uma pessoa, na pasta do projeto)
```sh
sh scripts/pin-versions.sh     # grava digests e a versão do Claude Code
sh scripts/prepare-env.sh      # cria o .env
alias dc='docker compose --env-file docker/versions.env --env-file .env'
dc build
dc up -d dev
```
Revise e envie a mudança em `docker/versions.env` por pedido de integração.

## Trabalhar com o agente
```sh
dc exec dev claude
```
Na primeira vez, o Claude Code pede login. Abra o endereço no navegador do computador e cole o código no terminal. O login fica no volume `claude`.

Rode o agente **somente dentro do contêiner**. No computador, ele teria o mesmo acesso que o seu usuário, inclusive ao Docker.

## Verificar sem internet
```sh
dc run --rm verify
```
Enquanto não houver código do produto, a verificação **falha de propósito**.

## Encerrar
`dc down` mantém o banco e o login. `dc down -v` apaga os dois.

## Rede
O `dev` não tem rota direta para a internet. O serviço `gateway` abre túneis na porta 443 apenas para os endereços de `ALLOWED_HOSTS` e recusa nomes que resolvam para endereços internos. Os endereços vêm dos [requisitos de rede do Claude Code](https://code.claude.com/docs/en/network-config.md); outros recursos dele podem ficar indisponíveis. O envio ao Git é feito por uma pessoa.

Limites:
- O agente ainda alcança os endereços liberados e pode enviar a eles o que ler no contêiner.
- O proxy confere o endereço do pedido, não o conteúdo do túnel.
- O contêiner lê toda a pasta do projeto, inclusive o `.env` do banco descartável.
- O login do agente fica acessível dentro do `dev`. Veja o aviso da [documentação sobre contêineres de desenvolvimento](https://code.claude.com/docs/en/devcontainer).
- As redes internas usam o [modo `isolated`](https://docs.docker.com/engine/network/port-publishing/). Sem ele, o contêiner alcança serviços abertos no computador pelo endereço da rede. Não remova a opção. Se a sua versão do Docker a recusar, atualize o Docker. O kit foi testado com o Engine 29.9.3.
- O isolamento de código de participante é outro trabalho, em outra máquina.
