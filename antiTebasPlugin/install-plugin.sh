#!/bin/bash
#
# AntiTebas Plugin - Script de instalación
# Este script instala el plugin en Pi-hole para integración con WARP
#

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
PIHOLE_DIR="/etc/pihole"
PLUGIN_DIR="/etc/pihole/plugins/warp"
DNSMASQ_DIR="/etc/dnsmasq.d"
CRON_DIR="/etc/cron.d"

echo -e "${GREEN}=== Instalador AntiTebas Plugin ===${NC}"
echo

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script debe ejecutarse como root${NC}"
   echo "Usa: sudo $0"
   exit 1
fi

# Verificar que Pi-hole está instalado
if [ ! -d "$PIHOLE_DIR" ]; then
    echo -e "${RED}Pi-hole no encontrado en $PIHOLE_DIR${NC}"
    echo "Asegúrate de que Pi-hole esté instalado correctamente"
    exit 1
fi

echo -e "${GREEN}✓${NC} Pi-hole encontrado"

# Crear directorio del plugin
echo "Creando directorio del plugin..."
mkdir -p "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR/logs"
mkdir -p "$PLUGIN_DIR/lists"

# Copiar archivos del plugin
echo "Instalando archivos del plugin..."
cp -r src/* "$PLUGIN_DIR/"
cp config/* "$PLUGIN_DIR/"

# Hacer ejecutables los scripts
chmod +x "$PLUGIN_DIR"/*.sh
chmod +x "$PLUGIN_DIR"/scripts/*.sh

# ==============================================
# CONFIGURACIÓN INTERACTIVA DE PI-HOLE
# ==============================================

echo -e "\n${GREEN}=== CONFIGURACIÓN DE PI-HOLE ===${NC}"

# Detectar puerto Pi-hole automáticamente
echo "Detectando configuración de Pi-hole..."
DETECTED_PORT=""
PIHOLE_SSL="false"

# Verificar puertos comunes
if netstat -tlnp 2>/dev/null | grep -q ":80.*lighttpd\|:80.*nginx"; then
    DETECTED_PORT="80"
elif netstat -tlnp 2>/dev/null | grep -q ":8080.*lighttpd\|:8080.*nginx"; then
    DETECTED_PORT="8080"
elif netstat -tlnp 2>/dev/null | grep -q ":443.*lighttpd\|:443.*nginx"; then
    DETECTED_PORT="443"
    PIHOLE_SSL="true"
fi

# Configurar host Pi-hole
echo "Introduce la configuración de Pi-hole:"
read -p "Host de Pi-hole (IP o hostname) [localhost]: " PIHOLE_HOST
PIHOLE_HOST=${PIHOLE_HOST:-localhost}

# Configurar puerto Pi-hole
if [[ -n "$DETECTED_PORT" ]]; then
    echo -e "${GREEN}✓${NC} Puerto Pi-hole detectado automáticamente: $DETECTED_PORT"
    read -p "¿Es correcto el puerto $DETECTED_PORT? (Y/n): " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        DETECTED_PORT=""
    fi
fi

if [[ -z "$DETECTED_PORT" ]]; then
    echo "Puertos comunes de Pi-hole:"
    echo "  - 80   (puerto estándar HTTP)"
    echo "  - 8080 (puerto alternativo común)"
    echo "  - 443  (HTTPS)"
    echo "  - Otro puerto personalizado"
    read -p "Puerto Pi-hole [80]: " PIHOLE_PORT
    PIHOLE_PORT=${PIHOLE_PORT:-80}
    
    # Detectar si es HTTPS
    if [[ "$PIHOLE_PORT" == "443" ]]; then
        PIHOLE_SSL="true"
    fi
else
    PIHOLE_PORT=$DETECTED_PORT
fi

# Configurar DNS Port (opcional)
read -p "Puerto DNS de Pi-hole [53]: " PIHOLE_DNS_PORT
PIHOLE_DNS_PORT=${PIHOLE_DNS_PORT:-53}

# Configurar token API (opcional)
echo -e "\n${YELLOW}Nota:${NC} El token API es opcional pero recomendado para funcionalidad avanzada"
echo "Se obtiene en: Pi-hole Admin → Settings → API → Show API Token"
read -p "Token API de Pi-hole (opcional): " PIHOLE_API_TOKEN

# Verificar conectividad
echo -e "\nVerificando conectividad con Pi-hole..."
PROTOCOL="http"
if [[ "$PIHOLE_SSL" == "true" ]]; then
    PROTOCOL="https"
fi

TEST_URL="$PROTOCOL://$PIHOLE_HOST:$PIHOLE_PORT/admin/api.php"
if curl -s --connect-timeout 5 "$TEST_URL" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Pi-hole accesible en $TEST_URL"
else
    echo -e "${YELLOW}⚠${NC} Advertencia: No se pudo verificar conectividad con $TEST_URL"
    read -p "¿Continuar de todos modos? (y/N): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
        echo "Instalación cancelada"
        exit 1
    fi
fi

# ==============================================
# CONFIGURACIÓN DE WARP PROXY
# ==============================================

echo -e "\n${GREEN}=== CONFIGURACIÓN DEL PROXY WARP ===${NC}"
read -p "Host del proxy WARP [localhost]: " WARP_PROXY_HOST
WARP_PROXY_HOST=${WARP_PROXY_HOST:-localhost}

read -p "Puerto SOCKS5 del proxy WARP [1080]: " WARP_PROXY_PORT
WARP_PROXY_PORT=${WARP_PROXY_PORT:-1080}

# Crear archivo de configuración
if [ ! -f "$PLUGIN_DIR/warp-config.conf" ]; then
    echo "Creando configuración del plugin..."
    cat > "$PLUGIN_DIR/warp-config.conf" << EOF
# Configuración AntiTebas Plugin
# Generado automáticamente el $(date)

# ==============================================
# CONFIGURACIÓN PI-HOLE
# ==============================================

PIHOLE_HOST=$PIHOLE_HOST
PIHOLE_PORT=$PIHOLE_PORT
PIHOLE_DNS_PORT=$PIHOLE_DNS_PORT
PIHOLE_SSL=$PIHOLE_SSL
PIHOLE_API_TOKEN=$PIHOLE_API_TOKEN

# URL construida automáticamente
PIHOLE_URL=$PROTOCOL://$PIHOLE_HOST:$PIHOLE_PORT

# ==============================================
# CONFIGURACIÓN WARP PROXY
# ==============================================

WARP_PROXY_HOST=$WARP_PROXY_HOST
WARP_PROXY_PORT=$WARP_PROXY_PORT

# ==============================================
# CONFIGURACIÓN DEL PLUGIN
# ==============================================

# Archivos de listas
DOMAIN_LIST_FILE=$PLUGIN_DIR/lists/warp-domains.txt
IP_LIST_FILE=$PLUGIN_DIR/lists/warp-ips.txt

# Configuración de logging
LOG_FILE=$PLUGIN_DIR/logs/warp-plugin.log
LOG_LEVEL=INFO
MAX_LOG_SIZE=10485760
BACKUP_LOGS=true

# Configuración de funcionamiento
UPDATE_INTERVAL=3600
CHECK_INTERVAL=30
WARP_PLUGIN_ENABLED=true

# URLs de listas externas (separadas por coma)
DOMAIN_LISTS_URLS=https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts

# Configuración avanzada
MONITOR_MODE=realtime
CONNECTION_TIMEOUT=10
MAX_RETRIES=3
DEBUG=false
EOF
fi

# Instalar hook de dnsmasq
echo "Configurando integración con dnsmasq..."
cat > "$DNSMASQ_DIR/99-warp-plugin.conf" << EOF
# AntiTebas Plugin Configuration
# Este archivo es gestionado automáticamente

# Configuración adicional será añadida dinámicamente por el plugin
EOF

# Crear script principal del plugin
cat > "$PLUGIN_DIR/warp-plugin.sh" << 'EOF'
#!/bin/bash
#
# AntiTebas Plugin - Script principal
#

PLUGIN_DIR="/etc/pihole/plugins/warp"
CONFIG_FILE="$PLUGIN_DIR/warp-config.conf"

# Cargar configuración
source "$CONFIG_FILE" 2>/dev/null || {
    echo "Error: No se puede cargar la configuración desde $CONFIG_FILE"
    exit 1
}

# Función de logging
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

# Verificar si el plugin está habilitado
if [ "$WARP_PLUGIN_ENABLED" != "true" ]; then
    log_message "INFO" "Plugin deshabilitado"
    exit 0
fi

# Función principal
main() {
    log_message "INFO" "Iniciando verificación WARP Plugin"
    
    # Verificar conectividad con servidor WARP
    if ! nc -z "$TRAFFIC_MANAGER_HOST" "$TRAFFIC_MANAGER_PORT" 2>/dev/null; then
        log_message "WARNING" "Servidor WARP no accesible en $TRAFFIC_MANAGER_HOST:$TRAFFIC_MANAGER_PORT"
        return 1
    fi
    
    log_message "INFO" "Servidor WARP accesible"
    
    # Sincronizar listas si hay cambios
    "$PLUGIN_DIR/sync-lists.sh"
    
    # Actualizar configuración de dnsmasq si es necesario
    "$PLUGIN_DIR/update-dnsmasq.sh"
    
    log_message "INFO" "Verificación completada"
}

# Ejecutar función principal
main "$@"
EOF

# Crear script de sincronización de listas
cat > "$PLUGIN_DIR/sync-lists.sh" << 'EOF'
#!/bin/bash
#
# Sincronizar listas con servidor WARP
#

PLUGIN_DIR="/etc/pihole/plugins/warp"
CONFIG_FILE="$PLUGIN_DIR/warp-config.conf"
source "$CONFIG_FILE"

# Función de logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SYNC] $1" | tee -a "$LOG_FILE"
}

# Obtener listas del servidor WARP
get_domain_list() {
    curl -s "http://$TRAFFIC_MANAGER_HOST:$TRAFFIC_MANAGER_PORT/api/domains" 2>/dev/null || echo ""
}

get_ip_list() {
    curl -s "http://$TRAFFIC_MANAGER_HOST:$TRAFFIC_MANAGER_PORT/api/ips" 2>/dev/null || echo ""
}

# Sincronizar dominios
log_message "Sincronizando lista de dominios..."
NEW_DOMAINS=$(get_domain_list)
if [ -n "$NEW_DOMAINS" ]; then
    echo "$NEW_DOMAINS" > "$DOMAIN_LIST_FILE.new"
    
    # Verificar si hay cambios
    if ! cmp -s "$DOMAIN_LIST_FILE" "$DOMAIN_LIST_FILE.new" 2>/dev/null; then
        mv "$DOMAIN_LIST_FILE.new" "$DOMAIN_LIST_FILE"
        log_message "Lista de dominios actualizada ($(wc -l < "$DOMAIN_LIST_FILE") dominios)"
        LISTS_UPDATED=true
    else
        rm -f "$DOMAIN_LIST_FILE.new"
        log_message "Lista de dominios sin cambios"
    fi
else
    log_message "WARNING: No se pudo obtener lista de dominios"
fi

# Sincronizar IPs
log_message "Sincronizando lista de IPs..."
NEW_IPS=$(get_ip_list)
if [ -n "$NEW_IPS" ]; then
    echo "$NEW_IPS" > "$IP_LIST_FILE.new"
    
    # Verificar si hay cambios
    if ! cmp -s "$IP_LIST_FILE" "$IP_LIST_FILE.new" 2>/dev/null; then
        mv "$IP_LIST_FILE.new" "$IP_LIST_FILE"
        log_message "Lista de IPs actualizada ($(wc -l < "$IP_LIST_FILE") IPs)"
        LISTS_UPDATED=true
    else
        rm -f "$IP_LIST_FILE.new"
        log_message "Lista de IPs sin cambios"
    fi
else
    log_message "WARNING: No se pudo obtener lista de IPs"
fi

# Si hubo cambios, notificar al sistema
if [ "$LISTS_UPDATED" = "true" ]; then
    log_message "Listas actualizadas - marcando para reconfiguración de dnsmasq"
    touch "$PLUGIN_DIR/.needs_dnsmasq_update"
fi
EOF

# Crear script de actualización de dnsmasq
cat > "$PLUGIN_DIR/update-dnsmasq.sh" << 'EOF'
#!/bin/bash
#
# Actualizar configuración de dnsmasq para WARP
#

PLUGIN_DIR="/etc/pihole/plugins/warp"
CONFIG_FILE="$PLUGIN_DIR/warp-config.conf"
DNSMASQ_CONFIG="/etc/dnsmasq.d/99-warp-plugin.conf"

source "$CONFIG_FILE"

# Función de logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DNSMASQ] $1" | tee -a "$LOG_FILE"
}

# Verificar si necesita actualización
if [ ! -f "$PLUGIN_DIR/.needs_dnsmasq_update" ]; then
    exit 0
fi

log_message "Actualizando configuración de dnsmasq..."

# Crear configuración temporal
TEMP_CONFIG=$(mktemp)

cat > "$TEMP_CONFIG" << EOF
# AntiTebas Plugin Configuration
# Generado automáticamente el $(date)

# Configuración para dominios WARP
EOF

# Agregar configuración para dominios si existe la lista
if [ -f "$DOMAIN_LIST_FILE" ] && [ -s "$DOMAIN_LIST_FILE" ]; then
    log_message "Configurando $(wc -l < "$DOMAIN_LIST_FILE") dominios para WARP"
    
    while IFS= read -r domain; do
        # Saltar líneas vacías y comentarios
        [[ -z "$domain" || "$domain" =~ ^[[:space:]]*# ]] && continue
        
        # Agregar configuración para redirigir consultas DNS
        echo "server=/$domain/127.0.0.1#5335" >> "$TEMP_CONFIG"
        
    done < "$DOMAIN_LIST_FILE"
fi

# Agregar configuración adicional
cat >> "$TEMP_CONFIG" << EOF

# Configuración adicional WARP
log-queries
log-dhcp
EOF

# Verificar si la configuración cambió
if ! cmp -s "$DNSMASQ_CONFIG" "$TEMP_CONFIG" 2>/dev/null; then
    # Hacer backup de la configuración anterior
    if [ -f "$DNSMASQ_CONFIG" ]; then
        cp "$DNSMASQ_CONFIG" "$DNSMASQ_CONFIG.backup.$(date +%s)"
    fi
    
    # Aplicar nueva configuración
    mv "$TEMP_CONFIG" "$DNSMASQ_CONFIG"
    
    log_message "Configuración de dnsmasq actualizada"
    
    # Reiniciar dnsmasq
    if systemctl is-active --quiet pihole-FTL; then
        systemctl reload pihole-FTL
        log_message "pihole-FTL recargado"
    else
        log_message "WARNING: No se pudo recargar pihole-FTL"
    fi
    
    # Marcar como actualizado
    rm -f "$PLUGIN_DIR/.needs_dnsmasq_update"
else
    rm -f "$TEMP_CONFIG"
    log_message "Configuración de dnsmasq sin cambios"
fi
EOF

# Hacer ejecutables los scripts
chmod +x "$PLUGIN_DIR"/*.sh

# Configurar cron para ejecución periódica
echo "Configurando tarea cron..."
cat > "$CRON_DIR/pihole-warp-plugin" << EOF
# AntiTebas Plugin - Verificación periódica
# Ejecutar cada minuto
* * * * * root $PLUGIN_DIR/warp-plugin.sh >/dev/null 2>&1

# Sincronización completa cada 5 minutos
*/5 * * * * root $PLUGIN_DIR/sync-lists.sh >/dev/null 2>&1
EOF

