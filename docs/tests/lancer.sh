#!/bin/bash
# =====================================================================
#  Teste supabase/INSTALLATION.sql sur un Postgres 16 LOCAL et jetable.
#  Rien ne part vers Supabase : un serveur temporaire est créé, testé,
#  arrêté puis effacé.
#
#    bash docs/tests/lancer.sh            (depuis le dossier du CRM)
#
#  Variables possibles : PGBIN (défaut /opt/homebrew/opt/postgresql@16/bin),
#  PORT (défaut 55433), GARDER=1 pour laisser le serveur tourner à la fin.
# =====================================================================
set -euo pipefail

ICI="$(cd "$(dirname "$0")" && pwd)"
RACINE="$(cd "$ICI/../.." && pwd)"
INSTALL="$RACINE/supabase/INSTALLATION.sql"
PGBIN="${PGBIN:-/opt/homebrew/opt/postgresql@16/bin}"
PORT="${PORT:-55433}"
DATA="$(mktemp -d "${TMPDIR:-/tmp}/ace-pg.XXXXXX")"

q() { local db="$1"; shift; "$PGBIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d "$db" -v ON_ERROR_STOP=1 "$@"; }

arreter() {
  if [ "${GARDER:-0}" != "1" ]; then
    "$PGBIN/pg_ctl" -D "$DATA" -m fast stop >/dev/null 2>&1 || true
    rm -rf "$DATA"
  else
    echo "Serveur laissé en marche : $DATA, port $PORT"
  fi
}
trap arreter EXIT

nouvelle_base() {
  "$PGBIN/createdb" -h 127.0.0.1 -p "$PORT" -U postgres "$1"
  q "$1" -q -c "alter database \"$1\" set search_path = \"\$user\", public, extensions"
  q "$1" -q -f "$ICI/stubs-supabase.sql" 2>&1 | grep -vE "wal_level|ASTUCE|HINT|NOTICE" || true
}

passer() {  # passer <base> <libellé> [options psql]
  local db="$1" lib="$2"; shift 2
  if q "$db" -q "$@" -f "$INSTALL" > "$DATA/$db-$lib.log" 2>&1; then
    echo "  ✓ $lib"
  else
    echo "  ✗ $lib"; grep -E "ERROR|ERREUR" "$DATA/$db-$lib.log" | head -5; exit 1
  fi
}

echo "Postgres temporaire : $DATA (port $PORT)"
"$PGBIN/initdb" -D "$DATA" -U postgres --auth=trust -E UTF8 --locale=C >/dev/null
# Socket Unix désactivée : le chemin du dossier temporaire peut dépasser 103 caractères.
"$PGBIN/pg_ctl" -D "$DATA" -o "-p $PORT -k ''" -l "$DATA/serveur.log" -w start >/dev/null

echo "1. Base vierge, INSTALLATION.sql deux fois de suite (requête par requête)"
nouvelle_base ace_a
passer ace_a "passage-1"
passer ace_a "passage-2"

echo "2. Base vierge, deux fois en une seule transaction (comme le SQL Editor de Supabase)"
nouvelle_base ace_b
passer ace_b "transaction-1" --single-transaction
passer ace_b "transaction-2" --single-transaction

echo "3. Scénario : lead → setter → vente → commission → invitation → élève"
q ace_a -f "$ICI/scenario.sql" > "$DATA/scenario.log" 2>&1 || { echo "  ✗ scénario"; grep -E "ERROR|ERREUR" "$DATA/scenario.log" | head -5; exit 1; }
grep -E "^--- " "$DATA/scenario.log" | sed 's/^/  /'
grep -q "SCÉNARIO OK" "$DATA/scenario.log" && echo "  ✓ SCÉNARIO OK"

echo "4. Troisième passage sur la base remplie : rien ne doit bouger"
avant="$(q ace_a -Atf "$ICI/verif-donnees.sql")"
passer ace_a "passage-3-avec-donnees" --single-transaction
apres="$(q ace_a -Atf "$ICI/verif-donnees.sql")"
echo "  avant : $avant"
echo "  après : $apres"
[ "$avant" = "$apres" ] && echo "  ✓ données intactes" || { echo "  ✗ les données ont changé"; exit 1; }

echo "5. Remise à zéro"
q ace_a -q -f "$RACINE/supabase/remise-a-zero.sql" > "$DATA/remise.log" 2>&1
[ "$(q ace_a -Atc 'select count(*) from public.leads')" = "0" ] && echo "  ✓ plus aucun lead"

echo "Tout est passé."
