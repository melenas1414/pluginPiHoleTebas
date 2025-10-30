#!/bin/bash
#
# Instalación rápida del AntiTebas Plugin
#

echo "=== Instalador AntiTebas Plugin ==="
echo

# Verificar permisos
if [[ $EUID -ne 0 ]]; then
   echo "❌ Este script debe ejecutarse como root"
   echo "   Ejecuta: sudo ./install-plugin.sh"
   exit 1
fi

# Verificar Pi-hole
if [ ! -d "/etc/pihole" ]; then
    echo "❌ Pi-hole no encontrado. Instala Pi-hole primero."
    exit 1
fi

echo "✅ Pi-hole encontrado"

# Ejecutar instalador del plugin
echo "📦 Instalando plugin..."
cd antiTebasPlugin
chmod +x install-plugin.sh
./install-plugin.sh

if [ $? -eq 0 ]; then
    echo
    echo "🎉 ¡Plugin instalado correctamente!"
    echo
    echo "📋 Próximos pasos:"
    echo "1. Configurar servidor WARP host en /etc/pihole/plugins/warp/warp-config.conf"
    echo "2. Iniciar contenedores Docker: make up"
    echo "3. Verificar logs: tail -f /etc/pihole/plugins/warp/logs/warp-plugin.log"
    echo
    echo "🔧 El plugin se ejecutará automáticamente y se conectará al servidor WARP"
else
    echo "❌ Error instalando el plugin"
    exit 1
fi