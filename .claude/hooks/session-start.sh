#!/bin/bash
set -euo pipefail

# Only run in Claude Code on the web (remote environment)
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "==> [session-start] Iniciando entorno Zack's Retail en la nube..."

# ── 1. PostgreSQL ────────────────────────────────────────────────────────────
echo "==> [session-start] Levantando PostgreSQL..."
service postgresql start

# Crear usuario y base de datos si no existen
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='zacks'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER zacks WITH PASSWORD 'zacks_dev';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='zacks_retail'" | grep -q 1 || \
  sudo -u postgres createdb -O zacks zacks_retail

# ── 2. Variables de entorno ──────────────────────────────────────────────────
echo "==> [session-start] Escribiendo .env..."
API_ENV="$CLAUDE_PROJECT_DIR/apps/api/.env"

if [ ! -f "$API_ENV" ]; then
  cat > "$API_ENV" << 'ENVEOF'
PORT=4000
DATABASE_URL=postgresql://zacks:zacks_dev@localhost:5432/zacks_retail?schema=public
PRODUCT_SOURCE=rics
INVENTORY_SOURCE=rics
SALES_SOURCE=rics
SESSION_COOKIE_SECRET=dev-secret-local
ANTHROPIC_API_KEY=
SKU_INQUIRY_AI_MODEL=claude-sonnet-4-6
AUTH_SESSION_SECRET=dev-auth-secret-local
AUTH_SESSION_TTL_HOURS=12
AUTH_OWNER_EMAIL=owner@example.com
AUTH_OWNER_PASSWORD=change-me-on-first-login
AUTH_OWNER_NAME=Owner
RICS_DB_DIR=
RICS_MDB_PASSWORD=
ENVEOF
fi

# Exportar DATABASE_URL para que prisma lo use en este script
export DATABASE_URL="postgresql://zacks:zacks_dev@localhost:5432/zacks_retail?schema=public"
echo "export DATABASE_URL=\"postgresql://zacks:zacks_dev@localhost:5432/zacks_retail?schema=public\"" >> "$CLAUDE_ENV_FILE"

# ── 3. Instalar dependencias ─────────────────────────────────────────────────
echo "==> [session-start] Instalando dependencias (pnpm install)..."
cd "$CLAUDE_PROJECT_DIR"
pnpm install --frozen-lockfile

# ── 4. Generar cliente Prisma y correr migraciones ───────────────────────────
echo "==> [session-start] Generando Prisma client y aplicando migraciones..."
cd "$CLAUDE_PROJECT_DIR/apps/api"
pnpm prisma generate --generator apiClient
pnpm prisma migrate deploy

echo "==> [session-start] ✅ Entorno listo. API en puerto 4000, Postgres en 5432."
