# AntiTebasPlugin

Un plugin para Pi-hole que redirije selectivamente el tráfico de ciertas URLs o IPs a través de la VPN de Cloudflare WARP usando Docker.

## 🛡️ ¿Qué son los "Bloqueos de Tebas"?

Los **"Bloqueos de Tebas"** se refieren a las medidas antipiratería implementadas por Javier Tebas, presidente de LaLiga desde 2013, que han causado controversia en España desde febrero de 2025.

### El Problema

**Javier Tebas** y LaLiga han implementado un sistema de bloqueos automáticos que:

- 🚫 **Bloquea miles de IPs cada fin de semana** (2.000-3.000 direcciones IP por partido)
- 🎯 **Usa inteligencia artificial** para detectar streaming ilegal en tiempo real
- 🌐 **Afecta servicios legítimos** al bloquear proveedores como Cloudflare masivamente
- 📡 **Instala sondas en operadoras** españolas para controlar los bloqueos
- ⚖️ **Envía órdenes directas** a telecomunicaciones para cortar IPs "en directo"

### Casos Polémicos

- **Real Academia Española (RAE)**: Su web oficial fue bloqueada durante un partido, afectando a millones de usuarios
- **Cloudflare**: 35% de su tráfico hacia España se bloquea durante partidos de LaLiga
- **Google Fonts**: Servicios esenciales de internet han sido afectados
- **Empresas legítimas**: Miles de sitios web y servicios se ven interrumpidos cada fin de semana

### La Respuesta de Tebas

Cuando la RAE se quejó del bloqueo, Tebas amenazó legalmente:

> *"Dígale a Cloudflare que no comparta usted, la RAE, con contenido ilegal. Y si no lo hace, le demandaré, porque usted está consintiendo que su IP sea utilizada para compartir un delito contra la propiedad intelectual."*

### ¿Por qué AntiTebasPlugin?

Este plugin te permite **recuperar el control de tu conexión** redirigiendo selectivamente el tráfico a través de Cloudflare WARP, evitando así los bloqueos indiscriminados implementados por LaLiga.

**No fomentamos la piratería** - este plugin está diseñado para restaurar el acceso legítimo a servicios que han sido bloqueados colateralmente por las medidas antipiratería.

---

## Características

- 🔒 **Redirección selectiva**: Solo el tráfico especificado pasa por WARP
- 🎯 **Policy-based routing**: El resto del tráfico sigue por la conexión normal
- 🔄 **Actualizaciones automáticas**: Las listas se actualizan periódicamente
- 🐳 **Containerizado**: Fácil despliegue con Docker Compose
- 📊 **Integración Pi-hole**: Sincronización opcional con Pi-hole existente
- 📝 **Logging completo**: Monitoreo detallado de operaciones

## 🏗️ Arquitectura

### **Nueva arquitectura centrada en Pi-hole (recomendada):**

```
Internet → [Router] → [Pi-hole + Plugin WARP] → [Proxy WARP simple]
                              ↓                        ↓
                      • Gestiona listas           • Solo proxy
                      • Detecta consultas        • SOCKS5 + Transparent
                      • Configura iptables       • Cloudflare WARP
                      • Coordina redirección     
```

**El cerebro está en Pi-hole:**
- ✅ **Plugin inteligente** gestiona todo desde Pi-hole  
- ✅ **Agregar/quitar dominios** directamente en Pi-hole
- ✅ **Detección automática** de consultas DNS
- ✅ **Configuración dinámica** de iptables  
- ✅ **Contenedor Docker simple** solo para proxy

## 📋 Requisitos del Sistema

### **Servidor Pi-hole (Principal)**

#### **Sistema Operativo:**
- ✅ **Ubuntu/Debian** 20.04+ (recomendado)
- ✅ **Raspberry Pi OS** Bullseye+ 
- ✅ **CentOS/RHEL** 8+
- ✅ **Arch Linux** (avanzado)

#### **Hardware Mínimo:**
- 📟 **CPU**: 1 core, 1GHz (ARM/x86_64)
- 🧠 **RAM**: 512MB (mínimo), 1GB+ (recomendado) 
- 💾 **Disco**: 2GB libres para logs y configuración
- 🌐 **Red**: Interfaz ethernet o WiFi estable

