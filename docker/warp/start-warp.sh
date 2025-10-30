#!/bin/bash

echo "Iniciando Cloudflare WARP..."

# Verificar si ya está registrado
if [ ! -f "/config/warp-settings.json" ]; then
    echo "Registrando WARP por primera vez..."
    warp-cli registration new
    
    # Si hay credenciales de Teams, configurarlas
    if [ -n "$WARP_TEAM_ID" ] && [ -n "$WARP_LICENSE_KEY" ]; then
        echo "Configurando WARP Teams..."
        warp-cli teams-enroll "$WARP_TEAM_ID"
    fi
    
    # Guardar configuración
    cp ~/.local/share/warp/settings.json /config/warp-settings.json 2>/dev/null || true
else
    echo "Restaurando configuración de WARP..."
    mkdir -p ~/.local/share/warp
    cp /config/warp-settings.json ~/.local/share/warp/settings.json 2>/dev/null || true
fi

# Configurar modo proxy
warp-cli mode proxy

# Conectar
echo "Conectando a WARP..."
warp-cli connect

# Verificar conexión
sleep 5
if warp-cli status | grep -q "Connected"; then
    echo "WARP conectado exitosamente"
else
    echo "Error: No se pudo conectar a WARP"
    exit 1
fi

# Habilitar IP forwarding para transparent proxy
echo 1 > /proc/sys/net/ipv4/ip_forward

# Mantener el proceso corriendo
while true; do
    if ! warp-cli status | grep -q "Connected"; then
        echo "Reconectando WARP..."
        warp-cli connect
    fi
    sleep 30
done