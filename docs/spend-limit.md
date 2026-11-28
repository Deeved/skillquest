# Bloqueio de gasto

## Bloqueio de gasto (Decidido)
- No piloto, o uso fica na conta da pessoa responsável, com uma chave de API do Claude Console. O login de assinatura do Claude não é usado pela plataforma.
- O piloto tem um limite de gasto total, que não se renova sozinho. O valor fica na configuração, fora deste repositório.
- Quando o gasto chega a 75% do limite, as perguntas dos participantes ao assistente são desativadas.
- Entram na conta as perguntas e as avaliações da plataforma. Testes do agente usam outra chave e outro controle.
- O servidor soma os tokens informados em cada resposta da API, pelos preços configurados.
- Antes de cada pergunta, o servidor reserva o custo máximo dela. Só aceita se gasto, reservas e a nova pergunta não passarem de 75%. Isso vale também para pedidos ao mesmo tempo.
- Em falha sem consumo informado, a pergunta não é descontada da pessoa, mas o valor reservado continua contando como gasto.
- Mensagem na tela: "O assistente está indisponível. As dicas continuam, e você pode enviar sua resposta."
- Só a pessoa responsável reativa o assistente, ao aumentar o limite.
- Depois dos 75%, as avaliações usam o saldo restante. Sem saldo para a próxima, a resposta é salva e vai para revisão humana.
- Como segunda barreira, a plataforma usa um espaço de trabalho próprio no Console, com limite de gasto. Isso não substitui o bloqueio da plataforma.

## Veja também
A regra sobre falha na chamada também aparece, com outra redação, em [security.md](security.md). A diferença está
registrada em [open-items.md](open-items.md#diferenças-registradas-nos-documentos).
