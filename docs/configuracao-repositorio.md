# Configuração do repositório no GitHub (feita por uma pessoa)

## Antes de começar
- **Plano e visibilidade:** segundo a [documentação](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches), a proteção de ramo vale para repositórios públicos no plano gratuito. Em repositório privado, exige Pro, Team ou Enterprise.
- **Duas identidades:** quem abre um pedido de integração [não pode aprová-lo](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews). Se o agente usar a sua conta, você não poderá aprovar o trabalho dele. Quem abre e quem aprova precisam ser contas diferentes.
- **Code owner:** o arquivo `.github/CODEOWNERS` aponta um [responsável](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners), que precisa ter permissão de escrita. Se for quem abre os pedidos, indique outra pessoa. Para ter substituto, acrescente o usuário na mesma linha.

## Proteção do ramo main
Ative depois do primeiro envio.

- [ ] Exigir pedido de integração com 1 aprovação.
- [ ] Exigir a revisão do code owner.
- [ ] Descartar aprovações quando houver novos commits.
- [ ] Exigir aprovação do envio mais recente por outra pessoa.
- [ ] Não permitir contornar as regras, inclusive para administradores. Sem essa opção, eles não ficam sujeitos à regra.
- [ ] Manter bloqueados o envio forçado e a exclusão do ramo.
- [ ] Na T-03, exigir que o CI passe.
- [ ] Testar: um envio direto ao main deve ser recusado.

Nesta primeira configuração, o code owner aprova todos os caminhos.

## Acessos
- [ ] O agente não integra, não publica e não altera estas configurações.
- [ ] Credencial do agente, se houver, limitada a este repositório e com validade curta.
- [ ] Nenhuma chave SSH ou credencial pessoal montada no contêiner.
- [ ] Repositório skillquest-desafios privado e sem acesso dos agentes de desenvolvimento.
- [ ] Limite de gasto definido para os agentes.
