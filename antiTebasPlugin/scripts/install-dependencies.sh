#!/bin/bash
#
# AntiTebas Plugin - Script de instalación de dependencias
# Instala automáticamente todos los requisitos necesarios
#

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

echo -e "${BLUE}=== AntiTebas Plugin - Instalador de Dependencias ===${NC}"
echo

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root"
   echo "Usa: sudo $0"
   exit 1
fi

# Detectar distribución
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="$ID"
    VERSION="$VERSION_ID"
    log "Distribución detectada: $NAME $VERSION"
else
    error "No se pudo detectar la distribución del sistema"
    exit 1
fi

# ==============================================
# ACTUALIZACIÓN DEL SISTEMA
# ==============================================

log "Actualizando repositorios del sistema..."

case $DISTRO in
    ubuntu|debian|raspbian)
        apt-get update
        log "Repositorios actualizados (apt)"
        ;;
    centos|rhel|rocky|almalinux)
        yum update -y || dnf update -y
        log "Repositorios actualizados (yum/dnf)"
        ;;
    arch|manjaro)
        pacman -Sy
        log "Repositorios actualizados (pacman)"
        ;;
    *)
        warn "Distribución no reconocida: $DISTRO"
        warn "Instalación manual requerida"
        ;;
esac

# ==============================================
# INSTALACIÓN DE HERRAMIENTAS BÁSICAS
# ==============================================

log "Instalando herramientas básicas..."

case $DISTRO in
    ubuntu|debian|raspbian)
        apt-get install -y \
            curl wget git nano vim \
            python3 python3-pip python3-venv \
            iptables netfilter-persistent \
            netcat-openbsd net-tools dnsutils \
            cron logrotate sudo \
            ca-certificates gnupg lsb-release \
            software-properties-common apt-transport-https
        ;;
    centos|rhel|rocky|almalinux)
        yum install -y \
            curl wget git nano vim \
            python3 python3-pip \
            iptables iptables-services \
            netcat net-tools bind-utils \
            cronie logrotate sudo \
            ca-certificates gnupg \
            yum-utils device-mapper-persistent-data lvm2 \
        || dnf install -y \
            curl wget git nano vim \
            python3 python3-pip \
            iptables iptables-services \
            netcat net-tools bind-utils \
            cronie logrotate sudo \
            ca-certificates gnupg \
            dnf-plugins-core device-mapper-persistent-data lvm2
        ;;
    arch|manjaro)
        pacman -S --noconfirm \
            curl wget git nano vim \
            python python-pip \
            iptables netfilter-utils \
            netcat net-tools dnsutils \
            cronie logrotate sudo \
            ca-certificates gnupg
        ;;
esac

log "Herramientas básicas instaladas"

# ==============================================
# INSTALACIÓN DE LIBRERÍAS PYTHON
# ==============================================

log "Instalando librerías Python..."

# Actualizar pip
python3 -m pip install --upgrade pip

# Instalar librerías requeridas
python3 -m pip install \
    requests \
    psutil \
    pathlib2

log "Librerías Python instaladas"

# ==============================================
# CONFIGURACIÓN DE IPTABLES
# ==============================================

log "Configurando iptables..."

# Habilitar IP forwarding
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p

# Habilitar servicios iptables
case $DISTRO in
    ubuntu|debian|raspbian)
        systemctl enable netfilter-persistent
        ;;
    centos|rhel|rocky|almalinux)
        systemctl enable iptables
        systemctl start iptables
        ;;
    arch|manjaro)
        systemctl enable iptables
        ;;
esac

log "Configuración de red completada"

# ==============================================
# INSTALACIÓN DE DOCKER (OPCIONAL)
# ==============================================

read -p "¿Instalar Docker para el proxy WARP? (y/N): " install_docker
if [[ $install_docker =~ ^[Yy]$ ]]; then
    log "Instalando Docker..."
    
    case $DISTRO in
        ubuntu|debian|raspbian)
            # Añadir repositorio Docker oficial
            curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
        centos|rhel|rocky|almalinux)
            # Usar script de instalación oficial
            curl -fsSL https://get.docker.com | sh
            ;;
        arch|manjaro)
            pacman -S --noconfirm docker docker-compose
            ;;
        *)
            warn "Instalación automática de Docker no disponible para $DISTRO"
            info "Instalar manualmente: curl -fsSL https://get.docker.com | sh"
            ;;
    esac
    
    # Configurar Docker
    systemctl enable docker
    systemctl start docker
    
    # Añadir usuario pi al grupo docker si existe
    if id "pi" &>/dev/null; then
        usermod -aG docker pi
        log "Usuario 'pi' añadido al grupo docker"
    fi
    
    # Verificar instalación
    if docker --version && docker compose version; then
        log "Docker instalado correctamente"
    else
        error "Error instalando Docker"
    fi
else
    info "Saltando instalación de Docker"
fi

# ==============================================
# VERIFICACIÓN FINAL
# ==============================================

log "Verificando instalación..."

# Ejecutar script de verificación si existe
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/verify-requirements.sh" ]; then
    log "Ejecutando verificación de requisitos..."
    bash "$SCRIPT_DIR/verify-requirements.sh"
else
    info "Script de verificación no encontrado - verificando manualmente..."
    
    # Verificaciones básicas
    python3 -c "import requests, socket, threading" && log "✓ Python y librerías OK"
    iptables -t nat -L > /dev/null && log "✓ iptables OK"
    curl -s https://1.1.1.1 > /dev/null && log "✓ Conectividad OK"
fi

echo
log "🎉 Instalación de dependencias completada"
echo -e "${GREEN}El sistema está listo para instalar AntiTebas Plugin${NC}"
echo
echo -e "${BLUE}Siguiente paso:${NC}"
echo "1. Copiar antiTebasPlugin/ al servidor Pi-hole"
echo "2. Ejecutar: cd antiTebasPlugin && sudo ./install-plugin.sh"
echo