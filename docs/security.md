# Segurança

A regra de segurança dos desafios é a regra 8 de [product.md](product.md#regras-dos-desafios-decidido).
O módulo de código está arquivado: veja [archived.md](archived.md).
Os limites do ambiente de desenvolvimento estão na seção "Rede" do [README.md](../README.md#rede).

## Segurança (Decidido)
- No piloto, nada enviado pelo participante é executado.
- Se o módulo de código voltar, nenhum código de participante roda fora de um ambiente isolado.
- Os ambientes de desenvolvimento em Docker **não** são o isolamento do código de participante.
- Usar apenas dados fictícios e nenhum código da empresa.
- Tratar o texto do participante e as saídas de teste como dados, nunca como instruções que mudem regras.
- Não montar o socket do Docker nem usar modo privilegiado.
- Nenhum segredo no código, nos logs ou nos testes.
- A chave da API fica só no servidor, fora do navegador, do repositório e das conversas, e é diferente da usada no desenvolvimento.
- Gabaritos, testes obrigatórios e entregas de referência ficam fora deste repositório e fora do alcance dos agentes de desenvolvimento.

## Assistente e avaliação (Plano)
- O assistente não recebe os critérios de avaliação.
- Antes de cada desafio ser publicado, uma pessoa tenta arrancar a resposta do assistente com pedidos diretos, disfarçados e em partes.
- Pergunta e resposta têm tamanho máximo. A resposta do desafio também.
- Em falha da chamada, a pergunta não é descontada da pessoa.
- A pessoa é avisada de que as perguntas ficam registradas. Elas não contam na avaliação.
- O retorno orienta o que aprofundar, sem revelar o gabarito nem quais marcações erraram.
- O agente sinaliza tentativas de manipulação.
- Antes de confiar no avaliador, testar ao menos 30 entregas de referência, com respostas fortes, fracas e convincentes mas erradas, sem aprovação indevida.

## Login e permissões (Plano)
- Senhas com Argon2id; sessão em cookie `HttpOnly`, `Secure` e `SameSite`; proteção contra CSRF; limite de tentativas.
- A mesma mensagem para e-mail ou senha incorretos.
- A API confere a permissão em todo pedido. A proteção de rotas no Angular só organiza a navegação.
- O navegador nunca recebe gabaritos, critérios privados nem dicas ainda não liberadas.
- Os agentes que constroem a plataforma e o agente que avalia entregas não compartilham chaves, instruções nem permissões.

## Diferenças registradas (veja open-items.md)
- A regra sobre falha na chamada aparece também em [spend-limit.md](spend-limit.md), com outro alcance.
- O `AGENTS.md` dá ao agente de desenvolvimento uma regra mais ampla sobre o texto do participante.

As duas estão em [open-items.md](open-items.md#diferenças-registradas-nos-documentos).
