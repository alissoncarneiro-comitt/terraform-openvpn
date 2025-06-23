# 📜 Descrição Detalhada do Script `install_openvpn.sh`

Este script automatiza a instalação e configuração completa de um **servidor OpenVPN seguro na AWS**, com os seguintes recursos:

- Autenticação via API Laravel
- 2FA com Google Authenticator
- HTTPS com Let's Encrypt
- Monitoramento com Netdata
- Proteção com Fail2Ban e UFW
- Atualizações automáticas
- Serviço Nginx para download do cliente `.ovpn`

O script é otimizado para execução em **Ubuntu Server** na região **us-east-1 (N. Virginia)** da AWS.

---

## 🔧 Bloco 1: Cabeçalho e Instalação Inicial

```bash
#!/bin/bash
# Script OpenVPN Completo com 2FA, Let's Encrypt, Netdata e Atualizações
# Domínio: vpn.o8partners.com.br
# Execute como root: sudo su
```

### 📌 O que isso faz:

- Define o interpretador do shell (`bash`)
- Comentários descritivos sobre o propósito do script
- Lembrete de executar como superusuário (`sudo su`)

---

## 📦 Bloco 2: Atualização e Instalação de Pacotes

```bash
apt update && apt upgrade -y
apt install -y openvpn easy-rsa iptables-persistent net-tools curl jq nginx certbot python3-certbot-nginx \
               libpam-google-authenticator fail2ban netdata unattended-upgrades
```

### 📌 O que isso faz:

- Atualiza pacotes do sistema
- Instala dependências essenciais:
  - **OpenVPN**: servidor seguro
  - **easy-rsa**: geração de certificados
  - **Nginx**: proxy reverso e servidor web
  - **Certbot + plugin nginx**: certificados SSL gratuitos
  - **Fail2Ban & UFW**: proteção contra tentativas maliciosas
  - **Netdata**: monitoramento em tempo real
  - **unattended-upgrades**: atualizações automáticas

> ✅ Recomendação: Adicionar `DEBIAN_FRONTEND=noninteractive` para evitar prompts durante a instalação.

---

## 🌐 Bloco 3: Configuração de Rede Otimizada (AWS/ARM)

```bash
cat << EOF >> /etc/sysctl.conf
net.core.rmem_max=33554432
...
EOF
sysctl -p
```

### 📌 O que isso faz:

- Ajusta parâmetros de rede para melhor desempenho em ambientes AWS/ARM
- Habilita o algoritmo **BBR** para controle de congestionamento
- Desativa offloading de rede para compatibilidade

> ✅ Ótimo tuning para máquinas T4g na AWS.

---

## ⚙️ Bloco 4: AWS ENA Support

```bash
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --ena-support ...
ethtool -K eth0 tx off rx off sg off tso off gso off gro off
ip link set dev eth0 mtu 1500 txqueuelen 2000
```

### 📌 O que isso faz:

- Habilita o recurso **ENA (Elastic Network Adapter)**
- Ajusta configurações da interface de rede
- Garante performance máxima em redes AWS

> ⚠️ Nota: Se já estiver habilitado, o comando pode falhar, mas não afeta a execução geral.

---

## 🔐 Bloco 5: Geração de Certificados PKI

```bash
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-dh
./easyrsa build-server-full server nopass
openvpn --genkey --secret /etc/openvpn/ta.key
```

### 📌 O que isso faz:

- Cria uma autoridade certificadora local (CA)
- Gera certificados para servidor e chaves seguras
- Gera chave TLS adicional (`ta.key`) para segurança extra

> ✅ Estrutura segura e recomendada para servidores OpenVPN.

---

## 🛡️ Bloco 6: Configuração do OpenVPN

```bash
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
```

### 📌 O que isso faz:

- Configura o servidor OpenVPN com:
  - Segurança avançada (TLS 1.3, AES-256-GCM)
  - Performance otimizada (buffer tuning, compresão)
  - Autenticação customizada via API Laravel
  - Suporte opcional a 2FA

> ✅ Uma das melhores práticas de configuração OpenVPN.

---

## 🧩 Bloco 7: Autenticação via API Laravel

```bash
cat << EOF > /etc/openvpn/auth-laravel.sh
#!/bin/bash
USERNAME=$(head -n 1 "$1")
PASSWORD=$(tail -n 1 "$1")
API_URL="https://api.o8partners.com.br/vpn/auth "
RESPONSE=$(curl -s -k --connect-timeout 5 ...)
if [[ $(echo $RESPONSE | jq -r '.success') == "true" ]]; then
    exit 0
else
    logger "OpenVPN Auth Failed: User $USERNAME"
    exit 1
fi
EOF
chmod +x /etc/openvpn/auth-laravel.sh
```

### 📌 O que isso faz:

- Valida credenciais via chamada HTTP POST à sua API Laravel
- Retorna sucesso ou falha conforme resposta da API
- Registra logs de acesso negado

> ❗ Melhoria: Remover `-k` do curl em produção (ignora validação SSL).

---

## 🔒 Bloco 8: Configuração de 2FA (Google Authenticator)

