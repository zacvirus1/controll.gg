```markdown
<h1 align="center">Instalador do Painel de Controle</h1>

![Discord](https://img.shields.io/discord/876934115302178876?label=DISCORD&style=for-the-badge)
![Contribuidores](https://img.shields.io/github/contributors/Ferks-FK/ControlPanel-Installer?style=for-the-badge)

Bem-vindo ao Instalador do Painel de Controle, um script independente para a instalação do [ControlPanel](https://ctrlpanel.gg/). Este script é orgulhosamente desenvolvido por [Rest Api Sistemas](https://github.com/RestApiSistemas) e não está afiliado ao projeto oficial do ControlPanel.

<h1 align="center">Recursos</h1>

- Instalação totalmente automatizada do ControlPanel, incluindo dependências, configuração do banco de dados, cronjob e configuração do NGINX.
- Configuração automática do UFW (firewall para Ubuntu/Debian).
- (Opcional) Configuração automática para o Let's Encrypt.
- (Opcional) Atualização automática do painel para a versão mais recente.

<h1 align="center">Suporte</h1>

Para obter ajuda com este script de instalação (não relacionado ao projeto oficial do ControlPanel), junte-se ao nosso [Grupo de Suporte](https://discord.gg/buDBbSGJmQ).

<h1 align="center">Configurações de Instalação Suportadas</h1>

Aqui estão as configurações de instalação suportadas por este script.

<h1 align="center">Sistemas Operacionais Suportados</h1></br>

| Sistema Operacional | Versão | ✔️ \| ❌ |
| :--- | :--- | :---: |
| Debian | 9, 10, 11 | ✔️ |
| Ubuntu | 18, 20, 22 | ✔️ |
| CentOS | 7, 8 | ✔️ |

<h1 align="center">Como Usar</h1>

Para instalar o ControlPanel, basta executar o seguinte comando como usuário root.

```bash
bash <(curl -s https://raw.githubusercontent.com/Ferks-FK/ControlPanel-Installer/development/install.sh)
```

<h1 align="center">Aviso Importante</h1>

*Não execute o comando com sudo.*

**Exemplo:** ```$ sudo bash <(curl -s...```

*Certifique-se de estar logado como usuário root para executar o comando.*

**Exemplo:** ```# bash <(curl -s...```


<h1 align="center">Desenvolvimento</h1>

Este script é orgulhosamente criado e mantido por [Rest Api Sistemas](https://github.com/zacvirus1).

<h1 align="center">Informações Adicionais</h1>

Se você tiver ideias ou sugestões, sinta-se à vontade para compartilhá-las no [Grupo de Suporte](https://discord.gg/buDBbSGJmQ).
```