# Claude Code Desktop no Android (Termux + Termux:X11)

Instalador automatizado para criar um ambiente Linux Ubuntu 24.04 ARM64 com XFCE e Claude Code dentro do Termux.

## Requisitos

- Android ARM64.
- Aplicativos Termux e Termux:X11 instalados no Android.
- Conexão com a internet.
- Espaço livre suficiente para Ubuntu, XFCE, Node.js e Claude Code (recomendado: pelo menos 5 GB).

> O APK Termux:X11 é instalado separadamente no Android. O instalador configura o restante pelo Termux. O login do Claude é feito pelo próprio usuário após a instalação.

## Instalação em um único comando

Abra o Termux e cole:

```bash
curl -fsSL https://raw.githubusercontent.com/alfa727337/Claude-Gr-fico/main/install.sh | bash
```

O instalador instala os pacotes do Termux, Node.js/npm, proot-distro, Ubuntu 24.04 ARM64, XFCE, terminal, Thunar, DBus, dependências e Claude Code usando o instalador oficial da Anthropic.

## Abrir a área de trabalho

Depois que a instalação terminar, execute no Termux:

```bash
claude-code-desktop
```

Na área de trabalho XFCE, abra o menu e selecione **Claude Code**. Entre com sua própria conta.

## Observações

- O instalador cria um ambiente separado chamado `claude-code`; não importa arquivos, histórico, credenciais ou configurações de outros ambientes.
- Se já existir um container com esse nome, o instalador para sem apagá-lo ou sobrescrevê-lo.
- A primeira instalação baixa vários gigabytes e pode demorar. Mantenha o Android conectado à internet e evite fechar o Termux.
- O desempenho depende do aparelho, da memória RAM e do espaço disponível.
- Este projeto não é afiliado à Anthropic.
