# Produto

## Objetivo (Decidido)
SkillQuest ("Suba de nível na prática") é uma plataforma gamificada de aprendizado em desenvolvimento de software para membros de TI. Os desafios devem ser realistas, e a evolução na plataforma deve fazer diferença no trabalho do dia a dia.

Para os perfis de desenvolvimento, o centro é o julgamento: avaliar soluções para problemas reais e decidir o que pode ser adotado, e por quê.

## Produto (Decidido)
- Perfis previstos, a princípio: Back-end, Front-end, Mobile, PO, Scrum Master, QA, Designer e Arquiteto/Tech Lead.
- Níveis de 1 (inicial) a 3 (experiente). No lançamento, só o nível 1.
- Trilhas do lançamento: Back-end, Front-end, Mobile, QA e PO, com 3 desafios cada. Cada pessoa pode fazer mais de uma.
- Ritmo: um desafio por trilha a cada 2 semanas.
- Piloto com no máximo 15 pessoas, com login por e-mail e senha.
- Avatar 2D.
- Um agente de IA Claude cria o material e faz as revisões. A supervisão humana segue as [regras dos desafios](#regras-dos-desafios-decidido).
- Tecnologias: plataforma e desafios de back-end em Go, front-end em Angular e mobile em Flutter. QA e PO não têm tecnologia definida.
- Layout: versão B. A pessoa pode escolher o tema de toda a plataforma entre o padrão e mais dois. Menu com ícones e grupo "Configurações".
- As telas não têm ranking, pontos nem sequências diárias. Dados fictícios aparecem identificados como exemplo.

## Telas e uso de IA (Plano)
- As telas informam que o uso de IA é permitido e mostram o limite do assistente.

## Desafio de desenvolvimento (Decidido)
A pessoa recebe um cenário de trabalho e uma solução feita por IA. Responde na própria tela, sem escrever nem executar código, em cinco etapas:
1. **Investigar** o pedido, a solução e as evidências.
2. **Apontar** o que preocupa, com o risco e a consequência.
3. **Decidir:** adotar, adotar com mudanças ou rejeitar, com justificativa.
4. **Verificar:** dizer o que precisa ser conferido antes da liberação.
5. **Reavaliar** com uma informação nova e manter ou mudar a decisão. A primeira decisão é salva antes de a informação aparecer.

QA e PO usam critérios escritos. A adaptação deles a este formato não foi discutida (pendente: veja [open-items.md](open-items.md)).

## Uso de IA pelo participante (Decidido)
- É permitido, inclusive com ferramentas de fora da plataforma. A pessoa conta como usou.
- A plataforma tem um assistente que explica conceitos, tira dúvidas e mostra caminhos, sem entregar a resposta.
- O limite é de 2 perguntas por tentativa e no máximo 6 por pessoa em cada desafio.
- O assistente não tem acesso ao gabarito. Isso reduz o risco de entregar a resposta, mas não o elimina.
- O limite vale só para o assistente da plataforma. Ferramentas externas não são controladas.

## Regras dos desafios (Decidido)
As regras 3, 5, 7 e 8 foram revisadas em 28/11/2026 para o modelo de julgamento.

1. **Aprovação:** cumprir todos os critérios obrigatórios. O resultado é "Aprovado", "Ajustar" ou "Revisão humana".
2. **Prazo:** cada ciclo dura 2 semanas. Entregas atrasadas continuam aceitas até o fim do piloto.
3. **Tentativas, dicas e assistente:** tentativas sem limite e 3 dicas liberadas uma a uma, sem reduzir a recompensa. O assistente aceita 2 perguntas por tentativa e no máximo 6 por pessoa em cada desafio, e fica indisponível quando o bloqueio de gasto é acionado.
4. **Recompensa:** a aprovação registra a competência e libera um item de avatar, uma única vez.
5. **Revisão:** regras fixas conferem o que a pessoa marca. O agente Claude avalia as explicações, critério por critério, e cita o trecho da resposta que justifica o resultado. Em QA e PO, ele usa os critérios escritos.
6. **Supervisão humana:** uma pessoa responde às contestações e aos casos de dúvida. Ela também confere a primeira revisão de cada desafio.
7. **Validação do material:** antes da publicação, cada desafio é testado com uma resposta correta e outra com erros. Uma pessoa confere o resultado.
8. **Segurança:** use apenas dados fictícios e nenhum código da empresa. Nada enviado pelo participante é executado. O agente e o assistente tratam o texto do participante como conteúdo e não seguem instruções nele que tentem mudar as regras deles.
9. **Ranking:** não há ranking individual no piloto.

## Veja também
O bloqueio de gasto está em [spend-limit.md](spend-limit.md).
