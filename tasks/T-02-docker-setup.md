# T-02 Estrutura e ambiente em Docker

## Objetivo
Qualquer pessoa ou agente sobe o mesmo ambiente e roda make verify.

## Depende de
T-01.

## Ler antes
- README.md, compose.yaml, docker/, scripts/verify.sh

## Escopo
- Uma pessoa roda scripts/pin-versions.sh, constrói as imagens e informa os erros.
- Corrigir o rascunho de Docker até as imagens construírem e iniciarem.
- Criar o esqueleto de api/, reviewer/ (Go) e web/ (Angular, versão compatível com o Node da imagem).
- Instalar as dependências na construção da imagem.
- Definir make setup e make dev.

## Fora do escopo
- Telas, rotas e banco do produto.
- CI (T-03). Execução de código de participante.

## Critérios de aceite
1. As imagens são construídas do zero, com digests fixos.
2. No dev: o usuário não é root e os arquivos criados têm o dono de quem desenvolve.
3. No dev: acesso direto à internet falha; pelo proxy, só os endereços da lista respondem.
4. No dev não existe /var/run/docker.sock, e um serviço aberto no computador não é alcançado.
5. O verify passa sem internet e falha quando um teste é quebrado de propósito.
6. A web e a API de exemplo abrem em 127.0.0.1 nas portas 4200 e 8080.
7. O login do agente continua depois de recriar o contêiner.
8. O README descreve os comandos que foram de fato executados.

## Verificação
- Saída dos comandos de cada critério anexada ao pedido de integração.
- Os critérios que exigem o Docker são executados por uma pessoa.

## Revisão
Reforçada: o ambiente define os limites dos agentes.

## Pare e pergunte se
- For preciso liberar um novo endereço, dar mais privilégio a um contêiner ou montar outra pasta.
