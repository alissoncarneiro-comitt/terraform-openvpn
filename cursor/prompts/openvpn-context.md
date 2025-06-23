# Prompt Salvo: Retomar Contexto do Projeto OpenVPN + Terraform

Tenho um projeto Terraform + Script Bash para criar uma instância EC2 na AWS com OpenVPN completo.

O script faz:

- Configuração automática do OpenVPN
- Autenticação via API Laravel
- 2FA com Google Authenticator
- HTTPS com Let's Encrypt
- Monitoramento com Netdata
- Proteção com Fail2Ban e UFW
- Atualizações automáticas

Preciso revisar, testar e possivelmente adaptar o script `install_openvpn.sh` para diferentes cenários, como:

- Alteração de domínio
- Remover dependência da API Laravel (usar autenticação local)
- Adicionar mais segurança
- Ajustar configurações de performance
- Incluir logs personalizados
- Melhorar a parte de 2FA
- Fazer deploy em outras regiões ou ambientes

Além disso, preciso entender melhor partes específicas do código, como:

- Como funciona a autenticação customizada
- Como é feita a integração com a API
- Como configurar os certificados SSL
- Como atualizar o script automaticamente

Vamos revisar e refinar tudo isso juntos?
