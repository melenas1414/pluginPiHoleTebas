# Listas Públicas de Bloqueos en España

## Descripción

El plugin AntiTebas ahora incluye soporte para descargar automáticamente listas públicas de dominios bloqueados en España, principalmente aquellos bloqueados por medidas antipiratería de LaLiga y otras entidades.

## ¿Cómo funciona?

El plugin puede configurarse para descargar automáticamente listas de dominios bloqueados desde URLs públicas. Estos dominios se agregan automáticamente a la lista de dominios que deben enrutarse a través de WARP, permitiendo acceder a servicios que han sido bloqueados colateralmente.

## Configuración

### En el archivo `warp-config.conf`:

```bash
# URLs de listas públicas de dominios bloqueados en España
# Separar múltiples URLs con comas
SPAIN_BLOCKLIST_URLS=https://example.com/spain-blocklist.txt,https://another.com/blocked-domains.txt
```

### Formatos soportados:

El plugin puede parsear diferentes formatos de blocklists:

1. **Formato hosts** (recomendado):
```
0.0.0.0 sitio-bloqueado.com
127.0.0.1 otro-sitio.es
```

2. **Formato plano** (un dominio por línea):
```
sitio-bloqueado.com
otro-sitio.es
subdomain.example.com
```

3. **Formato con wildcards**:
```
*.sitio-bloqueado.com
*.streaming-bloqueado.tv
```

## Fuentes de Listas Públicas

### ⚠️ IMPORTANTE - Uso Legal

Las listas públicas de bloqueos deben usarse **únicamente con fines legítimos**:
- ✅ Restaurar acceso a servicios bloqueados colateralmente
- ✅ Investigación académica sobre censura en internet
- ✅ Análisis de red corporativo
- ❌ NO para acceder a contenido pirata
- ❌ NO para evadir bloqueos legales de contenido sin licencia

### Listas Públicas Disponibles

Algunas fuentes públicas de información sobre bloqueos en España:

1. **Listas comunitarias mantenidas por usuarios**:
   - Listas colaborativas en GitHub de dominios bloqueados
   - Wikis públicas sobre censura en internet
   
2. **Organizaciones de derechos digitales**:
   - Informes de organizaciones que documentan la censura
   - Estudios académicos sobre bloqueos DNS

3. **Registros oficiales** (cuando están disponibles):
   - Listados publicados por autoridades (si son públicos)
   - Comunicados de titulares de derechos

### ⚖️ Nota Legal

Este plugin NO incluye por defecto URLs de listas de sitios piratas. Los usuarios son responsables de configurar las URLs de blocklists de acuerdo con las leyes locales e internacionales.

## Actualización Automática

Las listas se actualizan automáticamente según el intervalo configurado:

```bash
# Actualizar cada hora (3600 segundos)
UPDATE_INTERVAL=3600
```

También puedes actualizar manualmente:

```bash
# Actualizar listas manualmente
warp-domains update

# O usando el script Python directamente
python3 /etc/pihole/plugins/warp/src/query-monitor.py update
```

## Verificación

Para verificar qué dominios se han cargado desde las listas públicas:

```bash
# Ver estadísticas
warp-domains stats

# Ver archivo de dominios
cat /etc/pihole/plugins/warp/lists/warp-domains.txt
```

El archivo incluye comentarios indicando cuántos dominios provienen de cada fuente.

## Logs

El plugin registra información sobre la descarga de listas:

```bash
# Ver logs de actualización
tail -f /etc/pihole/plugins/warp/logs/warp-plugin.log | grep "España"
```

Mensajes típicos:
```
INFO - Descargando lista de bloqueos España desde: https://...
INFO - Lista España procesada: +1234 dominios bloqueados desde https://...
INFO - ✅ Listas actualizadas: 5678 dominios totales
INFO -    - Externos: 3000
INFO -    - Bloqueados España: 1234
```

## Privacidad y Seguridad

- ✅ Las listas se descargan por HTTPS cuando es posible
- ✅ Timeout de 30 segundos para evitar bloqueos
- ✅ Validación de dominios antes de agregarlos
- ✅ Logs detallados para auditoría
- ⚠️ Las URLs de listas deben ser de fuentes confiables

## Troubleshooting

### Error al descargar listas

```bash
# Verificar conectividad
curl -I https://url-de-tu-lista.com

# Verificar logs
tail -f /etc/pihole/plugins/warp/logs/warp-plugin.log
```

### Dominios no se agregan

- Verificar que el formato de la lista sea correcto
- Verificar que los dominios sean válidos
- Revisar logs para ver si hay errores de parsing

### Listas muy grandes

Si las listas son muy grandes, puedes aumentar el timeout o dividirlas en múltiples URLs más pequeñas.

## Ejemplo de Uso

```bash
# 1. Editar configuración
sudo nano /etc/pihole/plugins/warp/warp-config.conf

# 2. Agregar URLs de listas públicas
SPAIN_BLOCKLIST_URLS=https://raw.githubusercontent.com/usuario/repo/main/spain-blocks.txt

# 3. Actualizar listas
warp-domains update

# 4. Verificar
warp-domains stats
cat /etc/pihole/plugins/warp/lists/warp-domains.txt | grep -A 5 "Bloqueados España"
```

## Contribuir

Si conoces listas públicas legítimas de dominios bloqueados en España, puedes:
1. Crear una PR agregando la URL al archivo de ejemplos
2. Documentar la fuente y su propósito legal
3. Verificar que la lista cumple con los términos de uso

---

**Recordatorio**: Este plugin es para uso legal. Úsalo responsablemente y respeta las leyes locales e internacionales.
