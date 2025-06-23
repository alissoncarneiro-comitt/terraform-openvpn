#!/bin/bash
# Script OpenVPN Completo com 2FA, Let's Encrypt, Netdata e Atualizações
# Domínio: vpn.o8partners.com.br
# Execute como root: sudo su
# Versão: 2.0 - Melhorias em segurança e feedback



set -e  # Interrompe o script em caso de erro
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1


set -e  # Aborta em erro
trap 'echo "Erro na linha $LINENO. Instalação abortada." >&2; exit 1' ERR





# =============================
# 1. Verificações Iniciais
# =============================
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[31mERRO: Este script deve ser executado como root.\033[0m"
    exit 1
fi

if ! grep -i ubuntu /etc/os-release > /dev/null; then
    echo -e "\033[31mERRO: Este script requer Ubuntu. Abortando.\033[0m"
    exit 1
fi

for var in admin_user ovpn_password api_token; do
  if [ -z "${!var}" ]; then
    echo "Variável $var não definida. Abortando."
    exit 1
  fi
done

# =============================
# 2. Variáveis de Configuração
# =============================
DOMAIN="vpn.o8partners.com.br"
NETDATA_DOMAIN="netdata.$DOMAIN"
API_URL="https://api.o8partners.com.br/vpn/auth"
ADMIN_USER="${admin_user}"
OVPN_PASSWORD="${ovpn_password}"
API_TOKEN="${api_token}"

# =============================
# 2.1. Validação das Variáveis de Ambiente
# =============================
for var in ADMIN_USER OVPN_PASSWORD API_TOKEN; do
  if [ -z "${!var}" ]; then
    echo -e "\033[31mERRO: Variável $var não definida. Exporte antes de rodar o script.\033[0m"
    exit 1
  fi
done

# =============================
# 3. Funções Reutilizáveis
# =============================
log() {
    echo -e "\033[32m[$(date +'%H:%M:%S')] $1\033[0m"
}

fail() {
    echo -e "\033[31m[$(date +'%H:%M:%S')] ERRO: $1\033[0m"
    exit 1
}

check_service() {
    systemctl is-active --quiet "$1" && echo "$1 OK" || fail "$1 não está rodando"
}

# =============================
# 4. Atualização e Instalação
# =============================
log "Atualizando sistema e instalando pacotes..."
apt update && apt upgrade -y
apt install -y openvpn easy-rsa iptables-persistent net-tools curl jq nginx certbot python3-certbot-nginx \
               libpam-google-authenticator fail2ban netdata unattended-upgrades awscli apache2-utils || fail "Falha na instalação de pacotes"

# =============================
# 5. Configuração de Rede (sem duplicação)
# =============================
log "Configurando ajustes de rede otimizados..."
SYSCTL_MARKER="# O8PARTNERS OPENVPN TUNING"
if ! grep -q "$SYSCTL_MARKER" /etc/sysctl.conf; then
  cat << EOF >> /etc/sysctl.conf
$SYSCTL_MARKER
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 65536 33554432
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.core.default_qdisc=fq
EOF
  sysctl --system > /dev/null || fail "Falha ao aplicar configuração de rede"
else
  log "Ajustes de rede já aplicados anteriormente."
fi

# =============================
# 6. AWS ENA Support (com validação)
# =============================
log "Configurando AWS ENA Support..."
IFACE=$(ip route | grep default | awk '{print $5}')
if [ -z "$IFACE" ]; then
  fail "Não foi possível detectar a interface de rede padrão."
else
  ethtool -K $IFACE tx off rx off sg off tso off gso off gro off > /dev/null
  ip link set dev $IFACE mtu 1500 txqueuelen 2000
fi

# =============================
# 6.1. Ativação ENA via AWS CLI (opcional)
# =============================
if curl -s http://169.254.169.254/latest/meta-data/instance-id > /dev/null; then
  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
  if aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --ena-support --region $REGION 2>/dev/null; then
    log "ENA Support ativado"
  else
    echo -e "\033[33mAviso: Não foi possível ativar ENA Support\033[0m"
  fi
else
  log "Não está em ambiente AWS, pulando ativação ENA."
fi

# =============================
# 7. Geração de Certificados PKI (idempotente)
# =============================
log "Gerando certificados PKI..."
if [ -d /etc/openvpn/easy-rsa/pki ]; then
  log "PKI já existe, pulando geração de certificados."
else
  make-cadir /etc/openvpn/easy-rsa
  cd /etc/openvpn/easy-rsa
  ./easyrsa init-pki
  ./easyrsa build-ca nopass <<< "yes"
  ./easyrsa gen-dh
  ./easyrsa build-server-full server nopass
  openvpn --genkey --secret /etc/openvpn/ta.key
fi

# =============================
# 8. Configuração do OpenVPN
# =============================
log "Criando configuração do OpenVPN..."
cat << EOF > /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh /etc/openvpn/easy-rsa/pki/dh.pem
tls-auth /etc/openvpn/ta.key 0
topology subnet
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
cipher AES-256-GCM
auth SHA512
tls-version-min 1.3
tls-cipher TLS_AES_256_GCM_SHA384
remote-cert-tls client
compress lz4-v2
push "compress lz4-v2"
tun-mtu 1420
mssfix 1400
fast-io
txqueuelen 2000
sndbuf 8388608
rcvbuf 8388608
auth-user-pass-verify /etc/openvpn/auth-laravel.sh via-file
client-cert-not-required
username-as-common-name
plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so login
status /var/log/openvpn-status.log
log-append /var/log/openvpn.log
verb 3
explicit-exit-notify 1
reneg-sec 3600
EOF

# =============================
# 9. Autenticação via API Laravel
# =============================
log "Configurando autenticação via API..."
mkdir -p /etc/openvpn
cat << EOF > /etc/openvpn/auth.conf
API_TOKEN="$API_TOKEN"
EOF
chmod 600 /etc/openvpn/auth.conf

cat << 'EOF' > /etc/openvpn/auth-laravel.sh
#!/bin/bash
source /etc/openvpn/auth.conf
USERNAME=$(head -n 1 "$1")
PASSWORD=$(tail -n 1 "$1")

# Validação de conexão segura
if ! curl -s --connect-timeout 5 "$API_URL" > /dev/null; then
    logger "OpenVPN Auth: Falha de conexão com API"
    exit 1
fi

RESPONSE=$(curl -s -S --connect-timeout 5 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer \$API_TOKEN" \
  -d "{\"username\":\"\$USERNAME\", \"password\":\"\$PASSWORD\"}" \
  $API_URL)

if [[ $(echo $RESPONSE | jq -r '.success') == "true" ]]; then
    logger "OpenVPN Auth: Sucesso para \$USERNAME"
    exit 0
else
    logger "OpenVPN Auth Failed: User \$USERNAME"
    exit 1
fi
EOF
chmod +x /etc/openvpn/auth-laravel.sh

# =============================
# 10. Configuração de 2FA
# =============================
log "Configurando 2FA..."
apt install -y libpam-google-authenticator
echo "auth required pam_google_authenticator.so" >> /etc/pam.d/openvpn

cat << 'EOF' > /usr/local/bin/setup-2fa.sh
#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "Este script precisa ser executado como root"
   exit 1
fi

read -p "Digite o nome do usuário: " USERNAME
if id "$USERNAME" &>/dev/null; then
    su - "$USERNAME" -c "google-authenticator -t -d -r 3 -R 30 -w 3"
else
    echo "Usuário inválido"
    exit 1
fi
EOF
chmod +x /usr/local/bin/setup-2fa.sh

# =============================
# 11. Firewall e Fail2Ban
# =============================
log "Configurando firewall e proteção..."
ufw allow 1194/udp
ufw allow 80/tcp
ufw allow 443/tcp
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

cat << EOF > /etc/fail2ban/jail.local
[openvpn]
enabled = true
port = 1194
filter = openvpn
logpath = /var/log/openvpn.log
maxretry = 3
bantime = 86400
findtime = 3600
EOF
systemctl restart fail2ban

# =============================
# 12. Servidor Web para Cliente
# =============================
log "Configurando Nginx e cliente .ovpn..."
mkdir -p /var/www/html/download

cat << EOF > /etc/nginx/sites-available/vpn-download
server {
    listen 80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }
    
    location /download/ {
        root /var/www/html;
        try_files \$uri =404;
        autoindex off;
        add_header Content-Disposition "attachment";
        auth_basic "Restricted Download";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
EOF

ln -s /etc/nginx/sites-available/vpn-download /etc/nginx/sites-enabled/
htpasswd -b -c /etc/nginx/.htpasswd $ADMIN_USER "$OVPN_PASSWORD"
chmod 644 /etc/nginx/.htpasswd

# =============================
# 13. Geração do .ovpn
# =============================
cat << EOF > /var/www/html/download/client.ovpn
client
dev tun
proto udp
remote $DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA512
compress lz4-v2
tun-mtu 1420
mssfix 1400
auth-user-pass
key-direction 1
fast-io
sndbuf 8388608
rcvbuf 8388608
static-challenge "Código 2FA" 1
<ca>
$(cat /etc/openvpn/easy-rsa/pki/ca.crt)
</ca>
<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
EOF

# =============================
# 14. HTTPS com Let's Encrypt
# =============================
log "Configurando certificados SSL..."
systemctl restart nginx
sleep 30  # Espera DNS propagar

if ! certbot --nginx -d $DOMAIN -d $NETDATA_DOMAIN --non-interactive --agree-tos -m admin@o8partners.com.br; then
    echo -e "\033[33mAviso: Certbot falhou. Verifique DNS e tente novamente.\033[0m"
fi

# =============================
# 15. Configuração do Netdata
# =============================
log "Configurando acesso seguro ao Netdata..."
cat << EOF > /etc/nginx/sites-available/netdata
server {
    listen 443 ssl;
    server_name $NETDATA_DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$NETDATA_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$NETDATA_DOMAIN/privkey.pem;
    
    location / {
        proxy_pass http://localhost:19999;
        proxy_set_header Host \$host;
        auth_basic "Acesso Restrito";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
EOF

ln -s /etc/nginx/sites-available/netdata /etc/nginx/sites-enabled/
systemctl restart nginx

# =============================
# 16. Atualizações Automáticas
# =============================
log "Configurando atualizações automáticas..."
cat << EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::Mail "admin@o8partners.com.br";
Unattended-Upgrade::MailOnlyOnError "true";
EOF

dpkg-reconfigure --priority=low unattended-upgrades

# =============================
# 17. Reinicialização de Serviços
# =============================
log "Reiniciando serviços..."
systemctl enable openvpn@server netdata fail2ban
systemctl restart openvpn@server nginx netdata

# =============================
# 18. Criação do README
# =============================
cat << EOF > /root/README.txt
====================================
Instruções de Uso do OpenVPN Server
====================================
1. URL de Download do Cliente:
   https://$DOMAIN/download/client.ovpn
   - Usuário: $ADMIN_USER
   - Senha: $OVPN_PASSWORD

2. Monitoramento (Netdata):
   https://$NETDATA_DOMAIN
   - Usuário: $ADMIN_USER
   - Senha: $OVPN_PASSWORD

3. Configuração de 2FA:
   - Execute: sudo setup-2fa.sh
   - Siga as instruções para gerar o QR Code

4. Logs:
   - OpenVPN: tail -f /var/log/openvpn.log
   - Fail2Ban: fail2ban-client status openvpn

5. Recomendações:
   - Atualize as senhas padrão
   - Teste a API Laravel: curl -v $API_URL
   - Revise firewall: ufw status verbose
EOF

echo -e "\033[32m✅ Instalação concluída!\033[0m"
echo -e "Acesse: https://$DOMAIN/download/client.ovpn"