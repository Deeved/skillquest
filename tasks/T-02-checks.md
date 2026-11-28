# T-02: comandos de conferência (rodados por uma pessoa, no computador)

Rode na pasta do projeto, com o seu usuário (sem sudo), em bash. Cada bloco pode ir num terminal novo:
quando precisa do `dc`, o bloco o define de novo (como função, para funcionar também dentro de `$( )`).
Nenhum bloco usa `set -e`, então uma falha do verify não impede a restauração do arquivo.
Anexe a saída de cada bloco ao pedido de integração.

Atenção: os blocos 1 e 2 usam a rede do Docker, que **não passa pelo gateway**.

## 0. Preparação
Cria a pasta das cópias e dos registros. Falha se ela já existir, para não sobrescrever nada.
```sh
mkdir /tmp/t02
```

## 1. Versão do Angular (H1)
Mostra a versão atual do Angular CLI, o Node que ela aceita (`engines`) e a versão do angular-eslint.
Não monta pasta nem grava nada.
```sh
sh scripts/create-web.sh
```

## 2. Gerar web/ (H2)
Use a versão do bloco 1, se o `engines.node` aceitar o Node 24. Recusa se web/ já tiver conteúdo.
Envie a saída completa antes de seguir.
```sh
sh scripts/create-web.sh X.Y.Z
```

## 3. Reconstruir o dev (H3)
Só depois de aprovar as dependências. **Recria o dev e encerra a sessão do agente.**
```sh
unalias dc 2>/dev/null
dc() { docker compose --env-file docker/versions.env --env-file .env "$@"; }
dc build dev && dc up -d dev
```
Para retomar a sessão:
```sh
unalias dc 2>/dev/null
dc() { docker compose --env-file docker/versions.env --env-file .env "$@"; }
dc exec dev claude --continue --permission-mode manual
```

## 4. Critério 5: verify sem internet
Espera: "Passou.", saída 0, "sem mudanças" e falha ao consultar o npm.
```sh
unalias dc 2>/dev/null
dc() { docker compose --env-file docker/versions.env --env-file .env "$@"; }
sh scripts/snapshot.sh > /tmp/t02/antes.txt; echo "snapshot: $?"
dc run --rm verify; echo "saída: $?"
sh scripts/snapshot.sh > /tmp/t02/depois.txt; echo "snapshot: $?"
diff /tmp/t02/antes.txt /tmp/t02/depois.txt && echo "sem mudanças"
dc run --rm verify sh -c 'npm view left-pad version'; echo "saída: $?"
```

## 5. Critério 5: teste quebrado de propósito (Go)
Só altera o teste se a cópia de segurança for criada agora e conferida com `cmp`. Se já existir uma cópia
anterior, recusa, para não sobrescrever o original guardado.
Espera: "cópia conferida", "diff: 1", saída ≠ 0, `--- FAIL: TestRootReturnsOK` sem "Passou", "restaurado" e,
no último verify, saída 0.
```sh
unalias dc 2>/dev/null
dc() { docker compose --env-file docker/versions.env --env-file .env "$@"; }
f=api/internal/httpapi/handler_test.go
b=/tmp/t02/handler_test.go
if [ ! -e "$b" ] && cp -p "$f" "$b" && cmp "$f" "$b"; then
  echo "cópia conferida"
  sed -i 's/want := http.StatusOK/want := http.StatusTeapot/' "$f"
  diff "$b" "$f"; echo "diff: $? (1 = mudou)"
  dc run --rm verify > /tmp/t02/verify-go.log 2>&1; echo "saída: $?"
  grep -n -e '--- FAIL: TestRootReturnsOK' -e '^FAIL' -e 'Passou' /tmp/t02/verify-go.log
  cp -p "$b" "$f"; cmp "$b" "$f" && echo "restaurado"
  dc run --rm verify; echo "saída: $?"
else
  echo "FALHOU: cópia de segurança não criada ou já existente; o teste não foi alterado"
fi
```

