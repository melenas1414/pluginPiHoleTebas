# Makefile para AntiTebas Plugin

.PHONY: help build up down logs status health install clean update

# Configuración por defecto
COMPOSE_FILE = docker-compose.yml
PROJECT_NAME = pihole-warp

help: ## Mostrar ayuda
	@echo "AntiTebas Plugin - Comandos disponibles:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Instalar y configurar el proyecto (requiere sudo)
	@echo "🚀 Instalando AntiTebas Plugin..."
	@if [ ! -f .env ]; then cp .env.example .env; echo "📝 Archivo .env creado. Configúralo antes de continuar."; fi
	@mkdir -p logs config/warp config/pihole
	@chmod +x install.sh docker/warp/*.sh antiTebasPlugin/scripts/*.sh antiTebasPlugin/install-plugin.sh
	@echo "✅ Instalación completada"

build: ## Construir imágenes Docker
	@echo "🏗️  Construyendo imágenes..."
	@docker-compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) build

up: ## Iniciar servicios
	@echo "🚀 Iniciando servicios..."
	@docker-compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) up -d

down: ## Detener servicios
	@echo "🛑 Deteniendo servicios..."
	@docker-compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) down

restart: ## Reiniciar servicios
	@echo "🔄 Reiniciando servicios..."
	@docker-compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) restart

logs: ## Ver logs en tiempo real
	@docker-compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) logs -f



logs-warp: ## Ver logs del WARP container
	@docker-compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) logs -f warp-proxy

status: ## Ver estado de contenedores
	@echo "📊 Estado de contenedores:"
	@docker-compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) ps

health: ## Verificar estado del proxy WARP
	@echo "🔍 Verificando estado del proxy WARP..."
	@docker-compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec warp-proxy /bin/bash -c "curl -s http://localhost:1080 > /dev/null && echo '✅ Proxy SOCKS5 OK' || echo '❌ Proxy SOCKS5 Error'"

shell-warp: ## Abrir shell en contenedor WARP

	@docker-compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) exec warp-proxy /bin/bash

clean: ## Limpiar contenedores, imágenes y volúmenes
	@echo "🧹 Limpiando recursos Docker..."
	@docker-compose -f $(COMPOSE_FILE) -p $(PROJECT_NAME) down -v --rmi all --remove-orphans

clean-logs: ## Limpiar archivos de log
	@echo "🗑️  Limpiando logs..."
	@rm -f logs/*.log logs/*.log.old



test-warp: ## Probar conectividad WARP
	@echo "🧪 Probando conectividad WARP..."
	@nc -z localhost 1080 && echo "✅ WARP SOCKS5 accesible" || echo "❌ WARP SOCKS5 no accesible"
	@nc -z localhost 8080 && echo "✅ WARP Transparent Proxy accesible" || echo "❌ WARP Transparent Proxy no accesible"

backup: ## Crear backup de la configuración
	@echo "💾 Creando backup..."
	@mkdir -p backups
	@tar -czf backups/pihole-warp-backup-$$(date +%Y%m%d-%H%M%S).tar.gz .env config/ logs/ --exclude=logs/*.log
	@echo "✅ Backup creado en backups/"

dev: ## Modo desarrollo (logs en tiempo real)
	@echo "🛠️  Modo desarrollo - Ctrl+C para salir"
	@make up && make logs

# Aliases comunes
start: up ## Alias para 'up'
stop: down ## Alias para 'down'
ps: status ## Alias para 'status'