# Reiniciar cron
systemctl restart cron

# Crear listas iniciales vacías si no existen
touch "$PLUGIN_DIR/lists/warp-domains.txt"
touch "$PLUGIN_DIR/lists/warp-ips.txt"

# Configurar permisos
chown -R pihole:pihole "$PLUGIN_DIR" 2>/dev/null || chown -R root:root "$PLUGIN_DIR"
chmod 644 "$PLUGIN_DIR/warp-config.conf"
chmod 755 "$PLUGIN_DIR/logs"

echo
echo -e "${GREEN}✓ Plugin instalado correctamente${NC}"
echo
echo -e "${YELLOW}Configuración necesaria:${NC}"
echo "1. Editar $PLUGIN_DIR/warp-config.conf"
echo "2. Configurar TRAFFIC_MANAGER_HOST con la IP del contenedor Docker"
echo "3. Verificar logs en $PLUGIN_DIR/logs/warp-plugin.log"
echo
echo -e "${YELLOW}Comandos útiles:${NC}"
echo "- Ver estado: $PLUGIN_DIR/warp-plugin.sh"
echo "- Ver logs: tail -f $PLUGIN_DIR/logs/warp-plugin.log"
echo "- Configurar: nano $PLUGIN_DIR/warp-config.conf"
echo
echo -e "${GREEN}El plugin se ejecutará automáticamente cada minuto${NC}"
EOF