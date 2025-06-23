# Prompt Projeto OpenVPN + Terraform

Preciso de um script Bash automatizado para configurar um servidor OpenVPN completo na AWS (Ubuntu), incluindo:

1. Atualização de sistema e instalação de pacotes essenciais:

   - OpenVPN, Easy-RSA, Nginx, Certbot, Fail2Ban, Netdata
   - Google Authenticator PAM, unattended-upgrades

2. Configurações avançadas de rede otimizadas para AWS/ARM:

   - Ajustes no sysctl.conf (BBR, buffer tuning)
   - Habilitação do ENA Support via AWS CLI
   - Ajustes de MTU e offloading de interface eth0

3. Geração automática de certificados PKI usando EasyRSA:

   - CA, dh.pem, server.crt, server.key, ta.key

4. Configuração completa do OpenVPN com alto nível de segurança e performance:

   - Protocolo UDP
   - Ciphers AES-256-GCM e TLS 1.3
   - Compressão lz4
   - Tuning de buffer e performance
   - Autenticação customizada via API Laravel

5. Integração com autenticação remota via API REST:

   - Script `/etc/openvpn/auth-laravel.sh` que envia credenciais para `https://api.o8partners.com.br/vpn/auth `
   - Valida resposta JSON `{ "success": true }` para liberar acesso
   - Uso opcional de token Bearer (armazenado em arquivo seguro)

6. Suporte opcional a 2FA com Google Authenticator:

   - Plugin PAM do OpenVPN
   - Script `/usr/local/bin/setup-2fa.sh` para configuração por usuário

7. Servidor web seguro com Nginx para download do cliente `.ovpn`:

   - HTTPS com Let's Encrypt
   - Proteção com autenticação básica (`htpasswd`)
   - Cliente `.ovpn` pré-configurado com suporte a 2FA

8. Configuração de monitoramento com Netdata via HTTPS:

   - Proxy reverso com Nginx
   - Acesso protegido com autenticação HTTP

9. Firewall e proteção:

   - Configuração de UFW com regras mínimas
   - Fail2Ban configurado para bloqueio após tentativas maliciosas

10. Atualizações automáticas do sistema:

    - Configuração de `unattended-upgrades` com reinicialização noturna

11. Reinicialização dos serviços essenciais:
    - OpenVPN, Nginx, Fail2Ban, Netdata

O script deve ser compatível com Ubuntu 22.04+ e rodar durante o provisionamento de uma instância EC2 via `user_data`.

Desejo que ele seja robusto, bem comentado e pronto para uso imediato.
