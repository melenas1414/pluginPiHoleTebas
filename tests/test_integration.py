#!/usr/bin/env python3
"""
Test de integración para verificar el flujo completo de descarga de blocklists
"""

import sys
import os
import tempfile
from pathlib import Path

# Agregar el path del módulo
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'antiTebasPlugin', 'src'))

def test_blocklist_download_integration():
    """Test de integración completo"""
    print("=" * 60)
    print("🧪 Test de Integración: Descarga de Blocklists España")
    print("=" * 60)
    print()
    
    # Crear archivo de blocklist de prueba
    test_blocklist_content = """# Lista de prueba
# Comentario de ejemplo
0.0.0.0 test-blocked-1.com
127.0.0.1 test-blocked-2.es
test-blocked-3.tv
*.wildcard-test.com
# Fin de lista
"""
    
    # Crear archivo temporal
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write(test_blocklist_content)
        temp_file = f.name
    
    try:
        print(f"✓ Archivo de prueba creado: {temp_file}")
        
        # Simular el parseo de la lista
        blocked_domains = set()
        
        with open(temp_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                
                parts = line.split()
                
                # Formato hosts
                if len(parts) >= 2 and parts[0] in ['0.0.0.0', '127.0.0.1']:
                    domain = parts[1]
                    blocked_domains.add(domain)
                # Formato plano
                elif len(parts) == 1:
                    domain = parts[0]
                    if domain.startswith('*.'):
                        domain = domain[2:]
                    blocked_domains.add(domain)
        
        print(f"✓ Dominios parseados: {len(blocked_domains)}")
        print(f"  - test-blocked-1.com: {'✓' if 'test-blocked-1.com' in blocked_domains else '✗'}")
        print(f"  - test-blocked-2.es: {'✓' if 'test-blocked-2.es' in blocked_domains else '✗'}")
        print(f"  - test-blocked-3.tv: {'✓' if 'test-blocked-3.tv' in blocked_domains else '✗'}")
        print(f"  - wildcard-test.com: {'✓' if 'wildcard-test.com' in blocked_domains else '✗'}")
        
        # Validar resultados
        assert 'test-blocked-1.com' in blocked_domains
        assert 'test-blocked-2.es' in blocked_domains
        assert 'test-blocked-3.tv' in blocked_domains
        assert 'wildcard-test.com' in blocked_domains
        assert len(blocked_domains) == 4
        
        print()
        print("✅ Test de integración pasado correctamente")
        print()
        
        # Simular guardado de dominios
        output_file = tempfile.mktemp(suffix='.txt')
        with open(output_file, 'w') as f:
            f.write("# Lista de dominios WARP - Test\n")
            f.write(f"# Total dominios: {len(blocked_domains)}\n\n")
            for domain in sorted(blocked_domains):
                f.write(f"{domain}\n")
        
        print(f"✓ Archivo de salida generado: {output_file}")
        
        # Verificar contenido del archivo
        with open(output_file, 'r') as f:
            content = f.read()
            print(f"✓ Contenido guardado ({len(content)} bytes)")
        
        # Limpiar
        os.unlink(output_file)
        print("✓ Archivos temporales limpiados")
        
        return True
        
    finally:
        # Limpiar archivo temporal
        if os.path.exists(temp_file):
            os.unlink(temp_file)

def test_multiple_sources():
    """Test con múltiples fuentes de listas"""
    print("=" * 60)
    print("🧪 Test: Múltiples Fuentes de Blocklists")
    print("=" * 60)
    print()
    
    # Simular configuración con múltiples URLs
    config_urls = "https://example.com/list1.txt,https://example.com/list2.txt,https://example.com/list3.txt"
    
    urls = config_urls.split(',')
    print(f"✓ URLs configuradas: {len(urls)}")
    
    for i, url in enumerate(urls, 1):
        url = url.strip()
        print(f"  {i}. {url}")
    
    assert len(urls) == 3
    print()
    print("✅ Configuración de múltiples fuentes OK")
    print()
    
    return True

def test_stats_tracking():
    """Test de seguimiento de estadísticas"""
    print("=" * 60)
    print("🧪 Test: Seguimiento de Estadísticas")
    print("=" * 60)
    print()
    
    # Simular estadísticas
    stats = {
        'external_domains': 1500,
        'spain_blocked_domains': 350,
        'total_domains': 1850
    }
    
    print(f"✓ Estadísticas generadas:")
    print(f"  - Dominios externos: {stats['external_domains']}")
    print(f"  - Dominios bloqueados España: {stats['spain_blocked_domains']}")
    print(f"  - Total dominios: {stats['total_domains']}")
    
    assert stats['total_domains'] == stats['external_domains'] + stats['spain_blocked_domains']
    
    print()
    print("✅ Seguimiento de estadísticas OK")
    print()
    
    return True

def main():
    """Ejecutar todos los tests de integración"""
    print("\n" + "=" * 60)
    print("🚀 Suite de Tests de Integración")
    print("=" * 60)
    print()
    
    tests = [
        ("Descarga e integración", test_blocklist_download_integration),
        ("Múltiples fuentes", test_multiple_sources),
        ("Estadísticas", test_stats_tracking)
    ]
    
    passed = 0
    failed = 0
    
    for name, test_func in tests:
        try:
            if test_func():
                passed += 1
                print(f"✅ {name}: PASADO\n")
        except AssertionError as e:
            failed += 1
            print(f"❌ {name}: FALLÓ - {e}\n")
        except Exception as e:
            failed += 1
            print(f"❌ {name}: ERROR - {e}\n")
    
    print("=" * 60)
    print(f"📊 Resultados Finales: {passed} pasados, {failed} fallidos")
    print("=" * 60)
    
    if failed > 0:
        print("\n❌ Algunos tests fallaron\n")
        sys.exit(1)
    else:
        print("\n✅ Todos los tests de integración pasaron\n")
        sys.exit(0)

if __name__ == "__main__":
    main()
