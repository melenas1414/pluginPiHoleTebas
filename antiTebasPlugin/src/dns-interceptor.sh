#!/bin/bash
#
# AntiTebas Integration Script
# DNS Interceptor para Pi-hole Plugin
#
# Intercepta consultas DNS y coordina con el servidor WARP
#
#

# Configuración
PLUGIN_DIR="/etc/pihole/plugins/warp"
CONFIG_FILE="$PLUGIN_DIR/warp-config.conf"
QUERY_LOG="/var/log/pihole.log"

# Cargar configuración
source "$CONFIG_FILE" 2>/dev/null || exit 1

# Función de logging
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [INTERCEPT] $message" >> "$LOG_FILE"
}

# Función para verificar si un dominio está en la lista WARP
is_warp_domain() {
    local domain="$1"
    
    # Verificar en lista local
    if [ -f "$DOMAIN_LIST_FILE" ]; then
        if grep -Fxq "$domain" "$DOMAIN_LIST_FILE" 2>/dev/null; then
            return 0
        fi
        
        # Verificar subdominios
        while IFS= read -r listed_domain; do
            [[ -z "$listed_domain" || "$listed_domain" =~ ^[[:space:]]*# ]] && continue
            if [[ "$domain" == *".$listed_domain" ]]; then
                return 0
            fi
        done < "$DOMAIN_LIST_FILE"
    fi
    
    return 1
}

# Función para notificar al servidor WARP sobre una consulta
notify_warp_server() {
    local domain="$1"
    local client_ip="$2"
    local query_type="$3"
    
    # Enviar notificación al servidor WARP
    curl -s -X POST \
         -H "Content-Type: application/json" \
         -d "{\"domain\":\"$domain\",\"client\":\"$client_ip\",\"type\":\"$query_type\",\"timestamp\":\"$(date -Iseconds)\"}" \
         "http://$TRAFFIC_MANAGER_HOST:$TRAFFIC_MANAGER_PORT/api/query" \
         >/dev/null 2>&1 || true
}

# Función principal de intercepción
intercept_query() {
    local domain="$1"
    local client_ip="$2"
    local query_type="${3:-A}"
    
    # Verificar si es un dominio WARP
    if is_warp_domain "$domain"; then
        log_message "INFO" "Dominio WARP detectado: $domain (cliente: $client_ip)"
        
        # Notificar al servidor WARP
        notify_warp_server "$domain" "$client_ip" "$query_type"
        
        # Resolver normalmente pero marcar para routing
        return 0
    fi
    
    return 1
}

# Función para monitorear logs de Pi-hole en tiempo real
monitor_queries() {
    log_message "INFO" "Iniciando monitor de consultas DNS"
    
    # Monitorear el log de Pi-hole
    tail -F "$QUERY_LOG" 2>/dev/null | while read -r line; do
        # Parsear línea del log de Pi-hole
        # Formato típico: timestamp query[A] domain from client
        if echo "$line" | grep -q "query\["; then
            # Extraer información de la consulta
            timestamp=$(echo "$line" | awk '{print $1, $2}')
            query_info=$(echo "$line" | grep -o "query\[[^]]*\]")
            query_type=$(echo "$query_info" | sed 's/query\[\([^]]*\)\]/\1/')
            domain=$(echo "$line" | awk '{for(i=1;i<=NF;i++) if($i ~ /query\[/) print $(i+1)}' | head -1)
            client_ip=$(echo "$line" | awk '{print $NF}')
            
            # Procesar solo si tenemos toda la información
            if [ -n "$domain" ] && [ -n "$client_ip" ]; then
                intercept_query "$domain" "$client_ip" "$query_type"
            fi
        fi
    done
}

# Función para verificar estado del servidor WARP
check_warp_server() {
    if nc -z "$TRAFFIC_MANAGER_HOST" "$TRAFFIC_MANAGER_PORT" 2>/dev/null; then
        return 0
    else
        log_message "WARNING" "Servidor WARP no accesible en $TRAFFIC_MANAGER_HOST:$TRAFFIC_MANAGER_PORT"
        return 1
    fi
}

# Función principal
main() {
    case "${1:-monitor}" in
        "monitor")
            if check_warp_server; then
                monitor_queries
            else
                log_message "ERROR" "No se puede iniciar monitor - Servidor WARP no disponible"
                exit 1
            fi
            ;;
        "check")
            check_warp_server && echo "Servidor WARP disponible" || echo "Servidor WARP no disponible"
            ;;
        "test")
            local test_domain="${2:-google.com}"
            local test_client="${3:-127.0.0.1}"
            echo "Probando intercepción para: $test_domain"
            intercept_query "$test_domain" "$test_client" "A"
            ;;
        *)
            echo "Uso: $0 [monitor|check|test [domain]]"
            echo "  monitor - Monitorear consultas DNS en tiempo real"
            echo "  check   - Verificar conectividad con servidor WARP"
            echo "  test    - Probar intercepción de dominio"
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"