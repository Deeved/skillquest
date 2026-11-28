#!/usr/bin/env python3
"""Testes de check-osv-config.py. Rode com: python3 -I .github/scripts/tests/test_check_osv_config.py

Os IDs são fictícios. A data de referência é fixa (--agora), para o teste não depender do dia.
"""

import os
import re
import subprocess
import sys
import tempfile
import unittest

AQUI = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(AQUI, "..", "check-osv-config.py")
AGORA = "2026-11-28T12:00:00+00:00"
PREFIXO_ERRO = "::error::osv-scanner.toml: "


class ConfigOSV(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.config = os.path.join(self.dir.name, "osv-scanner.toml")
        self.lista = os.path.join(self.dir.name, "arquivos")
        self.arquivos(["osv-scanner.toml", "web/package-lock.json"])

    def arquivos(self, caminhos):
        with open(self.lista, "wb") as f:
            f.write(b"".join(c.encode() + b"\0" for c in caminhos))

    def rodar(self, toml, criar=True):
        if criar:
            with open(self.config, "w", encoding="utf-8") as f:
                f.write(toml)
        r = subprocess.run(
            [sys.executable, "-I", SCRIPT, "--config", self.config,
             "--tracked-files", self.lista, "--agora", AGORA],
            capture_output=True, text=True, cwd=self.dir.name)
        return r.returncode, r.stdout + r.stderr

    def aceita(self, toml):
        rc, saida = self.rodar(toml)
        self.assertEqual(rc, 0, saida)
        return saida

    def recusa(self, toml, trecho):
        rc, saida = self.rodar(toml)
        self.assertEqual(rc, 1, saida)
        self.assertIn(trecho, saida)

    # Aceitos
    def test_arquivo_so_com_comentarios(self):
        self.assertIn("0 exceção", self.aceita("# sem exceções\n"))

    def test_excecao_com_data(self):
        self.aceita('[[IgnoredVulns]]\nid = "GHSA-ficticio-0001"\n'
                    'effectiveUntil = 2026-12-31\nreason = "Motivo fictício."\n')

    def test_excecao_com_data_e_hora_com_fuso(self):
        self.aceita('[[IgnoredVulns]]\nid = "ID-1"\n'
                    'effectiveUntil = 2027-01-15T00:00:00Z\nreason = "Motivo."\n')

    def test_prazo_de_exatamente_90_dias(self):
        self.aceita('[[IgnoredVulns]]\nid = "ID-1"\n'
                    'effectiveUntil = 2027-02-26T12:00:00Z\nreason = "Motivo."\n')

    def test_excecao_vencida_e_aceita_com_aviso(self):
        saida = self.aceita('[[IgnoredVulns]]\nid = "ID-1"\n'
                            'effectiveUntil = 2026-11-01\nreason = "Motivo."\n')
        self.assertIn("vencida", saida)

    def test_duas_excecoes(self):
        self.aceita('[[IgnoredVulns]]\nid = "ID-1"\neffectiveUntil = 2026-12-01\nreason = "A."\n'
                    '[[IgnoredVulns]]\nid = "ID-2"\neffectiveUntil = 2026-12-02\nreason = "B."\n')

    # Prazo
    def test_sem_prazo(self):
        self.recusa('[[IgnoredVulns]]\nid = "ID-1"\nreason = "Motivo."\n',
                    "effectiveUntil é obrigatório")

    def test_prazo_acima_de_90_dias(self):
        self.recusa('[[IgnoredVulns]]\nid = "ID-1"\n'
                    'effectiveUntil = 2027-02-27\nreason = "Motivo."\n', "passa de 90 dias")

    def test_prazo_como_texto(self):
        self.recusa('[[IgnoredVulns]]\nid = "ID-1"\n'
                    'effectiveUntil = "2026-12-01"\nreason = "Motivo."\n', "data TOML")

    def test_prazo_sem_fuso(self):
        self.recusa('[[IgnoredVulns]]\nid = "ID-1"\n'
                    'effectiveUntil = 2026-12-01T00:00:00\nreason = "Motivo."\n', "data TOML")

    def test_ignoreUntil_obsoleto(self):
        self.recusa('[[IgnoredVulns]]\nid = "ID-1"\nignoreUntil = 2026-12-01\nreason = "Motivo."\n',
                    "ignoreUntil está obsoleto")

    def test_ignoreUntil_junto_com_effectiveUntil(self):
        self.recusa('[[IgnoredVulns]]\nid = "ID-1"\neffectiveUntil = 2026-12-01\n'
                    'ignoreUntil = 2026-12-01\nreason = "Motivo."\n', "ignoreUntil está obsoleto")

    # Motivo e id
    def test_sem_motivo(self):
        self.recusa('[[IgnoredVulns]]\nid = "ID-1"\neffectiveUntil = 2026-12-01\n',
                    "reason ausente ou vazio")

    def test_motivo_em_branco(self):
        self.recusa('[[IgnoredVulns]]\nid = "ID-1"\neffectiveUntil = 2026-12-01\nreason = "  "\n',
                    "reason ausente ou vazio")

    def test_sem_id(self):
        self.recusa('[[IgnoredVulns]]\neffectiveUntil = 2026-12-01\nreason = "Motivo."\n',
                    "id ausente ou inválido")

    def test_id_que_nao_e_texto(self):
        self.recusa('[[IgnoredVulns]]\nid = 1\neffectiveUntil = 2026-12-01\nreason = "Motivo."\n',
                    "id ausente ou inválido")

    def test_id_repetido(self):
        self.recusa('[[IgnoredVulns]]\nid = "ID-1"\neffectiveUntil = 2026-12-01\nreason = "A."\n'
                    '[[IgnoredVulns]]\nid = "ID-1"\neffectiveUntil = 2026-12-02\nreason = "B."\n',
                    "id repetido")

    # Chaves e seções
    def test_chave_desconhecida_na_excecao(self):
        self.recusa('[[IgnoredVulns]]\nid = "ID-1"\neffectiveUntil = 2026-12-01\n'
                    'reason = "Motivo."\nextra = true\n', "chave não permitida: extra")

    def test_PackageOverrides(self):
        self.recusa('[[PackageOverrides]]\nname = "pacote"\nignore = true\n',
                    "PackageOverrides não é permitido")

    def test_GoVersionOverride(self):
        self.recusa('GoVersionOverride = "1.27.0"\n', "GoVersionOverride não é permitido")

    def test_ScanGoModVersion(self):
        self.recusa('ScanGoModVersion = true\n', "ScanGoModVersion não é permitido")

    def test_secao_desconhecida(self):
        self.recusa('[Outra]\nx = 1\n', "seção ou chave não permitida: Outra")

    def test_IgnoredVulns_que_nao_e_lista_de_tabelas(self):
        self.recusa('IgnoredVulns = "tudo"\n', "lista de [[IgnoredVulns]]")

    def test_toml_invalido(self):
        self.recusa('[[IgnoredVulns]\n', "não é TOML válido")

    def test_config_ausente(self):
        rc, saida = self.rodar("", criar=False)
        self.assertEqual(rc, 1, saida)
        self.assertIn("ilegível", saida)

    # Outros arquivos de configuração
    def test_outro_osv_scanner_toml(self):
        self.arquivos(["osv-scanner.toml", "web/osv-scanner.toml"])
        self.recusa("# vazio\n", "fora da raiz")

    def test_osv_scanner_toml_oculto(self):
        self.arquivos(["osv-scanner.toml", "api/.osv-scanner.toml"])
        self.recusa("# vazio\n", "fora da raiz")

    def test_lista_de_arquivos_ausente(self):
        os.remove(self.lista)
        self.recusa("# vazio\n", "lista de arquivos ilegível")

    # Registro do Actions: o executor lê como comando uma linha que, sem os espaços iniciais,
    # começa com "::", e também "##[" em qualquer posição.
    def sem_comando(self, saida, marcadores):
        """Cada marcador aparece, e nenhuma linha com "injetado" tem "::" ou "##[" em qualquer
        posição. Só o prefixo exato do erro emitido pelo script é retirado, no começo da linha."""
        for m in marcadores:
            self.assertRegex(saida, r"injetado-%s(?![A-Za-z0-9])" % re.escape(m))
        # Mesmas quebras de linha que o executor reconhece.
        for linha in re.split(r"\r\n|\r|\n", saida):
            if "injetado" not in linha:
                continue
            if linha.startswith(PREFIXO_ERRO):
                linha = linha[len(PREFIXO_ERRO):]
            self.assertNotIn("::", linha, saida)
            self.assertNotIn("##[", linha, saida)

    def test_chaves_com_comando_do_actions(self):
        rc, saida = self.rodar(
            '"a\\n::error::injetado-quebra" = 1\n'
            '"  ::warning::injetado-inicio" = 1\n'
            '"x##[error]injetado-meio" = 1\n'
            '[[IgnoredVulns]]\nid = "ID-1"\neffectiveUntil = 2026-12-01\nreason = "Motivo."\n'
            '"::error::injetado-entrada" = 1\n')
        self.assertEqual(rc, 1, saida)
        self.assertIn(PREFIXO_ERRO + "seção ou chave não permitida", saida)
        self.sem_comando(saida, ["quebra", "inicio", "meio", "entrada"])

    def test_caminho_da_config_com_comando_do_actions(self):
        self.config = os.path.join(self.dir.name, "::error::injetado-config ##[error]injetado-config2")
        rc, saida = self.rodar("", criar=False)
        self.assertEqual(rc, 1, saida)
        self.assertIn("ilegível", saida)
        self.sem_comando(saida, ["config", "config2"])

    def test_caminho_versionado_com_comando_do_actions(self):
        self.arquivos(["osv-scanner.toml", "::error::injetado-pasta/osv-scanner.toml",
                       "a\n::error::injetado-quebra/osv-scanner.toml",
                       "b##[error]injetado-meio/osv-scanner.toml"])
        rc, saida = self.rodar("# vazio\n")
        self.assertEqual(rc, 1, saida)
        self.assertIn("fora da raiz", saida)
        self.sem_comando(saida, ["pasta", "quebra", "meio"])

    def test_limpo_preserva_texto_comum(self):
        rc, saida = self.rodar('[[IgnoredVulns]]\nid = "ID-1"\nreason = "Motivo."\n')
        self.assertEqual(rc, 1, saida)
        self.assertIn(PREFIXO_ERRO + "exceção ID-1: effectiveUntil é obrigatório", saida)


if __name__ == "__main__":
    unittest.main(verbosity=2)
