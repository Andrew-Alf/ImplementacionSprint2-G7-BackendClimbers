#!/bin/bash
# ============================================================
# BITEco — Experimento de Escalabilidad
# Este script corre automáticamente cuando EC2 arranca.
# Instala Python, escribe la app y la deja corriendo.
# Variables que inyecta Terraform: app_port, database_url
# ============================================================

set -e

# ── 1. Instalar Python y pip ─────────────────────────────────
dnf update -y
dnf install -y python3 python3-pip

# ── 2. Instalar dependencias de FastAPI ──────────────────────
pip3 install \
  fastapi==0.111.0 \
  "uvicorn[standard]==0.30.1" \
  asyncpg==0.29.0 \
  pydantic==2.7.1

# ── 3. Escribir el código de la app en disco ─────────────────
mkdir -p /opt/biteco

cat > /opt/biteco/main.py << 'PYEOF'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import asyncpg, os

app = FastAPI()
DATABASE_URL = os.getenv("DATABASE_URL")
pool = None

@app.on_event("startup")
async def startup():
    global pool
    pool = await asyncpg.create_pool(
        DATABASE_URL,
        min_size=2,
        max_size=10,
        command_timeout=30,
    )
    async with pool.acquire() as conn:
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS usuarios (
                id         SERIAL PRIMARY KEY,
                nombre     VARCHAR(100) NOT NULL,
                email      VARCHAR(150) UNIQUE NOT NULL,
                empresa_id INTEGER NOT NULL,
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)

@app.on_event("shutdown")
async def shutdown():
    if pool:
        await pool.close()

class UsuarioCreate(BaseModel):
    nombre:     str
    email:      str
    empresa_id: int

@app.post("/usuarios", status_code=201)
async def crear_usuario(u: UsuarioCreate):
    try:
        r = await pool.fetchrow(
            "INSERT INTO usuarios (nombre, email, empresa_id) VALUES ($1, $2, $3) RETURNING id, created_at",
            u.nombre, u.email, u.empresa_id,
        )
        return {
            "id": r["id"], "nombre": u.nombre, "email": u.email,
            "empresa_id": u.empresa_id, "created_at": str(r["created_at"]),
            "mensaje": "Usuario registrado exitosamente",
        }
    except asyncpg.UniqueViolationError:
        raise HTTPException(status_code=409, detail="Email ya registrado")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "ok", "service": "manejador-usuarios"}
PYEOF

# ── 4. Crear servicio systemd para que la app corra siempre ──
cat > /etc/systemd/system/biteco.service << SVCEOF
[Unit]
Description=BITEco Manejador Usuarios
After=network.target

[Service]
Environment="DATABASE_URL=${database_url}"
WorkingDirectory=/opt/biteco
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port ${app_port} --workers 4
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

# ── 5. Arrancar la app ───────────────────────────────────────
systemctl daemon-reload
systemctl enable biteco
systemctl start biteco
