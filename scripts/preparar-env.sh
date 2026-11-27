#!/bin/sh
# Cria o .env local, com uma senha aleatória para o banco descartável.
set -eu
cd "$(dirname "$0")/.."
[ -e .env ] && { echo ".env já existe; nada foi alterado."; exit 0; }
[ "$(id -u)" -ne 0 ] || { echo "Rode com o seu usuário, sem sudo." >&2; exit 1; }
senha=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
umask 077
printf 'UID_LOCAL=%s\nGID_LOCAL=%s\nDB_PASSWORD=%s\n' "$(id -u)" "$(id -g)" "$senha" > .env
echo ".env criado."
