# Como o trabalho é feito

## Como o trabalho é feito (Decidido)
- Agentes de IA implementam, em tarefas pequenas. Uma tarefa por ramo e por pedido de integração.
- Ambientes de desenvolvimento em Docker; a equipe usa Linux.
- Nomes técnicos em inglês. Telas, desafios, mensagens, comentários e documentação em português.
- Repositório público no GitHub, plano gratuito, com uma só pessoa. O CI usa GitHub Actions, com a condição de não ter custo.
- O `main` é protegido e exige `verify`, `secrets` e `deps`. A aprovação no GitHub não é obrigatória (risco aceito): a pessoa responsável revisa antes do merge e é quem faz o merge.
- Dependências: o `deps` bloqueia falha conhecida, salvo exceção aprovada e com prazo. A análise das imagens só gera relatório. Busca de segredos bloqueia qualquer achado.
- O agente de desenvolvimento roda no contêiner, em modo manual.

## Fluxo adotado em 28/11/2026 (Decidido)
- O agente apresenta um plano antes de programar. Em tarefas de revisão reforçada, a pessoa aprova o plano antes do código e o resultado depois. Mudanças que o `AGENTS.md` protege continuam exigindo aprovação.
- A revisão é feita sobre a diferença completa da tarefa.
- Antes de enviar um ramo, a pessoa confere os arquivos e o conteúdo, porque o repositório é público. Depois do envio, a diferença e o CI são revisados pelo GitHub, antes do merge.
- Critérios de aceite viram testes no `make verify` ou no CI sempre que possível. Teste manual fica para o que não puder ser automatizado com segurança.
- Preparações que dependem de uma pessoa correm em paralelo.

## Veja também
A configuração do GitHub e os responsáveis estão em [repository-setup.md](repository-setup.md). Os comandos e o CI
estão no [README.md](../README.md).