```bash
cat << EOF > /usr/local/bin/setup-2fa.sh
#!/bin/bash
if [ "$(id -u)" != "0" ]; then
   echo "Este script precisa ser executado como root" 1>&2
   exit 1
fi
read -p "Digite o nome do usuário: " USERNAME
su - $USERNAME -c "google-authenticator -t -d -r 3 -R 30 -w 3"
EOF
chmod +x /usr/local/bin/setup-2fa.sh
```

### 📌 O que isso faz:

- Instala o plugin PAM do Google Authenticator
- Cria script para gerar QR Code por usuário
- Integra com OpenVPN via linha `static-challenge` no `.ovpn`

> ✅ Excelente uso de autenticação em duas etapas.

---

## 🛡️ Bloco 9: Firewall e Fail2Ban

```bash
ufw allow 1194/udp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

cat << EOF > /etc/fail2ban/jail.local
[openvpn]
enabled = true
port = 1194
filter = openvpn
logpath = /var/log/openvpn.log
maxretry = 3
bantime = 86400
EOF
systemctl restart fail2ban
```

### 📌 O que isso faz:

- Abre as portas essenciais
- Habilita firewall UFW
- Configura Fail2Ban para bloquear IPs após 3 tentativas falhas

> ✅ Muito bom nível de proteção automática.

---

## 📥 Bloco 10: Servidor Web para Cliente .ovpn

```bash
cat << EOF > /etc/nginx/sites-available/vpn-download
server {
    listen 80;
    server_name vpn.o8partners.com.br;
    location /download/ {
        root /var/www/html;
        try_files \$uri =404;
        autoindex off;
        add_header Content-Disposition "attachment";
    }
}
EOF
ln -s /etc/nginx/sites-available/vpn-download /etc/nginx/sites-enabled/
systemctl restart nginx

mkdir -p /var/www/html/download
cat << EOF > /var/www/html/download/client.ovpn
client
dev tun
proto udp
remote vpn.o8partners.com.br 1194
...
EOF
```

### 📌 O que isso faz:

- Configura servidor Nginx para disponibilizar o cliente `.ovpn`
- Gera o arquivo `.ovpn` com todas as configurações necessárias
- Impede navegação direta no diretório

> ✅ Ideal para usuários baixarem facilmente o perfil.

---

## 🔐 Bloco 11: HTTPS com Let's Encrypt

```bash
certbot --nginx -d vpn.o8partners.com.br --non-interactive --agree-tos -m admin@o8partners.com.br
```

### 📌 O que isso faz:

- Gera certificado gratuito com Let's Encrypt
- Configura automaticamente o Nginx
- Renovação automática configurada

> ✅ Requisito: domínio apontando corretamente para o IP do servidor.

---

## 🔄 Bloco 12: Atualizações Automáticas

```bash
cat << EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF
dpkg-reconfigure --priority=low unattended-upgrades
```

### 📌 O que isso faz:

- Mantém o sistema atualizado automaticamente
- Reinicia o servidor às 02:00 se necessário

> ✅ Excelente prática de manutenção.

---

## 🔁 Bloco 13: Reinicialização dos Serviços

```bash
systemctl enable openvpn@server netdata fail2ban
systemctl restart openvpn@server nginx
```

### 📌 O que isso faz:

- Garante que os serviços iniciem na inicialização
- Reinicia os principais serviços após a instalação

> ✅ Importante para garantir funcionamento imediato.

---

## 📝 Bloco 14: Criação do README

```bash
cat << EOF > /root/README.txt
====================================
Instruções de Uso do OpenVPN Server
1. URL de Download do Cliente:
   https://vpn.o8partners.com.br/download/client.ovpn
2. Configuração de 2FA:
   - Execute: setup-2fa.sh como root
   - Siga as instruções para gerar o QR Code
3. Monitoramento:
   - Netdata: http://IP_DO_SERVIDOR:19999
   - Logs OpenVPN: tail -f /var/log/openvpn.log
4. Atualizações:
   - Sistema configurado para atualizações automáticas
   - Reinicializações às 2AM se necessário
EOF
echo "Instalação concluída!"
```

### 📌 O que isso faz:

- Cria um guia rápido de uso pós-instalação
- Documenta URLs, senhas e comandos importantes

> ✅ Prática excelente para facilitar uso futuro.

---

## 🧾 Resumo Final

| Bloco  | O que faz                             |
| ------ | ------------------------------------- |
| **1**  | Cabeçalho e atualização de pacotes    |
| **2**  | Tuning de rede para alta performance  |
| **3**  | Configuração de rede AWS/ENA          |
| **4**  | Geração de certificados PKI           |
| **5**  | Configuração completa do OpenVPN      |
| **6**  | Autenticação customizada via API      |
| **7**  | Setup de 2FA com Google Authenticator |
| **8**  | Configuração de firewall e Fail2Ban   |
| **9**  | Nginx para download do `.ovpn`        |
| **10** | HTTPS com Let's Encrypt               |
| **11** | Atualizações automáticas              |
| **12** | Reinicialização de serviços           |
| **13** | Criação de documento de instruções    |

---

## ✅ Recomendações Futuras

- Remover `--insecure (-k)` do `curl` em produção
- Usar vari
