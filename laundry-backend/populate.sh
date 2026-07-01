#!/bin/bash

# Nama root project
ROOT="."

echo "Membuat struktur project..."

# Membuat folder
mkdir -p "$ROOT/routers"
mkdir -p "$ROOT/services"

# Membuat file di root
touch "$ROOT/requirements.txt"
touch "$ROOT/.env.example"
touch "$ROOT/main.py"
touch "$ROOT/config.py"
touch "$ROOT/database.py"
touch "$ROOT/models.py"
touch "$ROOT/schemas.py"
touch "$ROOT/dependencies.py"
touch "$ROOT/guards.py"
touch "$ROOT/exceptions.py"

# Membuat file di routers
touch "$ROOT/routers/__init__.py"
touch "$ROOT/routers/auth.py"
touch "$ROOT/routers/orders.py"
touch "$ROOT/routers/tracking.py"
touch "$ROOT/routers/customers.py"
touch "$ROOT/routers/edit_requests.py"
touch "$ROOT/routers/analytics.py"

# Membuat file di services
touch "$ROOT/services/__init__.py"
touch "$ROOT/services/order_service.py"
touch "$ROOT/services/edit_request_service.py"
touch "$ROOT/services/analytics_service.py"

echo "✅ Struktur project berhasil dibuat!"
