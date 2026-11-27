# T-03 CI

## Objetivo
Todo pedido de integração é conferido no servidor, com a mesma imagem de desenvolvimento.

## Depende de
T-02.

## Escopo
- Construir a imagem do zero e rodar o serviço verify.
- Buscar segredos e analisar dependências e imagens.

## Fora do escopo
- Implantação. Testes com código hostil.

## Critérios de aceite
1. Um teste quebrado bloqueia a integração.
2. Um segredo fictício, incluído de propósito, é apontado e bloqueia.
3. O CI não tem segredos de produção nem chave do revisor.
4. O CI usa um .env gerado na hora, com dados fictícios.

## Revisão
Reforçada.

## Pare e pergunte se
- Faltar definir o serviço de CI ou a ferramenta de análise.