#### **Software Requerido:**
```bash
# Herramientas esenciales
sudo apt update && sudo apt install -y \
    curl wget git nano \
    python3 python3-pip \
    iptables netfilter-persistent \
    netcat-openbsd net-tools \
    cron logrotate

# Librerías Python
sudo pip3 install requests psutil
```

#### **Pi-hole Prerequisites:**
- ✅ **Pi-hole** 5.0+ instalado y configurando
- ✅ **Acceso root** o sudo sin password
- ✅ **Puerto web** accesible (80, 8080, 443, etc.)
- ✅ **DNS funcional** en puerto 53 o personalizado

#### **Permisos y Acceso:**
- 🔐 **Root access** para iptables y configuración de red
- 🌐 **Conectividad saliente** para descargar listas de dominios
- 📂 **Escritura en** `/etc/pihole/plugins/`
- ⏰ **Cron access** para tareas programadas

---

### **Servidor Docker (Proxy WARP)**

#### **Opción A: Mismo servidor que Pi-hole**
```bash
# Instalar Docker en el mismo servidor Pi-hole
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo apt install docker-compose-plugin
```

#### **Opción B: Servidor separado**
- 📟 **Hardware**: Cualquier servidor con Docker
- 🧠 **RAM**: 256MB+ para contenedor WARP
- 🌐 **Red**: Accesible desde servidor Pi-hole
- 🔌 **Puertos**: 1080 (SOCKS5) y 8080 (Transparent) disponibles

#### **Software Docker:**
```bash
# Verificar instalación Docker
docker --version          # >= 20.10.x
docker compose version    # >= 2.0.x

# Verificar conectividad
docker run --rm alpine:latest ping -c3 1.1.1.1
```

---

### **Configuración de Red**

#### **Routing y Firewall:**
```bash
# Habilitar IP forwarding (permanente)
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p

# Verificar iptables
iptables -t nat -L    # Debe mostrar cadenas PREROUTING, POSTROUTING
```

#### **Conectividad entre servidores:**
```bash
# Si Pi-hole y WARP están en servidores diferentes
# Desde servidor Pi-hole:
telnet <WARP_SERVER_IP> 1080    # Debe conectar al proxy SOCKS5
telnet <WARP_SERVER_IP> 8080    # Debe conectar al transparent proxy
```

---

### **Verificación Previa**

#### **Script de verificación automática:**
```bash
# Opción 1: Ejecutar script incluido
cd antiTebasPlugin/scripts
sudo ./verify-requirements.sh

# Opción 2: Instalación automática de dependencias
sudo ./install-dependencies.sh
```

#### **Verificación manual:**
```bash
# 1. Verificar Pi-hole
pihole status
curl -s http://localhost/admin/api.php | grep -q "queries_today"

# 2. Verificar permisos iptables  
sudo iptables -t nat -L > /dev/null && echo "✓ iptables OK"

# 3. Verificar Python y dependencias
python3 -c "import requests, socket, threading" && echo "✓ Python OK"

# 4. Verificar conectividad
curl -s https://1.1.1.1 > /dev/null && echo "✓ Internet OK"

# 5. Verificar espacio en disco
df -h /etc/pihole | tail -1 | awk '{print $5}' | sed 's/%//'
```

---

## 🚀 Instalación

### **Instalación Rápida (Recomendada)**

```bash
# 1. Descargar el proyecto
git clone <repository-url>
cd pluginPiHoleTebas

# 2. Copiar al servidor Pi-hole
scp -r antiTebasPlugin/ root@tu-pihole-ip:/tmp/

# 3. En el servidor Pi-hole - Instalar dependencias automáticamente
ssh root@tu-pihole-ip
cd /tmp/antiTebasPlugin/scripts
sudo ./install-dependencies.sh

# 4. Instalar el plugin
cd ../
sudo ./install-plugin.sh

# 5. Iniciar contenedor WARP (en servidor Docker)
cd /ruta/al/proyecto
docker compose up -d
```

### **Opción 1: Instalación completa (paso a paso)

1. **Clonar el repositorio**
   ```bash
   git clone <repository-url>
   cd pluginPiHoleTebas
   ```