## 6. Critério 5: teste quebrado de propósito (web)
Mesmo cuidado do bloco 5. No fim, compara com o estado do bloco 4.
Espera: "cópia conferida", "diff: 1", saída ≠ 0, falha em `mostra o nome SkillQuest` com `TESTE-QUEBRADO` e sem
"Passou", "restaurado", último verify com saída 0 e "igual ao início".
```sh
unalias dc 2>/dev/null
dc() { docker compose --env-file docker/versions.env --env-file .env "$@"; }
f=web/src/app/app.spec.ts
b=/tmp/t02/app.spec.ts
if [ ! -e "$b" ] && cp -p "$f" "$b" && cmp "$f" "$b"; then
  echo "cópia conferida"
  sed -i "s/toContain('SkillQuest')/toContain('TESTE-QUEBRADO')/" "$f"
  diff "$b" "$f"; echo "diff: $? (1 = mudou)"
  dc run --rm verify > /tmp/t02/verify-web.log 2>&1; echo "saída: $?"
  grep -n -e 'mostra o nome SkillQuest' -e 'TESTE-QUEBRADO' -e 'FAIL' -e 'Passou' /tmp/t02/verify-web.log
  cp -p "$b" "$f"; cmp "$b" "$f" && echo "restaurado"
  dc run --rm verify; echo "saída: $?"
  sh scripts/snapshot.sh > /tmp/t02/final.txt; echo "snapshot: $?"
  diff /tmp/t02/antes.txt /tmp/t02/final.txt && echo "igual ao início"
else
  echo "FALHOU: cópia de segurança não criada ou já existente; o teste não foi alterado"
fi
```

## 7. Critério 6: subir web e API
Terminal 1 (fica rodando):
```sh
unalias dc 2>/dev/null
dc() { docker compose --env-file docker/versions.env --env-file .env "$@"; }
dc exec dev make dev
```
Terminal 2. Espera: 200 nas duas e as portas só em 127.0.0.1. Depois abra http://127.0.0.1:4200 no navegador do Windows.
```sh
curl -i http://127.0.0.1:8080/
curl -sI http://127.0.0.1:4200/ | head -1
ss -ltn | grep -E ':(4200|8080)\b'
```

## 8. Critério 6: Ctrl+C e subir de novo
Aperte Ctrl+C no terminal 1. Não importa o código de saída; importa não sobrar processo.
No terminal 2, espera "achados: 1 (1 = nenhum)" (nunca "FALHOU") e um código diferente de 200:
```sh
unalias dc 2>/dev/null
dc() { docker compose --env-file docker/versions.env --env-file .env "$@"; }
if procs=$(dc exec -T dev ps -eo pid,pgid,args); then
  printf '%s\n' "$procs" | grep -E 'go run|go-build|/api$|ng serve|esbuild|vite'; echo "achados: $? (1 = nenhum)"
else
  echo "FALHOU: dc exec ou ps não rodou; nada foi conferido"
fi
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/
```
Rode `dc exec dev make dev` de novo no terminal 1 e repita os dois `curl` do bloco 7 (espera 200 nas duas).

## 9. Critério 6: queda de um servidor
Com o `make dev` do bloco 8 rodando. Derruba só o binário da API (`api`); o agente e o resto não são atingidos.
Espera "achados: 1 (1 = nenhum)" (nunca "FALHOU") e um código diferente de 200 na web:
```sh
unalias dc 2>/dev/null
dc() { docker compose --env-file docker/versions.env --env-file .env "$@"; }
dc exec -T dev pkill -TERM -x api; echo "pkill: $? (0 = derrubou)"
sleep 5
if procs=$(dc exec -T dev ps -eo pid,pgid,args); then
  printf '%s\n' "$procs" | grep -E 'go run|go-build|/api$|ng serve|esbuild|vite'; echo "achados: $? (1 = nenhum)"
else
  echo "FALHOU: dc exec ou ps não rodou; nada foi conferido"
fi
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:4200/
```
No terminal 1, espera "Um dos servidores parou…" e o erro do make. Confirme ali mesmo, logo depois
(espera um número diferente de 0):
```sh
echo "saída: $?"
```

## 10. Limpeza
Só depois de conferir e anexar as saídas.
```sh
rm -r /tmp/t02
```
