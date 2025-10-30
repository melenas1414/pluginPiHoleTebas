FROM ubuntu:22.04

# Instalar dependencias
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    iproute2 \
    iptables \
    dante-server \
    redsocks \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Instalar Cloudflare WARP
RUN curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list \
    && apt-get update \
    && apt-get install -y cloudflare-warp \
    && rm -rf /var/lib/apt/lists/*

# Crear directorios necesarios
RUN mkdir -p /config /var/log/supervisor

# Copiar archivos de configuración
COPY danted.conf /etc/danted.conf
COPY redsocks.conf /etc/redsocks.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start-warp.sh /usr/local/bin/start-warp.sh

# Hacer ejecutables los scripts
RUN chmod +x /usr/local/bin/start-warp.sh

# Exponer puertos
EXPOSE 1080 8080

# Comando por defecto
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]