2. **Configurar variables de entorno**
   ```bash
   cp .env.example .env
   nano .env
   ```

   **⚡ Configuración importante de puertos:**
   ```bash
   # Si tu Pi-hole corre en puerto personalizado
   PIHOLE_HOST=192.168.1.100    # IP de tu Pi-hole
   PIHOLE_PORT=8080             # Puerto personalizado (ej: 8080, 443)
   PIHOLE_SSL=true              # Si usas HTTPS
   
   # Para puertos estándar, usar valores por defecto:
   # PIHOLE_PORT=80  (HTTP estándar)
   # PIHOLE_PORT=443 (HTTPS estándar)
   ```

3. **Instalar plugin en Pi-hole**
   ```bash
   # Copiar plugin al servidor Pi-hole
   scp -r antiTebasPlugin/ root@tu-pihole-ip:/tmp/
   
   # En el servidor Pi-hole (como root)
   cd /tmp/antiTebasPlugin
   ./install-plugin.sh
   
   # El instalador detectará automáticamente el puerto de Pi-hole
   # y te permitirá configurarlo interactivamente
   
   # Configurar IP del servidor WARP
   nano /etc/pihole/plugins/warp/warp-config.conf
   ```

4. **Iniciar contenedores Docker**
   ```bash
   make up
   ```

### Opción 2: Solo contenedores (sin integración Pi-hole)

1. **Configurar listas de dominios/IPs**
   - Editar `config/lists/custom-domains.txt`
   - Editar `config/lists/custom-ips.txt`
   - O configurar URLs externas en `.env`

2. **Iniciar los servicios**
   ```bash
   docker-compose up -d
   ```

## Configuración

### Variables de entorno (.env)

```bash
# Pi-hole (opcional)
PIHOLE_HOST=192.168.1.100
PIHOLE_API_TOKEN=your-api-token

# WARP Teams (opcional)
WARP_TEAM_ID=your-team-id
WARP_LICENSE_KEY=your-license-key

# Listas externas
DOMAIN_LISTS_URLS=https://example.com/hosts,https://another.com/hosts

# Dominios/IPs personalizados
CUSTOM_DOMAINS=netflix.com,hulu.com
CUSTOM_IPS=8.8.8.8,1.1.1.1

# Configuración de actualización
UPDATE_INTERVAL=3600
```

### Listas personalizadas

**config/lists/custom-domains.txt**
```
netflix.com
disney.com
youtube.com
```

**config/lists/custom-ips.txt**
```
8.8.8.8
1.1.1.1
192.168.100.0/24
```

## Uso

### 🚀 Comandos básicos

### **Gestión del sistema Docker:**
```bash
# Iniciar proxy WARP
make up

# Ver logs del proxy
docker-compose logs -f

# Detener servicios  
make down
```

### **Gestión de dominios (en Pi-hole):**
```bash
# Agregar dominio WARP
warp-domains add netflix.com

# Eliminar dominio  
warp-domains remove netflix.com

# Ver lista de dominios
warp-domains list

# Probar dominio
warp-domains test youtube.com

# Ver estadísticas
warp-domains stats

# Ver estado del sistema
warp-domains status
```

### **Control del monitor:**
```bash
# Iniciar monitor en background
warp-domains start

# Detener monitor
warp-domains stop

# Actualizar listas externas
warp-domains update
```

### Monitoreo

Los logs se almacenan en:
- `/etc/pihole/plugins/warp/logs/warp-plugin.log` - Log principal del plugin
- `/var/log/pihole.log` - Logs de Pi-hole (para correlacionar)
- `docker logs warp-proxy` - Logs del contenedor WARP

## Funcionamiento

### 🎯 **Funcionamiento inteligente (Pi-hole como cerebro)**
1. **Usuario consulta** `netflix.com`
2. **Pi-hole resuelve** normalmente: `netflix.com → 52.84.124.90`  
3. **Plugin detecta** que `netflix.com` está en lista WARP
4. **Plugin resuelve** el dominio a IPs actuales
5. **Plugin configura** regla iptables: `52.84.124.90 → puerto 8080`
6. **Tráfico futuro** a esa IP se redirige automáticamente al proxy WARP
7. **Resto del tráfico** sigue normal por tu operador

### ⚡ **Ventajas del nuevo enfoque**
- 🧠 **Cerebro en Pi-hole**: Control total desde donde ya tienes DNS
- 🎯 **Redirección precisa**: Solo IPs consultadas realmente
- ⚡ **Tiempo real**: Configuración instantánea al detectar consulta
- 🔧 **Gestión simple**: Comandos directos para agregar/quitar dominios
- 📦 **Docker minimalista**: Solo proxy, sin complejidad extra

