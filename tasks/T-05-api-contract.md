# T-05 Contrato inicial da API

## Objetivo
API e telas partem do mesmo contrato.

## Depende de
T-04.

## Ler antes
- contracts/openapi.yaml (rascunho), docs/

## Escopo
- Completar corpos, respostas, erros, autenticação e proteção contra CSRF.
- Acrescentar a validação do contrato ao make verify (dependência nova exige aprovação).

## Fora do escopo
- Implementar rotas. Rota de inscrição em trilha.

## Critérios de aceite
1. O contrato é válido para OpenAPI 3.1 e a validação roda no verify.
2. Toda rota diz quem pode usar e quais erros retorna.
3. Nenhuma resposta ao participante traz gabarito, teste obrigatório ou dica não liberada.
4. Os pontos sem decisão estão listados no pedido de integração.

## Revisão
Reforçada.
