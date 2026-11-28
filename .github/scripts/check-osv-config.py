#!/usr/bin/env python3
"""Confere o osv-scanner.toml antes de o OSV-Scanner usá-lo.

Regras (T-03):
- Só a seção IgnoredVulns é permitida. Cada exceção tem exatamente id, reason e effectiveUntil.
- effectiveUntil é obrigatório (sem ele, o OSV-Scanner trata a exceção como permanente)
  e fica no máximo 90 dias depois de agora. Uma exceção vencida é aceita aqui: quem volta
  a bloquear é o próprio scanner.
- ignoreUntil (obsoleto), PackageOverrides, GoVersionOverride, ScanGoModVersion e qualquer
  outra chave são recusados.
- Só existe um osv-scanner.toml versionado, o da raiz (passado com --config).

Uso: check-osv-config.py --config osv-scanner.toml --tracked-files <lista separada por NUL>
"""

import argparse
import datetime as dt
import os
import re
import sys
import tomllib

MAX_DIAS = 90
CHAVES_ENTRADA = ("id", "reason", "effectiveUntil")
MOTIVO_PROIBIDA = {
    "ignoreUntil": "ignoreUntil está obsoleto; use effectiveUntil",
    "PackageOverrides": "PackageOverrides não é permitido",
    "GoVersionOverride": "GoVersionOverride não é permitido",
    "ScanGoModVersion": "ScanGoModVersion não é permitido",
}
NOMES_CONFIG = ("osv-scanner.toml", ".osv-scanner.toml")
ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,99}$")


def limpo(texto):
    """Prepara um texto para o registro do Actions.

    O executor lê como comando uma linha que, sem os espaços iniciais, começa com "::", e
    também "##[" em qualquer posição. Nomes de chaves, caminhos e mensagens do TOML vêm do
    repositório: perdem os caracteres de controle e têm essas sequências quebradas.
    Os prefixos de comando são acrescentados depois, só por este script.
    """
    texto = re.sub(r"[\x00-\x1f\x7f-\x9f]", "?", str(texto))
    texto = re.sub(r":(?=:)", ": ", texto)
    return re.sub(r"#(?=#\[)", "# ", texto)


def prazo_utc(valor):
    """Converte effectiveUntil para datetime em UTC, ou devolve None se o tipo não serve."""
    if isinstance(valor, dt.datetime):
        if valor.tzinfo is None:
            return None  # data e hora sem fuso: ambígua
        return valor.astimezone(dt.timezone.utc)
    if isinstance(valor, dt.date):
        return dt.datetime(valor.year, valor.month, valor.day, tzinfo=dt.timezone.utc)
    return None


def motivo(chave, padrao):
    return MOTIVO_PROIBIDA.get(chave, padrao)


def conferir_config(conteudo, agora):
    """Devolve (erros, avisos) para o conteúdo já lido do TOML."""
    erros, avisos = [], []
    for chave in conteudo:
        if chave != "IgnoredVulns":
            erros.append(motivo(chave, "seção ou chave não permitida: %s" % chave))

    entradas = conteudo.get("IgnoredVulns", [])
    if not isinstance(entradas, list) or not all(isinstance(e, dict) for e in entradas):
        erros.append("IgnoredVulns deve ser uma lista de [[IgnoredVulns]]")
        return erros, avisos

    limite = agora + dt.timedelta(days=MAX_DIAS)
    vistos = set()
    for n, entrada in enumerate(entradas, 1):
        rotulo = "exceção %d" % n
        for chave in entrada:
            if chave not in CHAVES_ENTRADA:
                erros.append("%s: %s" % (rotulo, motivo(chave, "chave não permitida: %s" % chave)))

        ident = entrada.get("id")
        if not isinstance(ident, str) or not ID_RE.match(ident):
            erros.append("%s: id ausente ou inválido" % rotulo)
        else:
            rotulo = "exceção %s" % ident
            if ident in vistos:
                erros.append("%s: id repetido" % rotulo)
            vistos.add(ident)

        razao = entrada.get("reason")
        if not isinstance(razao, str) or not razao.strip():
            erros.append("%s: reason ausente ou vazio" % rotulo)

        if "effectiveUntil" not in entrada:
            erros.append("%s: effectiveUntil é obrigatório" % rotulo)
            continue
        prazo = prazo_utc(entrada["effectiveUntil"])
        if prazo is None:
            erros.append("%s: effectiveUntil deve ser uma data TOML (ex.: 2026-12-31), "
                         "ou data e hora com fuso" % rotulo)
        elif prazo > limite:
            erros.append("%s: effectiveUntil passa de %d dias (limite %s)"
                         % (rotulo, MAX_DIAS, limite.date().isoformat()))
        elif prazo <= agora:
            avisos.append("%s: vencida em %s; o scanner volta a apontar a falha"
                          % (rotulo, prazo.isoformat()))
    return erros, avisos


def conferir_arquivos(caminhos, config):
    """Recusa outro arquivo de configuração do OSV-Scanner além do indicado.

    Os caminhos versionados são relativos à raiz do repositório, que é a pasta atual.
    """
    config = os.path.normpath(os.path.relpath(config))
    erros = []
    for caminho in caminhos:
        if os.path.basename(caminho) in NOMES_CONFIG and os.path.normpath(caminho) != config:
            erros.append("configuração do OSV-Scanner fora da raiz não é permitida: %r" % caminho)
    return erros


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--config", required=True)
    p.add_argument("--tracked-files", required=True,
                   help="arquivo com os caminhos versionados, separados por NUL (git ls-files -z)")
    p.add_argument("--agora", help="data e hora ISO com fuso; só para testes")
    args = p.parse_args(argv)

    if args.agora:
        agora = dt.datetime.fromisoformat(args.agora)
        if agora.tzinfo is None:
            p.error("--agora precisa de fuso")
    else:
        agora = dt.datetime.now(dt.timezone.utc)

    erros = []
    try:
        with open(args.tracked_files, "rb") as f:
            caminhos = [c.decode("utf-8", "replace") for c in f.read().split(b"\0") if c]
        erros += conferir_arquivos(caminhos, args.config)
    except OSError as e:
        erros.append("lista de arquivos ilegível: %s" % e.strerror)

    avisos = []
    try:
        with open(args.config, "rb") as f:
            conteudo = tomllib.load(f)
        e, avisos = conferir_config(conteudo, agora)
        erros += e
    except OSError as e:
        erros.append("%s ilegível: %s" % (args.config, e.strerror))
    except tomllib.TOMLDecodeError as e:
        erros.append("%s não é TOML válido: %s" % (args.config, e))

    for a in avisos:
        print("::notice::osv-scanner.toml: %s" % limpo(a))
    for e in erros:
        print("::error::osv-scanner.toml: %s" % limpo(e))
    if erros:
        return 1
    print("osv-scanner.toml conferido: %d exceção(ões)." % len(conteudo.get("IgnoredVulns", [])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