## Troubleshooting

### Problemas comunes

**WARP no se conecta**
```bash
# Verificar logs del contenedor WARP
docker compose logs warp-proxy

# Verificar conectividad desde Pi-hole
nc -z <DOCKER_HOST_IP> 1080
telnet <DOCKER_HOST_IP> 1080
```

**Reglas iptables no funcionan**
```bash
# En el servidor Pi-hole, verificar privilegios
sudo iptables -t nat -L

# Verificar reglas específicas del plugin
sudo iptables -t nat -L WARP_REDIRECT
```

**Pi-hole no se conecta**
```bash
# Verificar configuración
curl http://your-pihole-ip/admin/api.php?version

# Verificar token API
curl "http://your-pihole-ip/admin/api.php?summaryRaw&auth=your-token"
```

### Logs útiles

```bash
# Ver estado completo del plugin
sudo /etc/pihole/plugins/warp/src/warp-domains stats
sudo /etc/pihole/plugins/warp/src/warp-domains check

# Logs en tiempo real
tail -f /etc/pihole/plugins/warp/logs/warp-plugin.log

# Verificar reglas de routing en Pi-hole
sudo iptables -t nat -L WARP_REDIRECT -n -v

# Logs del contenedor WARP
docker compose logs -f warp-proxy
```

## 📖 Contexto Técnico y Legal

### Cronología del Conflicto

- **Febrero 2025**: Inicio de bloqueos masivos de Cloudflare durante partidos de LaLiga
- **Marzo 2025**: Bloqueo accidental de la web de la Real Academia Española
- **Actualidad**: Cloudflare recurre al Tribunal Constitucional español

### Metodología de Bloqueos de LaLiga

1. **Detección automática**: IA escanea internet buscando streams ilegales 24/7
2. **Identificación masiva**: 2.000-3.000 IPs detectadas cada fin de semana  
3. **Bloqueo indiscriminado**: Se bloquean rangos enteros de Cloudflare (35% del tráfico)
4. **Control en tiempo real**: Sondas instaladas en todas las operadoras españolas
5. **Supervisión social**: Monitorización de redes sociales para medir "ruido social"

### Impacto en Servicios Legítimos

- **Empresas**: Miles de sitios web corporativos inaccesibles
- **Instituciones**: Organismos oficiales como la RAE bloqueados  
- **CDNs**: Cloudflare, Google Fonts y otros servicios esenciales afectados
- **Usuarios**: Millones de personas sin acceso a servicios legítimos

### Marco Legal

Javier Tebas utiliza sentencias judiciales que autorizan el bloqueo de ~120 IPs específicas para justificar el bloqueo de miles de direcciones no incluidas en las órdenes judiciales.

### ⚖️ Legalidad de AntiTebasPlugin

- ✅ **Legal**: Usar VPN es completamente legal en España
- ✅ **Legítimo**: Restaurar acceso a servicios bloqueados colateralmente
- ✅ **No es piratería**: No facilita acceso a contenido ilegal
- ✅ **Derecho digital**: Ejercer el derecho a la conectividad

**Declaración**: Este plugin está diseñado exclusivamente para restaurar el acceso legítimo a servicios web que han sido bloqueados colateralmente por las medidas antipiratería. No fomentamos ni facilitamos la piratería de contenidos.

---

## Estructura del Proyecto

```
├── docker-compose.yml          # Orquestación simplificada
├── .env.example               # Variables mínimas
├── install-pihole-plugin.sh   # Instalador del plugin Pi-hole
├── docker/
│   └── warp/                  # 🔌 Proxy WARP simple
│       ├── Dockerfile
│       ├── start-warp.sh
│       ├── danted.conf        # SOCKS5 proxy
│       ├── redsocks.conf      # Transparent proxy
│       └── supervisord.conf   # Servicios
├── antiTebasPlugin/           # 🧠 Plugin inteligente Pi-hole
│   ├── install-plugin.sh      # Instalador automático
│   ├── src/
│   │   ├── query-monitor.py   # 🎯 Controlador principal
│   │   ├── dns-interceptor.sh # Interceptor DNS
│   │   └── warp-domains       # 🔧 Script de gestión
│   ├── config/
│   │   └── warp-config.conf   # Configuración
│   └── README.md
└── logs/                      # Archivos de log
```

