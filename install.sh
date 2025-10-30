#!/bin/bash

# Script de instalación rápida para AntiTebas Plugin

echo "=== Instalador AntiTebas Plugin ==="
echo

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no encontrado. Por favor instalar Docker primero."
    echo "   Visita: https://docs.docker.com/get-docker/"
    exit 1
fi

# Verificar Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose no encontrado. Por favor instalar Docker Compose."
    exit 1
fi

echo "✅ Docker y Docker Compose encontrados"

# Verificar permisos de administrador
if [[ $EUID -ne 0 ]]; then
   echo "⚠️  Este script necesita permisos de administrador para configurar iptables"
   echo "   Ejecuta: sudo $0"
   exit 1
fi

echo "✅ Permisos de administrador verificados"

# Crear archivo .env si no existe
if [ ! -f .env ]; then
    echo "📝 Creando archivo de configuración..."
    cp .env.example .env
    
    echo
    echo "🔧 Configuración requerida:"
    echo "   1. Edita el archivo .env con tu configuración"
    echo "   2. Configura PIHOLE_HOST con la IP de tu Pi-hole"
    echo "   3. Opcionalmente configura WARP_TEAM_ID y WARP_LICENSE_KEY"
    echo
    read -p "¿Quieres abrir el archivo .env ahora? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} .env
    fi
else
    echo "✅ Archivo .env ya existe"
fi

# Crear directorios necesarios
echo "📁 Creando directorios..."
mkdir -p logs config/warp config/pihole

# Configurar permisos
echo "🔐 Configurando permisos..."
chown -R 1000:1000 logs config



# Construir imágenes
echo "🏗️  Construyendo imágenes Docker..."
if docker-compose build; then
    echo "✅ Imágenes construidas exitosamente"
else
    echo "❌ Error construyendo imágenes"
    exit 1
fi

# Iniciar servicios
echo "🚀 Iniciando servicios..."
if docker-compose up -d; then
    echo "✅ Servicios iniciados"
else
    echo "❌ Error iniciando servicios"
    exit 1
fi

# Esperar a que los servicios estén listos
echo "⏳ Esperando a que los servicios estén listos..."
sleep 10

# Verificar estado
echo "🔍 Verificando estado de los servicios..."
docker-compose ps

echo
echo "🎉 ¡Proxy WARP instalado correctamente!"
echo
echo "📋 Próximos pasos:"
echo "   1. Instalar plugin en Pi-hole: ./install-pihole-plugin.sh"
echo "   2. Verificar logs: docker-compose logs -f"
echo "   3. Probar conectividad: make test-warp"
echo
echo "📚 Para más información consulta README.md"
echo
echo "🆘 Comandos útiles:"
echo "   - Ver logs: docker-compose logs -f"
echo "   - Parar: docker-compose down"
echo "   - Reiniciar: docker-compose restart"
echo "   - Probar WARP: make test-warp"