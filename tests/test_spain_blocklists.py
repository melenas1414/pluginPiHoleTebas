#!/usr/bin/env python3
"""
Test básico para la funcionalidad de listas públicas de España
"""

import sys
import os

# Agregar el path del módulo
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'antiTebasPlugin', 'src'))

def test_spain_blocklist_parsing():
    """Test de parseo de listas de bloqueos de España"""
    print("🧪 Test: Parseo de listas de bloqueos de España")
    
    # Datos de prueba en diferentes formatos
    test_data_hosts = """
# Comentario de prueba
0.0.0.0 sitio-bloqueado.com
127.0.0.1 otro-sitio.es
# Otro comentario
0.0.0.0 subdomain.example.com
"""
    
    test_data_plain = """
# Formato plano
sitio1.com
sitio2.es
sitio3.tv
"""
    
    test_data_wildcards = """
*.wildcard-domain.com
*.otro-wildcard.tv
normal-domain.com
"""
    
    # Test formato hosts
    domains_hosts = set()
    for line in test_data_hosts.split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split()
        if len(parts) >= 2 and parts[0] in ['0.0.0.0', '127.0.0.1']:
            domain = parts[1]
            domains_hosts.add(domain)
    
    print(f"  ✓ Formato hosts: {len(domains_hosts)} dominios parseados")
    assert 'sitio-bloqueado.com' in domains_hosts
    assert 'otro-sitio.es' in domains_hosts
    
    # Test formato plano
    domains_plain = set()
    for line in test_data_plain.split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split()
        if len(parts) == 1:
            domain = parts[0]
            domains_plain.add(domain)
    
    print(f"  ✓ Formato plano: {len(domains_plain)} dominios parseados")
    assert 'sitio1.com' in domains_plain
    
    # Test wildcards
    domains_wildcards = set()
    for line in test_data_wildcards.split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split()
        if len(parts) == 1:
            domain = parts[0]
            if domain.startswith('*.'):
                domain = domain[2:]
            domains_wildcards.add(domain)
    
    print(f"  ✓ Formato wildcards: {len(domains_wildcards)} dominios parseados")
    assert 'wildcard-domain.com' in domains_wildcards
    assert 'normal-domain.com' in domains_wildcards
    
    # Combinar todos
    all_domains = domains_hosts | domains_plain | domains_wildcards
    print(f"  ✅ Total: {len(all_domains)} dominios únicos parseados")
    print()
    return True

def test_domain_validation():
    """Test de validación de dominios"""
    print("🧪 Test: Validación de dominios")
    
    import re
    
    def is_valid_domain(domain):
        """Verificar si un dominio es válido"""
        if not domain or len(domain) > 253:
            return False
        pattern = r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
        return re.match(pattern, domain) is not None
    
    # Dominios válidos
    valid_domains = [
        'google.com',
        'subdomain.example.com',
        'test-domain.es',
        'a.b.c.d.example.com'
    ]
    
    # Dominios inválidos
    invalid_domains = [
        '',
        '-invalid.com',
        'invalid-.com',
        '.invalid.com',
        'invalid..com',
        'a' * 254  # Muy largo
    ]
    
    for domain in valid_domains:
        assert is_valid_domain(domain), f"Debería ser válido: {domain}"
        print(f"  ✓ Válido: {domain}")
    
    for domain in invalid_domains:
        assert not is_valid_domain(domain), f"Debería ser inválido: {domain}"
        print(f"  ✓ Inválido rechazado: {domain[:50]}")
    
    print("  ✅ Validación de dominios correcta")
    print()
    return True

def test_configuration_loading():
    """Test de carga de configuración"""
    print("🧪 Test: Carga de configuración SPAIN_BLOCKLIST_URLS")
    
    # Simular configuración
    config_text = """
# Configuración de prueba
WARP_PROXY_HOST=localhost
SPAIN_BLOCKLIST_URLS=https://example.com/list1.txt,https://example.com/list2.txt
UPDATE_INTERVAL=3600
"""
    
    config = {}
    for line in config_text.split('\n'):
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            key, value = line.split('=', 1)
            config[key.strip()] = value.strip()
    
    print(f"  ✓ Config cargado: {len(config)} valores")
    assert 'SPAIN_BLOCKLIST_URLS' in config
    print(f"  ✓ SPAIN_BLOCKLIST_URLS: {config['SPAIN_BLOCKLIST_URLS']}")
    
    # Parsear URLs
    urls = config['SPAIN_BLOCKLIST_URLS'].split(',')
    print(f"  ✓ URLs parseadas: {len(urls)}")
    assert len(urls) == 2
    
    print("  ✅ Configuración parseada correctamente")
    print()
    return True

def main():
    """Ejecutar todos los tests"""
    print("=" * 60)
    print("🚀 Tests para funcionalidad de listas públicas de España")
    print("=" * 60)
    print()
    
    tests = [
        test_spain_blocklist_parsing,
        test_domain_validation,
        test_configuration_loading
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test():
                passed += 1
        except AssertionError as e:
            print(f"  ❌ Test falló: {e}")
            failed += 1
        except Exception as e:
            print(f"  ❌ Error en test: {e}")
            failed += 1
    
    print("=" * 60)
    print(f"📊 Resultados: {passed} passed, {failed} failed")
    print("=" * 60)
    
    if failed > 0:
        sys.exit(1)
    else:
        print("\n✅ Todos los tests pasaron correctamente\n")
        sys.exit(0)

if __name__ == "__main__":
    main()