## 🔧 Troubleshooting

### **Problemas de Requisitos**

#### Error: "Pi-hole no encontrado"
```bash
# Verificar instalación Pi-hole
sudo systemctl status pihole-FTL
pihole status

# Reinstalar Pi-hole si es necesario
curl -sSL https://install.pi-hole.net | bash
```

#### Error: "iptables no accesible"
```bash
# Verificar permisos sudo
sudo iptables -t nat -L

# En Ubuntu/Debian
sudo apt install iptables netfilter-persistent

# En CentOS/RHEL
sudo yum install iptables-services
sudo systemctl enable iptables
```

#### Error: "Módulo Python faltante"
```bash
# Instalar dependencias Python
sudo pip3 install requests psutil

# O usar el script automático
sudo ./antiTebasPlugin/scripts/install-dependencies.sh
```

#### Error: "RAM insuficiente"
```bash
# Verificar uso de memoria
free -h
htop

# Optimizar Pi-hole (reducir logs)
pihole -f
echo 'MAXLOGAGE=1' >> /etc/pihole/pihole-FTL.conf
sudo systemctl restart pihole-FTL
```

#### Error: "Sin conectividad internet"
```bash
# Verificar conectividad
ping -c3 1.1.1.1
curl -I https://cloudflare.com

# Verificar DNS
nslookup cloudflare.com
cat /etc/resolv.conf
```

### **Problemas de Instalación**

#### Error de permisos durante instalación
```bash
# Ejecutar como root
sudo su -
cd /tmp/antiTebasPlugin
./install-plugin.sh
```

#### Puerto Pi-hole no detectado
```bash
# Verificar puertos manualmente
sudo netstat -tlnp | grep lighttpd
sudo ss -tlnp | grep ":80\|:8080\|:443"

# Configurar manualmente en warp-config.conf
PIHOLE_PORT=8080  # Tu puerto personalizado
```

### **Verificación Post-Instalación**

```bash
# Verificar plugin instalado
ls -la /etc/pihole/plugins/warp/
sudo /etc/pihole/plugins/warp/warp-domains check

# Verificar logs
tail -f /etc/pihole/plugins/warp/logs/warp-plugin.log

# Test de conectividad completo
sudo ./antiTebasPlugin/scripts/verify-requirements.sh
```

---

## Contribuir

1. Fork del repositorio
2. Crear rama para feature (`git checkout -b feature/amazing-feature`)
3. Commit de cambios (`git commit -m 'Add amazing feature'`)
4. Push a la rama (`git push origin feature/amazing-feature`)
5. Abrir Pull Request

## 🔍 FAQ - Bloqueos de Tebas

### ¿Por qué mi web empresarial se bloquea los fines de semana?

LaLiga bloquea rangos enteros de IPs de Cloudflare durante los partidos. Si tu web usa Cloudflare (como millones de sitios), puede ser afectada colateralmente.

### ¿Es legal usar este plugin para evitar los bloqueos?

**Sí, completamente legal.** Usar VPN es un derecho en España. Este plugin solo restaura acceso a servicios legítimos bloqueados por error.

### ¿Esto es para ver fútbol pirata?

**No.** Este plugin está diseñado para empresas y usuarios que han perdido acceso legítimo a sus servicios web debido a los bloqueos indiscriminados.

### ¿Qué diferencia hay con una VPN normal?

Este plugin es **selectivo** - solo redirije el tráfico afectado por los bloqueos, manteniendo el resto de tu conexión normal para mejor rendimiento.

### ¿Tebas puede bloquear WARP también?

Técnicamente sí, pero sería extremadamente controvertido ya que WARP es usado por millones de empresas legítimas mundialmente.

### ¿Cuándo terminará este conflicto?

Cloudflare ha llevado el caso al Tribunal Constitucional. Mientras tanto, los bloqueos continúan cada fin de semana durante los partidos de LaLiga.

---

## Licencia

Este proyecto está bajo la licencia MIT. Ver `LICENSE` para más detalles.

## Soporte

Para soporte, por favor abrir un issue en GitHub con:
- Logs relevantes
- Configuración utilizada
- Pasos para reproducir el problema