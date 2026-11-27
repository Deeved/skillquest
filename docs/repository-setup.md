# Configuração do repositório no GitHub (feita por uma pessoa)

## Como o projeto está organizado
- **Uma pessoa, plano gratuito.** `@Deeved` é o dono do produto e o responsável técnico. Não há substituto: é um risco aceito.
- **Repositório `skillquest` público.** No plano gratuito, a [proteção de ramo](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) vale para repositórios públicos.
- **Repositório `skillquest-challenges` privado.** Gabaritos, testes obrigatórios e entregas de referência ficam somente nele.
- **CI:** GitHub Actions, configurado na T-03. Nos repositórios públicos, os [executores padrão não têm custo](https://docs.github.com/en/billing/concepts/product-billing/github-actions).
- **Sem aprovação obrigatória.** Quem abre um pedido de integração [não pode aprová-lo](https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/approving-a-pull-request-with-required-reviews). A revisão é um compromisso: ler as mudanças antes de fazer o merge.

**Risco aceito:** um agente com permissão de merge pela conta `@Deeved` conseguiria integrar sem essa revisão. Quando a ferramenta do agente for escolhida, avaliar uma [conta de máquina](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service) para ele. Se funcionar, passar a exigir 1 aprovação.

## Antes de tornar o repositório público
- [ ] Confirmar que há autorização para publicar e que nada é código ou dado de empresa.
- [ ] Procurar segredos e dados pessoais nos arquivos, no histórico e nos pedidos de integração.
- [ ] Ativar [Keep my email addresses private](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address). Vale só para os próximos commits. No computador, configurar o `git config user.email` com o endereço `noreply` do GitHub.
- [ ] Saber que o código, o histórico e os [registros do Actions](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility) ficam visíveis e que qualquer pessoa pode fazer um fork.

Sem um arquivo `LICENSE`, o projeto não concede licença de uso. Escolher uma é uma decisão separada.

## Proteção do ramo main
Em **Settings > Branches**, crie uma [regra de proteção](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule) para `main`.

- [ ] Marcar **Require a pull request before merging**.
- [ ] Deixar **Require approvals** desmarcado.
- [ ] Marcar **Do not allow bypassing the above settings**. Sem essa opção, o administrador não fica sujeito à regra.
- [ ] Deixar **Allow force pushes** e **Allow deletions** desmarcados.
- [ ] Na T-03, marcar **Require status checks to pass before merging** e escolher a verificação do CI.

### Testar a proteção
Na pasta do projeto, este comando tenta enviar um commit vazio direto ao `main`, sem alterar os seus arquivos nem os ramos locais:

```sh
git fetch origin
git push origin "$(git commit-tree 'origin/main^{tree}' -p origin/main -m 'Teste de proteção')":refs/heads/main
```

O esperado é o GitHub **recusar** o envio por causa da regra do ramo. Faça o teste somente depois de criar a regra. Se o envio for aceito, o `main` ganha um commit sem mudanças: revise a regra.

## Acessos
- [ ] O agente não faz merge, não publica e não altera a visibilidade nem estas configurações.
- [ ] Credencial do agente, se houver, limitada ao `skillquest` e com validade curta.
- [ ] Nenhuma chave SSH ou credencial pessoal montada no contêiner.
- [ ] `skillquest-challenges` privado e fora do alcance dos agentes de desenvolvimento, inclusive no computador.
- [ ] Limite de gasto definido para os agentes.
