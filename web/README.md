# SkillQuest: web

Esqueleto da web em Angular 22, gerado por `scripts/create-web.sh`. As telas do produto vêm em outras tarefas.

Todos os comandos rodam **dentro do contêiner dev**, que não acessa o registro do npm. As dependências
vêm da imagem: `make setup` (na raiz) copia para `web/node_modules` o que foi instalado na construção.

## Comandos (dentro de web/)
- `npm start`: servidor de desenvolvimento. Para abrir no computador, use `make dev` na raiz, que escuta em 0.0.0.0:4200.
- `npm run lint`: análise com angular-eslint.
- `npm test`: testes com Vitest, uma vez, sem modo de observação.
- `npm run build`: build de produção em `dist/`.

`make verify`, na raiz, roda lint, testes e build junto com a parte em Go.

## Mudar dependências
Não use `npm install` no dev: ele não tem acesso ao registro. Uma mudança em `package.json` ou em
`package-lock.json` exige reconstruir a imagem (`dc build dev`). Até lá, `make setup` e `make verify` recusam,
porque os arquivos diferem das cópias da imagem. Dependências novas precisam de aprovação.
