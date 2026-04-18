#!/usr/bin/env python3
"""
AntiTebasPlugin - Controlador Principal
Gestiona listas, detecta consultas y coordina redirección WARP
"""

import re
import sys
import time
import logging
import ipaddress
import requests
import threading
import subprocess
import socket
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Set, Optional, Union

# Configuración
PLUGIN_DIR = Path("/etc/pihole/plugins/warp")
CONFIG_FILE = PLUGIN_DIR / "warp-config.conf"
QUERY_LOG = Path("/var/log/pihole.log")
FTL_LOG = Path("/var/log/pihole-FTL.log")

class AntiTebasController:
    """Controlador principal AntiTebas integrado en Pi-hole"""
    
    def __init__(self):
        self.config = self.load_config()
        self.setup_logging()
        self.warp_domains = set()
        self.warp_ips = set()
        self.client_vpn_ips: List[Union[ipaddress.IPv4Network, ipaddress.IPv6Network]] = []   # CIDRs que deben usar WARP
        self.client_bypass_ips: List[Union[ipaddress.IPv4Network, ipaddress.IPv6Network]] = []  # CIDRs que nunca usan WARP
        self.resolved_ips = {}  # Cache dominio → IP
        self.warp_proxy_host = self.config['WARP_PROXY_HOST']
        self.warp_proxy_port = int(self.config['WARP_PROXY_PORT'])
        self.running = False
        
        # Cargar listas locales
        self.load_warp_lists()
        
        # Estadísticas
        self.stats = {
            'total_queries': 0,
            'warp_queries': 0,
            'last_update': None
        }
        
    def load_config(self) -> Dict[str, str]:
        """Cargar configuración del plugin"""
        config = {}
        
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        config[key.strip()] = value.strip()
        
        # Valores por defecto
        config.setdefault('WARP_PROXY_HOST', 'localhost')
        config.setdefault('WARP_PROXY_PORT', '1080')
        config.setdefault('PIHOLE_HOST', 'localhost')
        config.setdefault('PIHOLE_PORT', '80')
        config.setdefault('PIHOLE_DNS_PORT', '53')
        config.setdefault('PIHOLE_SSL', 'false')
        config.setdefault('PIHOLE_API_TOKEN', '')
        config.setdefault('LOG_FILE', str(PLUGIN_DIR / 'logs' / 'warp-plugin.log'))
        config.setdefault('LOG_LEVEL', 'INFO')
        config.setdefault('DOMAIN_LIST_FILE', str(PLUGIN_DIR / 'lists' / 'warp-domains.txt'))
        config.setdefault('IP_LIST_FILE', str(PLUGIN_DIR / 'lists' / 'warp-ips.txt'))
        config.setdefault('DOMAIN_LISTS_URLS', '')
        config.setdefault('SPAIN_BLOCKLIST_URLS', '')
        config.setdefault('UPDATE_INTERVAL', '3600')
        config.setdefault('CLIENT_VPN_IPS', '')
        config.setdefault('CLIENT_BYPASS_IPS', '')
        
        # Construir URL de Pi-hole
        protocol = 'https' if config.get('PIHOLE_SSL', 'false').lower() == 'true' else 'http'
        pihole_host = config.get('PIHOLE_HOST', 'localhost')
        pihole_port = config.get('PIHOLE_PORT', '80')
        
        # Solo agregar puerto si no es el estándar
        if (protocol == 'http' and pihole_port != '80') or (protocol == 'https' and pihole_port != '443'):
            config['PIHOLE_URL'] = f"{protocol}://{pihole_host}:{pihole_port}"
        else:
            config['PIHOLE_URL'] = f"{protocol}://{pihole_host}"
        
        return config
        
    def setup_logging(self):
        """Configurar logging"""
        log_file = Path(self.config['LOG_FILE'])
        log_file.parent.mkdir(parents=True, exist_ok=True)
        
        logging.basicConfig(
            level=getattr(logging, self.config['LOG_LEVEL']),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
        
        self.logger = logging.getLogger('AntiTebas')
        
    def load_warp_lists(self):
        """Cargar listas de dominios e IPs WARP y listas de clientes"""
        # Cargar dominios
        domain_file = Path(self.config['DOMAIN_LIST_FILE'])
        if domain_file.exists():
            with open(domain_file, 'r') as f:
                self.warp_domains = {
                    line.strip() 
                    for line in f 
                    if line.strip() and not line.startswith('#')
                }
            self.logger.info(f"Cargados {len(self.warp_domains)} dominios WARP")
        
        # Cargar IPs
        ip_file = Path(self.config['IP_LIST_FILE'])
        if ip_file.exists():
            with open(ip_file, 'r') as f:
                self.warp_ips = {
                    line.strip() 
                    for line in f 
                    if line.strip() and not line.startswith('#')
                }
            self.logger.info(f"Cargadas {len(self.warp_ips)} IPs WARP")
        
        # Cargar IPs/CIDRs de clientes
        self.client_vpn_ips = self._parse_ip_network_list(self.config.get('CLIENT_VPN_IPS', ''))
        self.client_bypass_ips = self._parse_ip_network_list(self.config.get('CLIENT_BYPASS_IPS', ''))
        
        if self.client_vpn_ips:
            self.logger.info(f"Clientes VPN configurados: {[str(n) for n in self.client_vpn_ips]}")
        if self.client_bypass_ips:
            self.logger.info(f"Clientes bypass configurados: {[str(n) for n in self.client_bypass_ips]}")
    
    def _parse_ip_network_list(self, raw: str) -> List[ipaddress.IPv4Network]:
        """Parsear lista separada por comas de IPs y rangos CIDR"""
        result = []
        for entry in raw.split(','):
            entry = entry.strip()
            if not entry:
                continue
            try:
                result.append(ipaddress.ip_network(entry, strict=False))
            except ValueError:
                self.logger.warning(f"Entrada IP/CIDR inválida ignorada: {entry}")
        return result
    
    def _ip_matches_list(self, ip: str, networks: List[Union[ipaddress.IPv4Network, ipaddress.IPv6Network]]) -> bool:
        """Verificar si una IP pertenece a alguna red de la lista"""
        try:
            parsed_ip = ipaddress.ip_address(ip)
            return any(parsed_ip in network for network in networks)
        except ValueError:
            return False
    
    def should_use_warp(self, client_ip: str) -> bool:
        """Determinar si el tráfico de un cliente debe enrutarse por WARP.
        
        Lógica:
        - Si CLIENT_BYPASS_IPS está configurada y el cliente coincide → NO usar WARP
        - Si CLIENT_VPN_IPS está configurada y el cliente NO coincide → NO usar WARP
        - En cualquier otro caso → usar WARP
        """
        # La lista de bypass tiene prioridad
        if self.client_bypass_ips and self._ip_matches_list(client_ip, self.client_bypass_ips):
            self.logger.debug(f"Cliente {client_ip} en lista bypass — omitiendo WARP")
            return False
        
        # Si hay lista VPN, solo esos clientes usan WARP
        if self.client_vpn_ips:
            if self._ip_matches_list(client_ip, self.client_vpn_ips):
                return True
            self.logger.debug(f"Cliente {client_ip} no está en CLIENT_VPN_IPS — omitiendo WARP")
            return False
        
        # Sin restricciones: todos los clientes usan WARP
        return True
    
    def is_warp_domain(self, domain: str) -> bool:
        """Verificar si un dominio debe usar WARP"""
        # Verificación exacta
        if domain in self.warp_domains:
            return True
            
        # Verificación de subdominio
        for warp_domain in self.warp_domains:
            if domain.endswith(f".{warp_domain}"):
                return True
                
        return False
    
    def download_domain_lists(self):
        """Descargar listas de dominios desde URLs externas"""
        urls = self.config.get('DOMAIN_LISTS_URLS', '').split(',')
        new_domains = set()
        
        for url in urls:
            url = url.strip()
            if not url:
                continue
                
            try:
                self.logger.info(f"Descargando lista desde: {url}")
                response = requests.get(url, timeout=30)
                response.raise_for_status()
                
                # Parsear archivo hosts
                for line in response.text.split('\n'):
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                        
                    parts = line.split()
                    if len(parts) >= 2:
                        ip = parts[0]
                        domain = parts[1]
                        
                        # Si es entrada de bloqueo (0.0.0.0, 127.0.0.1), agregar dominio
                        if ip in ['0.0.0.0', '127.0.0.1'] and self.is_valid_domain(domain):
                            new_domains.add(domain)
                            
                self.logger.info(f"Lista procesada: +{len(new_domains)} dominios desde {url}")
                
            except Exception as e:
                self.logger.error(f"Error descargando {url}: {e}")
        
        return new_domains
    
    def download_spain_blocklists(self):
        """Descargar listas públicas de dominios bloqueados en España"""
        urls = self.config.get('SPAIN_BLOCKLIST_URLS', '').split(',')
        blocked_domains = set()
        
        for url in urls:
            url = url.strip()
            if not url:
                continue
                
            try:
                self.logger.info(f"Descargando lista de bloqueos España desde: {url}")
                response = requests.get(url, timeout=30)
                response.raise_for_status()
                
                # Track domains from this specific URL
                domains_from_url = set()
                
                # Parsear diferentes formatos de blocklists
                for line in response.text.split('\n'):
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    
                    # Intentar diferentes formatos:
                    # 1. Formato hosts (0.0.0.0 domain.com o 127.0.0.1 domain.com)
                    # 2. Formato plano (solo dominio por línea)
                    # 3. Formato con wildcards (*.domain.com)
                    
                    parts = line.split()
                    
                    if len(parts) >= 2 and parts[0] in ['0.0.0.0', '127.0.0.1']:
                        # Formato hosts
                        domain = parts[1]
                        if self.is_valid_domain(domain):
                            domains_from_url.add(domain)
                    elif len(parts) == 1:
                        # Formato plano
                        domain = parts[0]
                        # Eliminar wildcards al principio
                        if domain.startswith('*.'):
                            domain = domain[2:]
                        if domain and self.is_valid_domain(domain):
                            domains_from_url.add(domain)
                
                blocked_domains.update(domains_from_url)
                self.logger.info(f"Lista España procesada: +{len(domains_from_url)} dominios bloqueados desde {url}")
                
            except Exception as e:
                self.logger.error(f"Error descargando lista España {url}: {e}")
        
        return blocked_domains
    
    def is_valid_domain(self, domain: str) -> bool:
        """Verificar si un dominio es válido"""
        if not domain or len(domain) > 253:
            return False
        pattern = r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
        return re.match(pattern, domain) is not None
    
    def resolve_domain_to_ip(self, domain: str) -> Set[str]:
        """Resolver dominio a IPs"""
        ips = set()
        try:
            import socket
            result = socket.getaddrinfo(domain, None)
            for item in result:
                ip = item[4][0]
                if ':' not in ip:  # Solo IPv4 por simplicidad
                    ips.add(ip)
                    
            # Cachear resultado
            self.resolved_ips[domain] = ips
            self.logger.debug(f"Resuelto {domain} → {ips}")
            
        except Exception as e:
            self.logger.debug(f"No se pudo resolver {domain}: {e}")
            
        return ips
    
    def setup_iptables_rule(self, ip: str, client_ip: Optional[str] = None) -> bool:
        """Configurar regla iptables para IP destino específica.
        
        Si se proporciona client_ip, la regla se restringe a ese origen,
        de modo que solo ese cliente tenga su tráfico redirigido por WARP.
        """
        try:
            # Crear cadena personalizada si no existe
            subprocess.run([
                "iptables", "-t", "nat", "-N", "WARP_REDIRECT"
            ], check=False, capture_output=True)
            
            # Construir los argumentos comunes a check y add
            rule_args = ["-d", ip, "-p", "tcp"]
            if client_ip:
                rule_args = ["-s", client_ip] + rule_args
            rule_args += ["-j", "REDIRECT", "--to-port", "8080"]
            
            # Verificar si la regla ya existe
            check_cmd = ["iptables", "-t", "nat", "-C", "WARP_REDIRECT"] + rule_args
            result = subprocess.run(check_cmd, check=False, capture_output=True)
            if result.returncode == 0:
                # Regla ya existe
                return True
            
            # Agregar nueva regla
            add_cmd = ["iptables", "-t", "nat", "-A", "WARP_REDIRECT"] + rule_args
            subprocess.run(add_cmd, check=True, capture_output=True)
            
            if client_ip:
                self.logger.info(f"Regla iptables agregada: {client_ip} → {ip} → WARP")
            else:
                self.logger.info(f"Regla iptables agregada para IP: {ip}")
            return True
            
        except subprocess.CalledProcessError as e:
            self.logger.error(f"❌ Error configurando cadena iptables: {e}")
            return False
    
    def check_pihole_connectivity(self) -> bool:
        """Verificar conectividad con Pi-hole"""
        try:
            pihole_url = self.config.get('PIHOLE_URL', 'http://localhost')
            api_endpoint = f"{pihole_url}/admin/api.php"
            
            response = requests.get(api_endpoint, timeout=5)
            if response.status_code == 200:
                self.logger.info(f"✅ Pi-hole accesible en {pihole_url}")
                return True
            else:
                self.logger.warning(f"⚠️ Pi-hole respondió con código {response.status_code} en {pihole_url}")
                return False
                
        except requests.RequestException as e:
            self.logger.warning(f"⚠️ Pi-hole no accesible en {pihole_url}: {e}")
            return False
    
    def check_warp_proxy(self) -> bool:
        """Verificar conectividad con proxy WARP"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((self.warp_proxy_host, self.warp_proxy_port))
            sock.close()
            return result == 0
        except Exception:
            return False
    
    def parse_pihole_log_line(self, line: str) -> Optional[Dict]:
        """Parsear línea del log de Pi-hole"""
        # Formato típico: "timestamp query[A] domain from client_ip"
        # Ejemplo: "Oct 29 10:15:30 query[A] google.com from 192.168.1.100"
        
        # Pattern para consultas DNS
        query_pattern = r'(\w+\s+\d+\s+\d+:\d+:\d+).*query\[([A-Z]+)\]\s+(\S+)\s+from\s+(\S+)'
        match = re.search(query_pattern, line)
        
        if match:
            timestamp_str, query_type, domain, client_ip = match.groups()
            
            return {
                'timestamp': datetime.now().isoformat(),
                'domain': domain,
                'client_ip': client_ip,
                'query_type': query_type,
                'raw_line': line.strip()
            }
        
        return None
    
    def process_dns_query(self, query_data: Dict):
        """Procesar consulta DNS y configurar redirección"""
        domain = query_data['domain']
        client_ip = query_data['client_ip']
        
        # Actualizar estadísticas
        self.stats['total_queries'] += 1
        
        # Verificar si es dominio WARP
        if self.is_warp_domain(domain):
            # Comprobar si este cliente debe usar WARP
            if not self.should_use_warp(client_ip):
                self.logger.debug(f"Dominio WARP {domain} — cliente {client_ip} excluido del enrutamiento")
                return False
            
            self.logger.info(f"🎯 Dominio WARP detectado: {domain} desde {client_ip}")
            self.stats['warp_queries'] += 1
            
            # Resolver dominio a IPs
            ips = self.resolve_domain_to_ip(domain)
            
            # Configurar redirección para cada IP destino.
            # Si CLIENT_VPN_IPS está activo pasamos client_ip para restringir la regla a ese origen.
            client_ip_filter = client_ip if self.client_vpn_ips else None
            for ip in ips:
                if self.setup_iptables_rule(ip, client_ip_filter):
                    self.logger.info(f"✅ Redirección configurada: {ip} → WARP")
                else:
                    self.logger.warning(f"❌ Error configurando redirección para {ip}")
            
            return True
            
        return False
    
    def monitor_pihole_log(self):
        """Monitorear log de Pi-hole en tiempo real"""
        self.logger.info("Iniciando monitor de consultas DNS")
        
        try:
            # Abrir archivo de log
            with open(QUERY_LOG, 'r') as f:
                # Ir al final del archivo
                f.seek(0, 2)
                
                while self.running:
                    line = f.readline()
                    
                    if line:
                        # Procesar línea
                        query_data = self.parse_pihole_log_line(line)
                        if query_data:
                            self.process_dns_query(query_data)
                    else:
                        # No hay nuevas líneas, esperar un poco
                        time.sleep(0.1)
                        
        except FileNotFoundError:
            self.logger.error(f"Archivo de log no encontrado: {QUERY_LOG}")
        except Exception as e:
            self.logger.error(f"Error monitoreando log: {e}")
    

    
    def update_domain_lists(self):
        """Actualizar listas de dominios (locales + externas + España)"""
        self.logger.info("📋 Actualizando listas de dominios...")
        
        # Descargar listas externas generales
        external_domains = self.download_domain_lists()
        
        # Descargar listas específicas de España (dominios bloqueados)
        spain_blocked_domains = self.download_spain_blocklists()
        
        # Combinar con listas locales existentes
        self.warp_domains.update(external_domains)
        self.warp_domains.update(spain_blocked_domains)
        
        # Guardar listas actualizadas
        domain_file = Path(self.config['DOMAIN_LIST_FILE'])
        domain_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(domain_file, 'w') as f:
            f.write("# Lista de dominios WARP - Actualizada automáticamente\n")
            f.write(f"# Última actualización: {datetime.now().isoformat()}\n")
            f.write(f"# Dominios externos: {len(external_domains)}\n")
            f.write(f"# Dominios bloqueados España: {len(spain_blocked_domains)}\n\n")
            for domain in sorted(self.warp_domains):
                f.write(f"{domain}\n")
        
        self.stats['last_update'] = datetime.now().isoformat()
        self.logger.info(f"✅ Listas actualizadas: {len(self.warp_domains)} dominios totales")
        self.logger.info(f"   - Externos: {len(external_domains)}")
        self.logger.info(f"   - Bloqueados España: {len(spain_blocked_domains)}")
        
    def add_domain(self, domain: str) -> bool:
        """Agregar dominio manualmente a la lista WARP"""
        if self.is_valid_domain(domain):
            self.warp_domains.add(domain)
            self.save_domain_lists()
            self.logger.info(f"➕ Dominio agregado: {domain}")
            return True
        else:
            self.logger.warning(f"❌ Dominio inválido: {domain}")
            return False
    
    def remove_domain(self, domain: str) -> bool:
        """Eliminar dominio de la lista WARP"""
        if domain in self.warp_domains:
            self.warp_domains.remove(domain)
            self.save_domain_lists()
            self.logger.info(f"➖ Dominio eliminado: {domain}")
            return True
        else:
            self.logger.warning(f"❌ Dominio no encontrado: {domain}")
            return False
    
    def save_domain_lists(self):
        """Guardar listas de dominios"""
        domain_file = Path(self.config['DOMAIN_LIST_FILE'])
        domain_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(domain_file, 'w') as f:
            f.write("# Lista de dominios WARP\n")
            f.write(f"# Actualizada: {datetime.now().isoformat()}\n\n")
            for domain in sorted(self.warp_domains):
                f.write(f"{domain}\n")
    
    def periodic_update(self):
        """Actualización periódica de listas en hilo separado"""
        update_interval = int(self.config.get('UPDATE_INTERVAL', '3600'))
        
        while self.running:
            try:
                # Verificar conectividad WARP
                if self.check_warp_proxy():
                    self.logger.debug("✅ Proxy WARP accesible")
                else:
                    self.logger.warning("⚠️ Proxy WARP no accesible")
                
                # Actualizar listas periódicamente
                self.update_domain_lists()
                    
                # Esperar hasta la próxima actualización
                for _ in range(update_interval):
                    if not self.running:
                        break
                    time.sleep(1)
                    
            except Exception as e:
                self.logger.error(f"Error en actualización periódica: {e}")
                time.sleep(60)  # Esperar 1 minuto antes de reintentar
    
    def setup_iptables_chain(self):
        """Configurar cadena iptables inicial"""
        try:
            # Crear cadena personalizada
            subprocess.run([
                "iptables", "-t", "nat", "-N", "WARP_REDIRECT"
            ], check=False, capture_output=True)
            
            # Insertar cadena en PREROUTING si no está ya
            check_cmd = ["iptables", "-t", "nat", "-C", "PREROUTING", "-j", "WARP_REDIRECT"]
            result = subprocess.run(check_cmd, check=False, capture_output=True)
            
            if result.returncode != 0:
                subprocess.run([
                    "iptables", "-t", "nat", "-I", "PREROUTING", "-j", "WARP_REDIRECT"
                ], check=True)
                
            self.logger.info("✅ Cadena iptables configurada")
            return True
            
        except subprocess.CalledProcessError as e:
            self.logger.error(f"❌ Error configurando cadena iptables: {e}")
            return False

    def start(self):
        """Iniciar el controlador WARP"""
        self.logger.info("🚀 === AntiTebas Plugin iniciando ===")
        
        # Verificar conectividad con Pi-hole
        if self.check_pihole_connectivity():
            self.logger.info("✅ Conectividad con Pi-hole verificada")
        else:
            self.logger.warning("⚠️ Pi-hole no accesible - verificar configuración de puerto")
        
        # Verificar proxy WARP
        if self.check_warp_proxy():
            self.logger.info(f"✅ Proxy WARP accesible en {self.warp_proxy_host}:{self.warp_proxy_port}")
        else:
            self.logger.warning(f"⚠️ Proxy WARP no accesible en {self.warp_proxy_host}:{self.warp_proxy_port}")
        
        # Configurar iptables
        if not self.setup_iptables_chain():
            self.logger.error("❌ Error configurando iptables - continuando de todos modos")
        
        # Cargar/actualizar listas iniciales
        self.update_domain_lists()
        
        self.running = True
        
        # Iniciar actualización periódica en hilo separado
        update_thread = threading.Thread(target=self.periodic_update, daemon=True)
        update_thread.start()
        
        # Iniciar monitoreo principal
        try:
            self.monitor_pihole_log()
        except KeyboardInterrupt:
            self.logger.info("⏹️ Interrupción recibida")
        finally:
            self.stop()
    
    def stop(self):
        """Detener el controlador"""
        self.logger.info("🛑 Deteniendo AntiTebas Plugin")
        self.running = False


def main():
    """Función principal"""
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "check":
            controller = AntiTebasController()
            if controller.check_warp_proxy():
                print("✓ Proxy WARP accesible")
                sys.exit(0)
            else:
                print("✗ Proxy WARP no accesible")
                sys.exit(1)
                
        elif command == "update":
            controller = AntiTebasController()
            controller.update_domain_lists()
            
        elif command == "add":
            if len(sys.argv) > 2:
                controller = AntiTebasController()
                domain = sys.argv[2]
                if controller.add_domain(domain):
                    print(f"✓ Dominio {domain} agregado")
                else:
                    print(f"✗ Error agregando {domain}")
            else:
                print("Uso: add <dominio>")
                sys.exit(1)
                
        elif command == "remove":
            if len(sys.argv) > 2:
                controller = AntiTebasController()
                domain = sys.argv[2]
                if controller.remove_domain(domain):
                    print(f"✓ Dominio {domain} eliminado")
                else:
                    print(f"✗ Dominio {domain} no encontrado")
            else:
                print("Uso: remove <dominio>")
                sys.exit(1)
                
        elif command == "test":
            test_domain = sys.argv[2] if len(sys.argv) > 2 else "google.com"
            controller = AntiTebasController()
            result = controller.is_warp_domain(test_domain)
            print(f"Dominio {test_domain}: {'🎯 WARP' if result else '🌐 Normal'}")
            
        elif command == "stats":
            controller = AntiTebasController()
            stats = controller.stats
            print(f"📊 Estadísticas:")
            print(f"   Total consultas: {stats['total_queries']}")
            print(f"   Consultas WARP: {stats['warp_queries']}")
            print(f"   Última actualización: {stats['last_update'] or 'Nunca'}")
            print(f"   Dominios cargados: {len(controller.warp_domains)}")
            
        else:
            print("Comandos disponibles:")
            print("  check          - Verificar proxy WARP")
            print("  update         - Actualizar listas de dominios")
            print("  add <dominio>  - Agregar dominio a lista WARP")
            print("  remove <dom>   - Eliminar dominio de lista WARP")
            print("  test [dominio] - Probar si dominio usa WARP")
            print("  stats          - Ver estadísticas")
            sys.exit(1)
    else:
        # Modo monitor (por defecto)
        controller = AntiTebasController()
        controller.start()


if __name__ == "__main__":
    main()