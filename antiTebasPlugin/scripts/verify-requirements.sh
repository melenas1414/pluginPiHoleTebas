#!/bin/bash
#
# AntiTebas Plugin - Script de verificación de requisitos
# Verifica que el sistema cumple todos los requisitos necesarios
#

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Función para logging
check_ok() {
    echo -e "${GREEN}✓${NC} $1"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((CHECKS_WARNING++))
}

check_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

echo -e "${BLUE}=== AntiTebas Plugin - Verificación de Requisitos ===${NC}"
echo

# ==============================================
# VERIFICACIÓN DEL SISTEMA OPERATIVO
# ==============================================

echo -e "${BLUE}📊 Sistema Operativo${NC}"

# Detectar distribución
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="$NAME"
    OS_VERSION="$VERSION"
    check_ok "Sistema detectado: $OS_NAME $OS_VERSION"
else
    check_warn "No se pudo detectar la distribución del sistema"
fi

# Verificar arquitectura
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64)
        check_ok "Arquitectura compatible: $ARCH"
        ;;
    aarch64|arm64|armv7l)
        check_ok "Arquitectura ARM compatible: $ARCH"
        ;;
    *)
        check_warn "Arquitectura no probada: $ARCH"
        ;;
esac

echo

# ==============================================
# VERIFICACIÓN DE HARDWARE
# ==============================================

echo -e "${BLUE}🖥️ Hardware${NC}"

# Verificar RAM
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))

if [ $TOTAL_RAM_MB -ge 1024 ]; then
    check_ok "RAM: ${TOTAL_RAM_MB}MB (óptimo)"
elif [ $TOTAL_RAM_MB -ge 512 ]; then
    check_warn "RAM: ${TOTAL_RAM_MB}MB (mínimo - se recomienda 1GB+)"
else
    check_fail "RAM: ${TOTAL_RAM_MB}MB (insuficiente - mínimo 512MB)"
fi

# Verificar espacio en disco
DISK_USAGE=$(df /etc 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")
DISK_AVAIL_KB=$(df /etc 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
DISK_AVAIL_MB=$((DISK_AVAIL_KB / 1024))

if [ $DISK_AVAIL_MB -ge 2048 ]; then
    check_ok "Espacio en disco: ${DISK_AVAIL_MB}MB disponibles"
elif [ $DISK_AVAIL_MB -ge 1024 ]; then
    check_warn "Espacio en disco: ${DISK_AVAIL_MB}MB disponibles (se recomienda 2GB+)"
else
    check_fail "Espacio en disco: ${DISK_AVAIL_MB}MB disponibles (insuficiente - mínimo 2GB)"
fi

echo

# ==============================================
# VERIFICACIÓN DE PI-HOLE
# ==============================================

echo -e "${BLUE}🕳️ Pi-hole${NC}"

# Verificar instalación Pi-hole
if [ -d "/etc/pihole" ]; then
    check_ok "Directorio Pi-hole encontrado: /etc/pihole"
else
    check_fail "Pi-hole no encontrado - instalar desde https://pi-hole.net"
fi

# Verificar servicio Pi-hole
if command -v pihole >/dev/null 2>&1; then
    PIHOLE_STATUS=$(pihole status 2>/dev/null | grep -o "Enabled\|Disabled" || echo "Unknown")
    if [ "$PIHOLE_STATUS" = "Enabled" ]; then
        check_ok "Pi-hole activo y funcionando"
    else
        check_warn "Pi-hole instalado pero no activo: $PIHOLE_STATUS"
    fi
else
    check_fail "Comando 'pihole' no encontrado"
fi

# Verificar web admin Pi-hole
for PORT in 80 8080 443; do
    if netstat -tlnp 2>/dev/null | grep -q ":$PORT.*lighttpd\|:$PORT.*nginx"; then
        check_ok "Pi-hole web accesible en puerto $PORT"
        break
    fi
done

# Verificar DNS Pi-hole
if netstat -ulnp 2>/dev/null | grep -q ":53.*pihole-FTL"; then
    check_ok "Pi-hole DNS funcionando en puerto 53"
else
    check_warn "Pi-hole DNS no detectado en puerto estándar 53"
fi

echo

# ==============================================
# VERIFICACIÓN DE SOFTWARE
# ==============================================

echo -e "${BLUE}⚙️ Software Requerido${NC}"

# Verificar herramientas esenciales
for cmd in curl wget git python3 iptables netcat nc; do
    if command -v $cmd >/dev/null 2>&1; then
        VERSION=$($cmd --version 2>/dev/null | head -1 | cut -d' ' -f2- || "")
        check_ok "$cmd instalado"
    else
        check_fail "$cmd no encontrado - instalar con: apt install $cmd"
    fi
done

# Verificar Python 3
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    if python3 -c "import sys; exit(0 if sys.version_info >= (3,6) else 1)" 2>/dev/null; then
        check_ok "Python $PYTHON_VERSION (compatible)"
    else
        check_fail "Python $PYTHON_VERSION (se requiere Python 3.6+)"
    fi
fi

# Verificar pip3
if command -v pip3 >/dev/null 2>&1; then
    check_ok "pip3 instalado"
else
    check_fail "pip3 no encontrado - instalar con: apt install python3-pip"
fi

# Verificar librerías Python
echo -e "\n${BLUE}🐍 Librerías Python${NC}"
for module in requests socket threading subprocess pathlib datetime; do
    if python3 -c "import $module" 2>/dev/null; then
        check_ok "Módulo Python: $module"
    else
        check_fail "Módulo Python faltante: $module"
    fi
done

echo

# ==============================================
# VERIFICACIÓN DE RED
# ==============================================

echo -e "${BLUE}🌐 Configuración de Red${NC}"

# Verificar IP forwarding
if [ "$(sysctl -n net.ipv4.ip_forward)" = "1" ]; then
    check_ok "IP forwarding habilitado"
else
    check_warn "IP forwarding deshabilitado - se habilitará durante la instalación"
fi

# Verificar iptables
if iptables -t nat -L >/dev/null 2>&1; then
    check_ok "iptables accesible (requiere sudo)"
else
    check_fail "iptables no accesible - verificar permisos sudo"
fi

# Verificar conectividad internet
if curl -s --connect-timeout 5 https://1.1.1.1 >/dev/null 2>&1; then
    check_ok "Conectividad internet (HTTPS)"
elif curl -s --connect-timeout 5 http://1.1.1.1 >/dev/null 2>&1; then
    check_warn "Conectividad internet (HTTP solamente)"
else
    check_fail "Sin conectividad internet - verificar configuración de red"
fi

# Verificar resolución DNS
if nslookup cloudflare.com >/dev/null 2>&1; then
    check_ok "Resolución DNS funcionando"
else
    check_warn "Problemas con resolución DNS"
fi

echo

# ==============================================
# VERIFICACIÓN DE DOCKER (OPCIONAL)
# ==============================================

echo -e "${BLUE}🐳 Docker (Opcional)${NC}"

if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version 2>/dev/null | cut -d' ' -f3 | sed 's/,//')
    if docker ps >/dev/null 2>&1; then
        check_ok "Docker $DOCKER_VERSION funcionando"
    else
        check_warn "Docker instalado pero sin permisos - añadir usuario al grupo docker"
    fi
    
    # Verificar Docker Compose
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version --short 2>/dev/null)
        check_ok "Docker Compose $COMPOSE_VERSION disponible"
    else
        check_warn "Docker Compose no encontrado - instalar plugin"
    fi
