#!/usr/bin/env bash
# Lance tout d'un coup: ./start.sh   (arrêt: ./start.sh stop)
set -u
cd "$(dirname "$0")"
mkdir -p .run

if [ "${1:-}" = stop ]; then
  for f in .run/*.pid; do [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null && rm -f "$f"; done
  echo "Arrêté."; exit 0
fi

# 1. Plugins Claude Code (ponytail, lemo-opuscar sont déjà dans .claude/settings.json; unslop s'ajoute ici)
if command -v claude >/dev/null; then
  claude plugin marketplace add heydamir/unslop >/dev/null 2>&1
  claude plugin install unslop@heydamir --scope project 2>&1 | tail -1
fi

# 2. Sellbird: venv + dashboard + connexion à vos agents (demande un oui)
[ -d .venv ] || python3 -m venv .venv
. .venv/bin/activate
command -v sellbird >/dev/null || pip install -q -e .
nohup sellbird dashboard >.run/sellbird.log 2>&1 & echo $! >.run/sellbird.pid
sellbird connect
echo "Sellbird: lien du dashboard avec 'sellbird dashboard --url'"

# 3. freellmapi: API gratuite sur http://localhost:3001/v1
(cd freellmapi
 [ -d node_modules ] || npm install --no-audit --no-fund
 [ -f .env ] || { cp .env.example .env
   sed -i "s|^ENCRYPTION_KEY=.*|ENCRYPTION_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")|" .env; }
 nohup npm run dev -w server >../.run/freellmapi.log 2>&1 & echo $! >../.run/freellmapi.pid)
echo "freellmapi: http://localhost:3001/v1"
echo "Redémarrez Claude Code/desktop pour charger les plugins et Sellbird."
