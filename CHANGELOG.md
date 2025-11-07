# Cambios en la arquitectura - v2.0

## 🆕 **Nuevas características - v2.1**

### **Soporte para listas públicas de bloqueos en España**
- ✅ **Nueva configuración**: `SPAIN_BLOCKLIST_URLS` en `warp-config.conf`
- ✅ **Descarga automática**: Listas públicas de dominios bloqueados en España
- ✅ **Múltiples formatos**: Soporta hosts, plano y wildcards
- ✅ **Actualización periódica**: Se actualizan junto con otras listas
- ✅ **Documentación completa**: Ver `docs/SPAIN_BLOCKLISTS.md`
- ✅ **Ejemplo incluido**: Ver `examples/spain-blocklist-example.txt`

**Archivos nuevos**:
- `docs/SPAIN_BLOCKLISTS.md` - Documentación completa sobre listas públicas
- `examples/spain-blocklist-example.txt` - Ejemplo de formato de blocklist
- `tests/test_spain_blocklists.py` - Tests para la nueva funcionalidad

**Archivos modificados**:
- `antiTebasPlugin/src/query-monitor.py` - Nuevo método `download_spain_blocklists()`
- `antiTebasPlugin/config/warp-config.conf` - Nueva variable `SPAIN_BLOCKLIST_URLS`
- `README.md` - Documentación de la nueva característica

**Uso**:
```bash
# Configurar en warp-config.conf
SPAIN_BLOCKLIST_URLS=https://ejemplo.com/lista-publica.txt

# Actualizar listas
warp-domains update
```

---

# Cambios en la arquitectura - v2.0

## ❌ **Componentes eliminados**

### **Componente Traffic Manager**
- **Razón**: Funcionalidad simplificada e integrada completamente al plugin Pi-hole
- **Archivos eliminados**:
  - `src/main.py` - Coordinador principal
  - `src/domain_manager.py` - Gestión de dominios
  - `src/routing_manager.py` - Configuración iptables
  - `src/api_server.py` - API REST
  - `src/pihole_integration.py` - Integración Pi-hole
  - `scripts/health-check.sh` - Scripts de monitoreo
  - `requirements.txt` - Dependencias Python

### **Configuración centralizada (config/)**
- **Razón**: Listas gestionadas directamente en Pi-hole
- **Archivos eliminados**:
  - `config/lists/custom-domains.txt` → Movido a ejemplos
  - `config/lists/custom-ips.txt` → Ya no necesario
  - `config/pihole/` → Configuración directa en Pi-hole

### **Variables de entorno simplificadas**
- **Configuración ahora en plugin Pi-hole**:
  - `PIHOLE_HOST` - Configurado automáticamente en plugin
  - `PIHOLE_PORT` - Detectado automáticamente o configurable
  - `PIHOLE_API_TOKEN` - Opcional para funciones avanzadas
  - `DOMAIN_LISTS_URLS` - Gestionado en warp-config.conf
  - `WARP_PROXY_HOST` - IP del servidor Docker

## ✅ **Arquitectura nueva (simplificada)**

### **Docker: Solo proxy WARP**
```
docker/
└── warp/
    ├── Dockerfile          # Imagen minimalista
    ├── start-warp.sh       # Script simple
    ├── danted.conf         # SOCKS5 config
    ├── redsocks.conf       # Transparent proxy
    └── supervisord.conf    # Servicios mínimos
```

### **Pi-hole: Cerebro del sistema**
```
antiTebasPlugin/
├── src/
│   ├── query-monitor.py    # 🧠 Controlador principal
│   ├── dns-interceptor.sh  # Interceptor DNS
│   └── warp-domains        # 🔧 Gestión de dominios
└── config/
    └── warp-config.conf    # Configuración local
```

## 🎯 **Beneficios del cambio**

### **Simplicidad**
- ✅ **Docker minimalista**: Solo proxy, sin lógica compleja
- ✅ **Un solo punto de control**: Todo desde Pi-hole
- ✅ **Menos dependencias**: Sin Python en Docker
- ✅ **Configuración mínima**: Solo variables WARP

### **Rendimiento** 
- ⚡ **Detección instantánea**: Sin APIs ni polling
- ⚡ **Configuración dinámica**: iptables en tiempo real
- ⚡ **Menos overhead**: Sin comunicación entre contenedores
- ⚡ **Gestión directa**: Comandos nativos Pi-hole

### **Mantenimiento**
- 🔧 **Control directo**: Comandos simples (`warp-domains add`)
- 🔧 **Logs centralizados**: Todo en Pi-hole
- 🔧 **Debugging simple**: Un solo proceso
- 🔧 **Actualizaciones fáciles**: Solo plugin

## 🚀 **Migración para usuarios existentes**

### **Si ya tienes la v1 instalada:**

1. **Detener servicios antiguos**:
   ```bash
   docker-compose down
   ```

2. **Limpiar archivos antiguos**:
   ```bash
   rm -rf docker/traffic-manager/
   rm -rf config/
   ```

3. **Actualizar repositorio**:
   ```bash
   git pull origin main
   ```

4. **Instalar nueva versión**:
   ```bash
   # Iniciar solo proxy WARP
   make up
   
   # Instalar plugin en Pi-hole
   ./install-pihole-plugin.sh
   ```

5. **Migrar dominios** (si los tenías):
   ```bash
   # En Pi-hole, agregar dominios uno por uno
   warp-domains add netflix.com
   warp-domains add youtube.com
   # etc...
   ```

## 📊 **Comparación de arquitecturas**

| Aspecto | v1 (Arquitectura compleja) | v2 (Plugin Pi-hole) |
|---------|---------------------|---------------------|
| **Complejidad Docker** | 2 contenedores complejos | 1 contenedor simple |
| **Líneas de código** | ~2000 líneas Python | ~800 líneas Python |
| **Configuración** | 15+ variables | 3 variables |
| **Gestión dominios** | Archivos + APIs | Comandos directos |
| **Detección consultas** | Polling logs | Tiempo real |
| **Configuración iptables** | Masiva y periódica | Selectiva e instantánea |
| **Debugging** | Múltiples logs | Logs centralizados |
| **Mantenimiento** | Complejo | Simple |

La nueva arquitectura es **60% menos código**, **80% menos configuración** y **100% más eficiente**. 🎉