else
    check_warn "Docker no instalado - necesario para proxy WARP"
fi

echo

# ==============================================
# VERIFICACIÓN DE PERMISOS
# ==============================================

echo -e "${BLUE}🔐 Permisos${NC}"

# Verificar si se ejecuta como root
if [ "$EUID" -eq 0 ]; then
    check_ok "Ejecutándose como root"
else
    check_info "Ejecutándose como usuario $(whoami)"
    
    # Verificar sudo
    if sudo -n true 2>/dev/null; then
        check_ok "Acceso sudo sin password"
    else
        check_warn "Se requerirá password para sudo durante la instalación"
    fi
fi

# Verificar escritura en /etc/pihole
if [ -w "/etc/pihole" ] || sudo -n test -w "/etc/pihole" 2>/dev/null; then
    check_ok "Permisos de escritura en /etc/pihole"
else
    check_fail "Sin permisos de escritura en /etc/pihole"
fi

echo

# ==============================================
# RESUMEN DE RESULTADOS
# ==============================================

echo -e "${BLUE}📊 Resumen de Verificación${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $CHECKS_FAILED -eq 0 ]; then
    if [ $CHECKS_WARNING -eq 0 ]; then
        echo -e "${GREEN}🎉 Todos los requisitos cumplidos${NC}"
        echo -e "✅ $CHECKS_PASSED verificaciones pasadas"
        echo -e "El sistema está listo para instalar AntiTebas Plugin"
        exit 0
    else
        echo -e "${YELLOW}⚠️ Sistema compatible con advertencias${NC}"
        echo -e "✅ $CHECKS_PASSED verificaciones pasadas"
        echo -e "⚠️ $CHECKS_WARNING advertencias encontradas"
        echo -e "El plugin funcionará, pero se recomiendan mejoras"
        exit 0
    fi
else
    echo -e "${RED}❌ Requisitos faltantes encontrados${NC}"
    echo -e "✅ $CHECKS_PASSED verificaciones pasadas"
    echo -e "⚠️ $CHECKS_WARNING advertencias"
    echo -e "❌ $CHECKS_FAILED verificaciones fallidas"
    echo -e "\nCorregir los errores antes de la instalación"
    exit 1
fi