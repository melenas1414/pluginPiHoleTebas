# AntiTebas Plugin

Este directorio contiene el **plugin específico para Pi-hole** que implementa la redirección selectiva de tráfico a través de Cloudflare WARP.

## ¿Qué hace este plugin?

El plugin se instala **directamente en Pi-hole** y actúa como el **cerebro del sistema**:

1. **Monitorea consultas DNS** en tiempo real desde Pi-hole
2. **Detecta dominios WARP** automáticamente según listas configuradas  
3. **Configura iptables** dinámicamente para redirección selectiva
4. **Gestiona proxy WARP** a través de contenedor Docker simple
5. **Mantiene estadísticas** y logs detallados

## 🚀 Instalación Rápida

### **Opción 1: Instalación Automática (Recomendada)**

```bash
# 1. Copiar plugin al servidor Pi-hole
scp -r antiTebasPlugin/ root@tu-pihole:/tmp/

# 2. En el servidor Pi-hole - Instalar dependencias automáticamente
ssh root@tu-pihole
cd /tmp/antiTebasPlugin/scripts
sudo ./install-dependencies.sh

# 3. Instalar el plugin (detecta configuración automáticamente)
cd /tmp/antiTebasPlugin
sudo ./install-plugin.sh
```

### **Opción 2: Instalación Manual**

```bash
# 1. Verificar requisitos
cd /tmp/antiTebasPlugin/scripts
sudo ./verify-requirements.sh

# 2. Instalar plugin
cd /tmp/antiTebasPlugin
chmod +x install-plugin.sh
sudo ./install-plugin.sh

# 3. Configurar conexión con proxy WARP
nano /etc/pihole/plugins/warp/warp-config.conf
# Cambiar WARP_PROXY_HOST por la IP del servidor Docker
WARP_PROXY_HOST=192.168.1.200  # IP donde corre el contenedor WARP
WARP_PROXY_PORT=1080
```

### **3. Iniciar contenedor WARP (en servidor Docker):**

```bash
# En el servidor donde está el código Docker
cd /ruta/al/proyecto
docker compose up -d warp-proxy
```

## 🏗️ Arquitectura Pi-hole Céntrica

```
[Cliente] → [Router] → [Pi-hole + AntiTebas Plugin] → [Internet/WARP]
                              ↓                           ↑
                       [Detecta dominios]           [Proxy WARP]
                              ↓                           ↑
                       [Configura iptables] ←→ [Contenedor Docker]
```

### **Flujo de trabajo inteligente:**

1. **Cliente solicita dominio** (ej: netflix.com)
2. **Pi-hole resuelve DNS** normalmente  
3. **Plugin AntiTebas detecta** si está en lista WARP
4. **Si es dominio WARP:**
   - Resuelve IPs del dominio
   - Configura reglas iptables dinámicamente  
   - Redirige tráfico específico a proxy WARP
5. **El resto del tráfico** sigue la ruta normal
6. **Estadísticas y logs** se actualizan automáticamente

## 📁 Estructura del Plugin

```
antiTebasPlugin/
├── install-plugin.sh              # 🔧 Instalador automático
├── scripts/
│   ├── verify-requirements.sh     # ✅ Verificador de requisitos  
│   └── install-dependencies.sh    # 📦 Instalador de dependencias
├── src/
│   ├── query-monitor.py          # 🧠 Controlador principal (Python)
│   ├── dns-interceptor.sh        # 🔍 Interceptor DNS (Bash)
│   └── warp-domains              # 🛠️ Herramienta de gestión
├── config/
│   └── warp-config.conf          # ⚙️ Configuración del plugin
└── README.md                     # 📖 Esta documentación
```

## 🔧 Comandos y Gestión

### **Herramienta principal: warp-domains**

```bash
# Verificar estado del proxy WARP
sudo /etc/pihole/plugins/warp/src/warp-domains check

# Actualizar listas de dominios  
sudo /etc/pihole/plugins/warp/src/warp-domains update

# Agregar dominio específico
sudo /etc/pihole/plugins/warp/src/warp-domains add netflix.com

# Eliminar dominio
sudo /etc/pihole/plugins/warp/src/warp-domains remove netflix.com

# Probar si un dominio usa WARP
sudo /etc/pihole/plugins/warp/src/warp-domains test google.com

# Ver estadísticas
sudo /etc/pihole/plugins/warp/src/warp-domains stats
```

### **Monitoreo y logs**

```bash
# Ver logs en tiempo real
tail -f /etc/pihole/plugins/warp/logs/warp-plugin.log

# Ver logs del controlador Python
sudo journalctl -f -u antitebas-plugin

# Ver estadísticas de uso
sudo /etc/pihole/plugins/warp/src/query-monitor.py stats

# Verificar conectividad completa
sudo /etc/pihole/plugins/warp/src/query-monitor.py check
```

## ✨ Integración con Pi-hole

El plugin **extiende Pi-hole** sin reemplazarlo:

- ✅ **Mantiene todas las funciones** de Pi-hole (adblocking, DNS, web admin)
- ✅ **Añade redirección selectiva** WARP completamente transparente
- ✅ **Gestión inteligente** de listas de dominios automática
- ✅ **Configuración iptables** dinámica y automática  
- ✅ **Logs separados** que no interfieren con Pi-hole
- ✅ **Control granular** por dominio individual
- ✅ **Estadísticas integradas** de uso WARP vs normal

### **Compatibilidad:**
- 🟢 **Pi-hole 5.0+** - Totalmente compatible
- 🟢 **Unbound** - Funciona con DNS recursivo
- 🟢 **Custom DNS** - Compatible con configuraciones personalizadas  
- 🟢 **Pi-hole en Docker** - Funciona con contenedores Pi-hole

## 🔧 Troubleshooting

### **Plugin no funciona:**
```bash
# 1. Verificar instalación
ls -la /etc/pihole/plugins/warp/
sudo /etc/pihole/plugins/warp/src/warp-domains check

# 2. Verificar permisos
sudo chown -R root:root /etc/pihole/plugins/warp/
sudo chmod +x /etc/pihole/plugins/warp/src/*
```

### **No se conecta al proxy WARP:**
```bash
# Verificar conectividad
nc -z <WARP_PROXY_HOST> 1080
telnet <WARP_PROXY_HOST> 1080

# Verificar configuración
cat /etc/pihole/plugins/warp/warp-config.conf | grep WARP_PROXY

# Verificar contenedor WARP (en servidor Docker)  
docker ps | grep warp
docker logs warp-proxy
```

### **Iptables no se configuran:**
```bash
# Verificar permisos sudo
sudo iptables -t nat -L WARP_REDIRECT

# Ver reglas actuales
sudo iptables -t nat -L -n -v

# Resetear reglas (cuidado!)
sudo /etc/pihole/plugins/warp/src/query-monitor.py setup-iptables
```

### **Logs y diagnóstico:**
```bash
# Ver errores del plugin
grep -i error /etc/pihole/plugins/warp/logs/warp-plugin.log

# Ver actividad en tiempo real
tail -f /etc/pihole/plugins/warp/logs/warp-plugin.log

# Logs de Pi-hole (por si interfiere)  
tail -f /var/log/pihole.log

# Test completo del sistema
sudo /tmp/antiTebasPlugin/scripts/verify-requirements.sh
```

### **Problemas de rendimiento:**
```bash
# Ver uso de CPU/RAM
htop
ps aux | grep python3

# Optimizar logs (reducir verbose)
echo "LOG_LEVEL=WARNING" >> /etc/pihole/plugins/warp/warp-config.conf

# Verificar espacio en disco
df -h /etc/pihole/plugins/warp/logs/
```