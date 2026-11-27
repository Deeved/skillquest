# T-06 Ensaio: rota de saúde

## Objetivo
Provar o fluxo completo com uma tarefa pequena, feita por um agente sem histórico.

## Depende de
T-03 e T-05.

## Escopo
- api/: GET /api/saude, com testes, e a rota no contrato.

## Fora do escopo
- Conferir o banco ou expor versão e dados internos.

## Critérios de aceite
1. GET /api/saude responde 200 com {"estado":"ok"}.
2. Outros métodos respondem 405.
3. A rota não exige login.
4. O CI passa e uma pessoa aprova a integração.

## Revisão
Normal.
