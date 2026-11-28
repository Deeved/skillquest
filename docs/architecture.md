# Arquitetura

## Arquitetura (Plano)
- Web em Angular, API em Go e PostgreSQL.
- A API grava a resposta e a coloca numa fila no próprio PostgreSQL (`FOR UPDATE SKIP LOCKED`).
- O revisor é um processo Go separado, que chama a API do Claude.
- O agente avalia os critérios. Quem decide o resultado é o back-end, por regras fixas. Em casos de dúvida ou falha da revisão, uma pessoa decide. A recompensa só sai com o resultado final "Aprovado".
- Assistente e avaliador usam chamadas, instruções e históricos separados. O processo que atende o assistente está pendente (veja [open-items.md](open-items.md)). Toda chamada parte do servidor.
- Estados de uma entrega: `received`, `evaluating`, terminando em `awaiting_human` ou `completed`.
- Cada entrega aponta para a versão do desafio. Decisões são acrescentadas ao histórico, sem apagar as anteriores.
- A recompensa é liberada uma única vez por pessoa e desafio.
- A tela de resultado consulta o andamento periodicamente.
- Grupos de tabelas sugeridos: acesso; conteúdo; entrega; revisão; evolução; perguntas ao assistente e consumo da API.
- A lista de rotas está em `contracts/openapi.yaml`, ainda em rascunho. Ela precisa refletir o novo modelo. A T-05 define o contrato.

## Veja também
O bloqueio de gasto está em [spend-limit.md](spend-limit.md), e a segurança em [security.md](security.md).
